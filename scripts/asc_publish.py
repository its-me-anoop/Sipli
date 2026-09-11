#!/usr/bin/env python3
"""Prepare and submit an App Store release using an explicit, validated asset plan.

fetch is read-only. prepare updates the draft and verifies provider readback but
never submits. publish prepares, verifies, then submits for automatic release
AFTER_APPROVAL. Re-running either write mode reuses matching completed assets.

PUBLISH_VERSION/PUBLISH_BUILD default to 5.0.2/14. PUBLISH_SCREENSHOTS defaults to
appstore-screenshots/release-<version>/manifest.json. The manifest contains
{"version": "5.0.2", "locales": {"en-US": {"APP_IPHONE_67": ["repo/path.png"]}}}.
Only listed locale/display sets are replaced; other sets (such as Watch) remain.

Provider dependencies: PyJWT, cryptography, requests. Credentials: ASC_KEY_ID,
ASC_ISSUER_ID, and ASC_KEY_PATH or ~/.appstoreconnect/private_keys/AuthKey_<id>.p8.
Apple upload protocol: https://developer.apple.com/documentation/
appstoreconnectapi/uploading-assets-to-app-store-connect
"""
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
from urllib.parse import urlsplit
import zlib

API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.waterquest.hydration"
VERSION = os.environ.get("PUBLISH_VERSION", "5.0.2")
BUILD_NUMBER = os.environ.get("PUBLISH_BUILD", "14")
REPO_ROOT = Path(__file__).resolve().parent.parent
EDITABLE_STATES = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
REVIEW_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING", "UNRESOLVED_ISSUES"}
# ASC retains the APP_IPHONE_67 enum for the current largest iPhone display.
PORTRAIT_SIZES = {
    "APP_IPHONE_67": {(1260, 2736), (1290, 2796), (1320, 2868)},
    "APP_IPAD_PRO_3GEN_129": {(2048, 2732)},
    "APP_IPAD_PRO_3GEN_11": {(1668, 2388)},
}


class ReleaseError(RuntimeError):
    """The release cannot safely proceed without correcting its inputs/state."""


@dataclass(frozen=True)
class Screenshot:
    path: Path
    data: bytes
    checksum: str
    width: int
    height: int


@dataclass(frozen=True)
class ReleasePlan:
    version: str
    build_number: str
    whats_new: str
    description: str
    locales: dict


def token() -> str:
    import jwt
    key_id = os.environ["ASC_KEY_ID"]
    key_path = os.environ.get("ASC_KEY_PATH", os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"))
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        Path(key_path).read_text(), algorithm="ES256", headers={"kid": key_id},
    )


def http_request(method, url, **kwargs):
    # Lazy imports keep validation and mocked tests independent of credentials/deps.
    import requests
    return requests.request(method, url, **kwargs)


def req(method: str, path: str, payload=None, params=None):
    if not path.startswith("/v1/"):
        raise ReleaseError("Unsupported ASC API path")
    for attempt in range(3):
        response = http_request(
            method, f"{API}{path}",
            headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
            json=payload, params=params, timeout=60, allow_redirects=False,
        )
        # Do not retry uncertain POST/PATCH mutations automatically.
        if method == "GET" and response.status_code in (429, 500, 502, 503, 504) and attempt < 2:
            time.sleep(2 ** attempt)
            continue
        if not 200 <= response.status_code < 300:
            raise ReleaseError(f"ASC API {method} {path.split('?')[0]} -> {response.status_code}: {response.text[:2000]}")
        return response.json() if response.text else {}


def get_all(path, params=None):
    data = []
    while path:
        result = req("GET", path, params=params)
        data.extend(result.get("data", []))
        next_url = result.get("links", {}).get("next")
        if not next_url:
            break
        parsed = urlsplit(next_url)
        if f"{parsed.scheme}://{parsed.netloc}" != API:
            raise ReleaseError("Refusing a pagination link outside App Store Connect")
        path, params = parsed.path + ("?" + parsed.query if parsed.query else ""), None
    return data


def app_id():
    data = get_all("/v1/apps", params={"filter[bundleId]": BUNDLE_ID})
    if len(data) != 1:
        raise ReleaseError(f"Expected exactly one app with bundle ID {BUNDLE_ID}")
    return data[0]["id"]


def versions(app):
    return get_all(f"/v1/apps/{app}/appStoreVersions", params={"limit": "200"})


