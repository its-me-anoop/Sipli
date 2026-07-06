#!/usr/bin/env python3
"""App Store Connect publish automation for Sipli.

Modes:
  fetch    Dump current app/version/build/metadata state as JSON (read-only).
  publish  Ensure version exists, set What's New (+ optional description),
           wait for the build, attach it, and submit for review.

Requires env: ASC_KEY_ID, ASC_ISSUER_ID and the .p8 at
~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 (or ASC_KEY_PATH).

Deps: PyJWT, cryptography, requests.
"""
import json
import os
import sys
import time
from pathlib import Path

import jwt
import requests

API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.waterquest.hydration"
VERSION = os.environ.get("PUBLISH_VERSION", "5.0")
BUILD_NUMBER = os.environ.get("PUBLISH_BUILD", "12")
REPO_ROOT = Path(__file__).resolve().parent.parent
WHATS_NEW_FILE = REPO_ROOT / "docs" / "release-notes-5.0.md"
DESCRIPTION_FILE = REPO_ROOT / "docs" / "appstore-description.txt"  # optional


def token() -> str:
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ.get(
        "ASC_KEY_PATH",
        os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"),
    )
    private_key = Path(key_path).read_text()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id},
    )


def req(method: str, path: str, payload=None, params=None):
    r = requests.request(
        method,
        f"{API}{path}",
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
        json=payload,
        params=params,
        timeout=60,
    )
    if r.status_code >= 400:
        sys.exit(f"ASC API {method} {path} -> {r.status_code}: {r.text[:2000]}")
    return r.json() if r.text else {}


def app_id() -> str:
    data = req("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not data:
        sys.exit(f"no app with bundle id {BUNDLE_ID}")
    return data[0]["id"]


def latest_builds(app):
    return req(
        "GET",
        "/v1/builds",
        params={
            "filter[app]": app,
            "sort": "-uploadedDate",
            "limit": "5",
            "fields[builds]": "version,processingState,uploadedDate,expired",
        },
    )["data"]


def versions(app):
    return req(
        "GET",
        f"/v1/apps/{app}/appStoreVersions",
        params={
            "limit": "5",
            "fields[appStoreVersions]": "versionString,appVersionState,releaseType,platform,createdDate",
        },
    )["data"]


def localizations(version_id):
    return req(
        "GET",
        f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        params={"limit": "10"},
    )["data"]


def screenshot_inventory(loc_id):
    sets = req(
        "GET",
        f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets",
        params={"limit": "20", "include": "appScreenshots"},
    )
    out = []
    for s in sets["data"]:
        count = len((s.get("relationships", {}).get("appScreenshots", {}).get("data") or []))
        out.append({"displayType": s["attributes"]["screenshotDisplayType"], "count": count})
    return out


def whats_new_text() -> str:
    lines = WHATS_NEW_FILE.read_text().splitlines()
    body = [l for l in lines if not l.startswith("#")]
    text = "\n".join(body).strip()
    if len(text) > 4000:
        sys.exit("What's New exceeds 4000 characters")
    return text


def cmd_fetch():
    app = app_id()
    out = {"appId": app, "builds": [], "versions": []}
    for b in latest_builds(app):
        out["builds"].append({"id": b["id"], **b["attributes"]})
    for v in versions(app):
        entry = {"id": v["id"], **v["attributes"], "localizations": []}
        for loc in localizations(v["id"]):
            a = loc["attributes"]
            entry["localizations"].append(
                {
                    "id": loc["id"],
                    "locale": a["locale"],
                    "whatsNew": a.get("whatsNew"),
                    "descriptionHead": (a.get("description") or "")[:400],
                    "descriptionTail": (a.get("description") or "")[-400:],
                    "descriptionLength": len(a.get("description") or ""),
                    "keywords": a.get("keywords"),
                    "screenshots": screenshot_inventory(loc["id"]),
                }
            )
        out["versions"].append(entry)
    print(json.dumps(out, indent=2))


def cmd_publish():
    app = app_id()

    # 1. Ensure the target version exists.
    existing = {v["attributes"]["versionString"]: v for v in versions(app)}
    prev_release_type = None
    for v in versions(app):
        if v["attributes"]["versionString"] != VERSION:
            prev_release_type = v["attributes"].get("releaseType")
            break
    if VERSION in existing:
        version = existing[VERSION]
        print(f"version {VERSION} exists (state {version['attributes']['appVersionState']})")
    else:
        payload = {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "IOS",
                    "versionString": VERSION,
                    "releaseType": prev_release_type or "AFTER_APPROVAL",
                },
                "relationships": {"app": {"data": {"type": "apps", "id": app}}},
            }
        }
        version = req("POST", "/v1/appStoreVersions", payload)["data"]
        print(f"created version {VERSION} (releaseType {prev_release_type or 'AFTER_APPROVAL'})")
    version_id = version["id"]

    # 2. Copy: What's New always; description only when the file exists.
    wn = whats_new_text()
    description = DESCRIPTION_FILE.read_text().strip() if DESCRIPTION_FILE.exists() else None
    for loc in localizations(version_id):
        attrs = {"whatsNew": wn}
        if description:
            attrs["description"] = description
        req(
            "PATCH",
            f"/v1/appStoreVersionLocalizations/{loc['id']}",
            {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": attrs}},
        )
        print(f"updated localization {loc['attributes']['locale']}"
              + (" (whatsNew+description)" if description else " (whatsNew)"))
        shots = screenshot_inventory(loc["id"])
        total = sum(s["count"] for s in shots)
        print(f"  screenshots on this version: {total} across {len(shots)} sets {shots}")
        if total == 0:
            sys.exit("no screenshots present on the version — aborting before submission")

    # 3. Wait for the build to finish processing, then attach.
    deadline = time.time() + 45 * 60
    build = None
    while time.time() < deadline:
        for b in latest_builds(app):
            if b["attributes"]["version"] == BUILD_NUMBER and not b["attributes"]["expired"]:
                build = b
                break
        state = build and build["attributes"]["processingState"]
        if state == "VALID":
            break
        if state in ("FAILED", "INVALID"):
            sys.exit(f"build {BUILD_NUMBER} processing state: {state}")
        print(f"build {BUILD_NUMBER}: {state or 'not visible yet'} — waiting 60s")
        time.sleep(60)
    if not build or build["attributes"]["processingState"] != "VALID":
        sys.exit(f"build {BUILD_NUMBER} not VALID before deadline")

    req(
        "PATCH",
        f"/v1/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build["id"]}},
    )
    print(f"attached build {BUILD_NUMBER} ({build['id']})")

    # 4. Submit for review via the review submissions flow.
    in_flight = req(
        "GET",
        "/v1/reviewSubmissions",
        params={"filter[app]": app, "filter[state]": "READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES"},
    )["data"]
    if in_flight:
        sys.exit(f"a review submission is already in flight: {in_flight[0]['id']}")

    submission = req(
        "POST",
        "/v1/reviewSubmissions",
        {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": app}}},
            }
        },
    )["data"]
    req(
        "POST",
        "/v1/reviewSubmissionItems",
        {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                },
            }
        },
    )
    req(
        "PATCH",
        f"/v1/reviewSubmissions/{submission['id']}",
        {"data": {"type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}},
    )
    print(f"SUBMITTED version {VERSION} (build {BUILD_NUMBER}) for App Store review — submission {submission['id']}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "fetch"
    {"fetch": cmd_fetch, "publish": cmd_publish}[mode]()