def localizations(version_id):
    return get_all(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations", params={"limit": "200"})


def screenshot_sets(localization_id):
    return get_all(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets", params={"limit": "200"})


def screenshots(set_id):
    # This related-resource endpoint returns the set's display order.
    return get_all(f"/v1/appScreenshotSets/{set_id}/appScreenshots", params={"limit": "200"})


def screenshot_state(screenshot):
    return (screenshot.get("attributes", {}).get("assetDeliveryState") or {}).get("state")


def screenshot_inventory(loc_id):
    inventory = []
    for screenshot_set in screenshot_sets(loc_id):
        assets = []
        for screenshot in screenshots(screenshot_set["id"]):
            attributes = screenshot["attributes"]
            # Explicit allowlist: reservation upload URLs must never enter logs.
            assets.append({"id": screenshot["id"], **{key: attributes.get(key) for key in (
                "fileName", "fileSize", "sourceFileChecksum", "assetDeliveryState", "imageAsset")}})
        inventory.append({"id": screenshot_set["id"], "displayType": screenshot_set["attributes"]["screenshotDisplayType"],
                          "count": len(assets), "assets": assets})
    return inventory


def cmd_fetch():
    app = app_id()
    builds = get_all("/v1/builds", params={"filter[app]": app, "sort": "-uploadedDate", "limit": "20", "include": "preReleaseVersion"})
    out = {"appId": app, "builds": [], "versions": []}
    for build in builds:
        prerelease = req("GET", f"/v1/builds/{build['id']}/preReleaseVersion")["data"]
        out["builds"].append({"id": build["id"], **build["attributes"], "preReleaseVersion": prerelease["attributes"]})
    for version in versions(app):
        entry = {"id": version["id"], **version["attributes"], "localizations": [],
                 "build": req("GET", f"/v1/appStoreVersions/{version['id']}/relationships/build").get("data")}
        for loc in localizations(version["id"]):
            entry["localizations"].append({"id": loc["id"], **loc["attributes"], "screenshots": screenshot_inventory(loc["id"])})
        out["versions"].append(entry)
    out["reviewSubmissions"] = get_all("/v1/reviewSubmissions", params={"filter[app]": app, "limit": "200"})
    print(json.dumps(out, indent=2))


def read_screenshot(path, display_type):
    """Validate complete noninterlaced RGB PNGs and exact display dimensions."""
    if display_type not in PORTRAIT_SIZES:
        raise ReleaseError(f"Unsupported screenshot display type: {display_type}")
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ReleaseError(f"Screenshot is not a PNG: {path}")
    offset, dimensions, compressed, ended = 8, None, bytearray(), False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ReleaseError(f"Truncated PNG: {path}")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ReleaseError(f"Truncated PNG chunk: {path}")
        body = data[offset + 8:end - 4]
        if zlib.crc32(kind + body) != struct.unpack_from(">I", data, end - 4)[0]:
            raise ReleaseError(f"PNG checksum failed: {path}")
        if offset == 8 and kind != b"IHDR":
            raise ReleaseError(f"Missing PNG header: {path}")
        if kind == b"IHDR":
            if length != 13 or dimensions is not None:
                raise ReleaseError(f"Invalid PNG header: {path}")
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", body)
            if (depth, color, compression, filtering, interlace) != (8, 2, 0, 0, 0):
                raise ReleaseError(f"PNG must be 8-bit RGB with no alpha and no interlacing: {path}")
            allowed = PORTRAIT_SIZES[display_type]
            if (width, height) not in allowed and (height, width) not in allowed:
                raise ReleaseError(f"Invalid {display_type} dimensions {width}x{height}: {path}")
            dimensions = (width, height)
        elif kind == b"tRNS":
            raise ReleaseError(f"PNG transparency is not allowed: {path}")
        elif kind == b"IDAT":
            compressed.extend(body)
        elif kind == b"IEND":
            if length != 0 or end != len(data):
                raise ReleaseError(f"Invalid PNG end: {path}")
            ended = True
        offset = end
    if not ended or dimensions is None or not compressed:
        raise ReleaseError(f"Incomplete PNG: {path}")
    width, height = dimensions
    expected = height * (1 + width * 3)
    try:
        decoder = zlib.decompressobj()
        pixels = decoder.decompress(compressed, expected + 1)
        if not decoder.eof or decoder.unused_data or len(pixels) != expected:
            raise ReleaseError(f"Invalid PNG pixel data: {path}")
        if any(pixels[row * (width * 3 + 1)] > 4 for row in range(height)):
            raise ReleaseError(f"Invalid PNG row filter: {path}")
    except zlib.error as error:
        raise ReleaseError(f"Invalid PNG compression: {path}") from error
    return Screenshot(path, data, hashlib.md5(data).hexdigest(), width, height)


def load_plan(root=None, version=None, build_number=None, manifest_path=None):
    root = (root or REPO_ROOT).resolve()
    version, build_number = version or VERSION, build_number or BUILD_NUMBER
    manifest_path = Path(manifest_path or os.environ.get("PUBLISH_SCREENSHOTS", f"appstore-screenshots/release-{version}/manifest.json"))
    if not manifest_path.is_absolute():
        manifest_path = root / manifest_path
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("version") != version:
        raise ReleaseError("Screenshot manifest version must exactly match PUBLISH_VERSION")
    locale_map = manifest.get("locales")
    if not isinstance(locale_map, dict) or not locale_map:
        raise ReleaseError("Screenshot manifest must specify at least one locale")
    desired = {}
    for locale, sets in locale_map.items():
        if not isinstance(locale, str) or not locale or not isinstance(sets, dict) or not sets:
            raise ReleaseError("Screenshot locale must contain explicit display sets")
        desired[locale] = {}
        for display_type, paths in sets.items():
            if not isinstance(paths, list) or not 1 <= len(paths) <= 10:
                raise ReleaseError(f"{locale}/{display_type} must contain 1–10 screenshots")
            assets = []
            for relative in paths:
                if not isinstance(relative, str):
                    raise ReleaseError("Screenshot paths must be strings relative to the repository")
                path = (root / relative).resolve()
                if not path.is_relative_to(root):
                    raise ReleaseError("Screenshot paths must stay inside the repository")
                assets.append(read_screenshot(path, display_type))
            if len({asset.checksum for asset in assets}) != len(assets):
                raise ReleaseError(f"Duplicate screenshot content in {locale}/{display_type}")
            desired[locale][display_type] = assets
    notes = (root / "docs" / f"release-notes-{version}.md").read_text()
    whats_new = "\n".join(line for line in notes.splitlines() if not line.lstrip().startswith("#")).strip()
    description = (root / "docs/appstore-description.txt").read_text().strip()
    if not whats_new or len(whats_new) > 4000:
        raise ReleaseError("What's New must contain 1–4000 characters")
    if not description or len(description) > 4000:
        raise ReleaseError("Description must contain 1–4000 characters")
    return ReleasePlan(version, build_number, whats_new, description, desired)


def find_build(app, version, build_number):
    prereleases = get_all("/v1/preReleaseVersions", params={"filter[app]": app, "filter[version]": version, "filter[platform]": "IOS", "limit": "200"})
    matching = [item for item in prereleases if item["attributes"]["version"] == version and item["attributes"]["platform"] == "IOS"]
    if not matching:
        return None
    if len(matching) != 1:
        raise ReleaseError(f"Ambiguous prerelease version {version}")
    candidates = get_all("/v1/builds", params={"filter[app]": app, "filter[preReleaseVersion]": matching[0]["id"], "filter[version]": build_number, "limit": "200"})
    candidates = [build for build in candidates if build["attributes"]["version"] == build_number and not build["attributes"].get("expired", True)]
    if len(candidates) > 1:
        raise ReleaseError(f"Ambiguous build {version} ({build_number})")
    return candidates[0] if candidates else None


def wait_for_build(app, plan):
    deadline = time.monotonic() + 45 * 60
    while time.monotonic() < deadline:
        build = find_build(app, plan.version, plan.build_number)
        state = build and build["attributes"].get("processingState")
        if state == "VALID":
            return build
        if state in {"FAILED", "INVALID"}:
            raise ReleaseError(f"Build {plan.version} ({plan.build_number}) is {state}")
        print(f"Build {plan.version} ({plan.build_number}): {state or 'not available'}; waiting 30 seconds", flush=True)
        time.sleep(30)
    raise ReleaseError(f"Build {plan.version} ({plan.build_number}) did not become VALID")


def ensure_version(app, version_string):
    existing = [version for version in versions(app) if version["attributes"].get("platform") == "IOS" and version["attributes"]["versionString"] == version_string]
    if len(existing) > 1:
        raise ReleaseError(f"Ambiguous App Store version {version_string}")
    if existing:
        return existing[0]
    return req("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": version_string, "releaseType": "AFTER_APPROVAL"},
        "relationships": {"app": {"data": {"type": "apps", "id": app}}},
    }})["data"]


def wait_for_screenshot(screenshot_id, checksum, timeout=600):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        screenshot = req("GET", f"/v1/appScreenshots/{screenshot_id}")["data"]
        state = screenshot_state(screenshot)
        if state == "COMPLETE":
            if (screenshot["attributes"].get("sourceFileChecksum") or "").lower() != checksum.lower():
                raise ReleaseError(f"Screenshot {screenshot_id} checksum differs from the local asset")
            return screenshot
        if state == "FAILED":
            raise ReleaseError(f"Screenshot {screenshot_id} processing FAILED")
        time.sleep(5)
    raise ReleaseError(f"Screenshot {screenshot_id} processing did not complete")


def upload_parts(operations, data):
    offset = 0
    # Validate every operation before sending any bytes. URLs remain confidential.
    for operation in operations:
        length = operation.get("length", 0)
        if operation.get("offset") != offset or not isinstance(length, int) or length <= 0:
            raise ReleaseError("Screenshot upload ranges must cover the file sequentially")
        parsed = urlsplit(operation.get("url", ""))
        if operation.get("method") != "PUT" or parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
            raise ReleaseError("Invalid screenshot upload operation")
        offset += length
    if not operations or offset != len(data):
        raise ReleaseError("Screenshot upload ranges do not match the file size")
    for operation in operations:
        headers = {header["name"]: header["value"] for header in operation.get("requestHeaders", [])}
        if any(name.lower() == "authorization" for name in headers):
            raise ReleaseError("Unexpected authorization header in screenshot upload operation")
        offset, length = operation["offset"], operation["length"]
        for attempt in range(3):
            try:
                response = http_request("PUT", operation["url"], headers=headers, data=data[offset:offset + length], timeout=120, allow_redirects=False)
                if 200 <= response.status_code < 300:
                    break
                retryable = response.status_code in (429, 500, 502, 503, 504)
                status = response.status_code
            except Exception:
                # Requests exceptions may contain the signed URL; never print them.
                retryable, status = True, "network failure"
            if not retryable or attempt == 2:
                raise ReleaseError(f"Screenshot upload failed ({status}); reservation can be retried") from None
            time.sleep(2 ** attempt)


def upload_screenshot(set_id, asset):
    reservation = req("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots", "attributes": {"fileName": asset.path.name, "fileSize": len(asset.data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
    }})["data"]
    screenshot_id = reservation["id"]
    upload_parts(reservation["attributes"].get("uploadOperations") or [], asset.data)
    req("PATCH", f"/v1/appScreenshots/{screenshot_id}", {"data": {
        "type": "appScreenshots", "id": screenshot_id, "attributes": {"uploaded": True, "sourceFileChecksum": asset.checksum},
    }})
    return wait_for_screenshot(screenshot_id, asset.checksum)


def verify_screenshot_set(set_id, assets):
    actual = screenshots(set_id)
    if len(actual) != len(assets):
        raise ReleaseError(f"Screenshot set {set_id} count does not match the manifest")
    for screenshot, asset in zip(actual, assets):
        if screenshot_state(screenshot) != "COMPLETE" or (screenshot["attributes"].get("sourceFileChecksum") or "").lower() != asset.checksum:
            raise ReleaseError(f"Screenshot set {set_id} order, processing state, or checksum mismatch")
    return actual


def sync_screenshot_set(set_id, assets):
    current = screenshots(set_id)
    if len(current) > 10:
        raise ReleaseError(f"Screenshot set {set_id} unexpectedly exceeds 10 items")
    desired_checksums = {asset.checksum for asset in assets}
    reusable = {}
    for screenshot in current:
        checksum = (screenshot["attributes"].get("sourceFileChecksum") or "").lower()
        if checksum not in desired_checksums or checksum in reusable:
            continue
        if screenshot_state(screenshot) in {"UPLOAD_COMPLETE", "PROCESSING"}:
            screenshot = wait_for_screenshot(screenshot["id"], checksum)
        if screenshot_state(screenshot) == "COMPLETE":
            reusable[checksum] = screenshot
    retained_ids = {item["id"] for item in reusable.values()}
    obsolete = [item for item in current if item["id"] not in retained_ids]
    # A failed retry can leave a reservation in the last slot. Reclaim that
    # incomplete asset before removing any usable original screenshot.
    obsolete.sort(key=lambda item: screenshot_state(item) == "COMPLETE")
    count, ordered = len(current), []
    for asset in assets:
        screenshot = reusable.get(asset.checksum)
        if screenshot is None:
            # Keep old completed assets until replacement succeeds wherever possible.
            # At Apple's 10-item limit, free only one obsolete slot at a time.
            if count >= 10:
                if not obsolete:
                    raise ReleaseError(f"No safe replacement slot in screenshot set {set_id}")
                old = obsolete.pop(0)
                req("DELETE", f"/v1/appScreenshots/{old['id']}")
                count -= 1
            screenshot = upload_screenshot(set_id, asset)
            count += 1
        ordered.append({"type": "appScreenshots", "id": screenshot["id"]})
    for old in obsolete:
        req("DELETE", f"/v1/appScreenshots/{old['id']}")
    req("PATCH", f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots", {"data": ordered})
    verify_screenshot_set(set_id, assets)


def sync_localization(localization, display_sets, plan):
    loc_id = localization["id"]
    metadata = {"whatsNew": plan.whats_new, "description": plan.description}
    if any(localization["attributes"].get(key) != value for key, value in metadata.items()):
        req("PATCH", f"/v1/appStoreVersionLocalizations/{loc_id}", {"data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": metadata}})
    existing = {item["attributes"]["screenshotDisplayType"]: item for item in screenshot_sets(loc_id)}
    for display_type, assets in display_sets.items():
        screenshot_set = existing.get(display_type)
        if screenshot_set is None:
            screenshot_set = req("POST", "/v1/appScreenshotSets", {"data": {
                "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}},
            }})["data"]
        sync_screenshot_set(screenshot_set["id"], assets)
        print(f"Verified {localization['attributes']['locale']}/{display_type}: {len(assets)} screenshots", flush=True)


def verify_prepared(version_id, build_id, plan):
    version = req("GET", f"/v1/appStoreVersions/{version_id}")["data"]
    if version["attributes"].get("versionString") != plan.version or version["attributes"].get("platform") != "IOS":
        raise ReleaseError("App Store version readback mismatch")
    if version["attributes"].get("releaseType") != "AFTER_APPROVAL":
        raise ReleaseError("Release type must be AFTER_APPROVAL")
    attached = req("GET", f"/v1/appStoreVersions/{version_id}/relationships/build").get("data")
    if not attached or attached["id"] != build_id:
        raise ReleaseError("Attached build readback mismatch")
    build = req("GET", f"/v1/builds/{build_id}")["data"]
    prerelease = req("GET", f"/v1/builds/{build_id}/preReleaseVersion")["data"]
    if (build["attributes"].get("version") != plan.build_number or build["attributes"].get("processingState") != "VALID"
            or build["attributes"].get("expired", True) or prerelease["attributes"].get("version") != plan.version
            or prerelease["attributes"].get("platform") != "IOS"):
        raise ReleaseError("Attached build must be VALID and match the exact marketing version and build number")
    existing = {item["attributes"]["locale"]: item for item in localizations(version_id)}
    for locale, desired_sets in plan.locales.items():
        loc = existing.get(locale)
        if not loc or loc["attributes"].get("whatsNew") != plan.whats_new or loc["attributes"].get("description") != plan.description:
            raise ReleaseError(f"Metadata readback mismatch for {locale}")
        sets = {item["attributes"]["screenshotDisplayType"]: item for item in screenshot_sets(loc["id"])}
        for display_type, assets in desired_sets.items():
            if display_type not in sets:
                raise ReleaseError(f"Missing screenshot set {locale}/{display_type}")
            verify_screenshot_set(sets[display_type]["id"], assets)
    return version


def prepare():
    plan = load_plan()  # No provider access until every file and metadata field validates.
    app = app_id()
    build = wait_for_build(app, plan)
    version = ensure_version(app, plan.version)
    state = version["attributes"].get("appVersionState")
    if state not in EDITABLE_STATES:
        # Idempotent retry of an already submitted release must verify, never alter it.
        verify_prepared(version["id"], build["id"], plan)
        return app, version, plan
    existing = {item["attributes"]["locale"]: item for item in localizations(version["id"])}
    missing = set(plan.locales) - set(existing)
    if missing:
        raise ReleaseError(f"Expected existing App Store localizations: {', '.join(sorted(missing))}; refusing to invent locale metadata")
    if version["attributes"].get("releaseType") != "AFTER_APPROVAL":
        req("PATCH", f"/v1/appStoreVersions/{version['id']}", {"data": {"type": "appStoreVersions", "id": version["id"], "attributes": {"releaseType": "AFTER_APPROVAL"}}})
    for locale, display_sets in plan.locales.items():
        sync_localization(existing[locale], display_sets, plan)
    attached = req("GET", f"/v1/appStoreVersions/{version['id']}/relationships/build").get("data")
    if not attached or attached["id"] != build["id"]:
        req("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build", {"data": {"type": "builds", "id": build["id"]}})
    version = verify_prepared(version["id"], build["id"], plan)
    print(f"PREPARED {plan.version} ({plan.build_number}): metadata, screenshot order/checksums, and build verified; AFTER_APPROVAL", flush=True)
    return app, version, plan


def submit_review(app, version_id):
    active = [item for item in get_all("/v1/reviewSubmissions", params={"filter[app]": app, "limit": "200"})
              if item["attributes"].get("state") in REVIEW_STATES and item["attributes"].get("platform", "IOS") == "IOS"]
    if len(active) > 1:
        raise ReleaseError("Multiple active iOS review submissions need reconciliation")
    submission = active[0] if active else None
    needs_item = True
    if submission:
        items = get_all(f"/v1/reviewSubmissions/{submission['id']}/items", params={"include": "appStoreVersion", "limit": "200"})
        identities = [item.get("relationships", {}).get("appStoreVersion", {}).get("data") for item in items]
        if any(not item or item["id"] != version_id for item in identities) or len(items) > 1:
            raise ReleaseError("An active review submission contains another version or different review items")
        needs_item = not items
        state = submission["attributes"]["state"]
        if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}:
            if needs_item:
                raise ReleaseError("Active review does not contain the expected App Store version")
            print(f"Already submitted: {submission['id']} ({state})", flush=True)
            return submission
        if state == "UNRESOLVED_ISSUES":
            raise ReleaseError("Existing review has unresolved issues; inspect Apple's feedback before resubmitting")
    else:
        submission = req("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app}}},
        }})["data"]
    if needs_item:
        req("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
        }}})
    result = req("PATCH", f"/v1/reviewSubmissions/{submission['id']}", {"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True},
    }})["data"]
    return result


def cmd_prepare():
    prepare()


def wait_for_review(submission_id, timeout=300):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        submission = req("GET", f"/v1/reviewSubmissions/{submission_id}")["data"]
        state = submission["attributes"].get("state")
        if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETE"}:
            return submission
        if state in {"CANCELING", "CANCELED", "UNRESOLVED_ISSUES"}:
            raise ReleaseError(f"Review submission {submission_id} is {state}")
        time.sleep(5)
    raise ReleaseError(f"Review submission {submission_id} has not confirmed submission; inspect its state before retrying")


def cmd_publish():
    app, version, plan = prepare()
    state = version["attributes"].get("appVersionState")
    if state in {"ACCEPTED", "PENDING_APPLE_RELEASE", "READY_FOR_DISTRIBUTION", "PROCESSING_FOR_DISTRIBUTION", "READY_FOR_SALE", "PROCESSING_FOR_APP_STORE"}:
        print(f"Version {plan.version} ({plan.build_number}) is already {state}")
        return
    submission = submit_review(app, version["id"])
    submission = wait_for_review(submission["id"])
    print(f"SUBMITTED {plan.version} ({plan.build_number}) for App Store review; submission {submission['id']}, state {submission['attributes'].get('state')}. Automatic release follows approval.")


if __name__ == "__main__":
    commands = {"fetch": cmd_fetch, "prepare": cmd_prepare, "publish": cmd_publish}
    mode = sys.argv[1] if len(sys.argv) > 1 else "fetch"
    if mode not in commands:
        sys.exit("Usage: asc_publish.py [fetch|prepare|publish]")
    try:
        commands[mode]()
    except (ReleaseError, OSError, ValueError, KeyError) as error:
        sys.exit(str(error))
