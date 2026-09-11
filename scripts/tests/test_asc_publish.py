"""Release safety checks; these tests never contact App Store Connect."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import zlib

SPEC = importlib.util.spec_from_file_location("asc_publish", Path(__file__).parents[1] / "asc_publish.py")
asc = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = asc
SPEC.loader.exec_module(asc)


def png(width=1290, height=2796, color=2):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    channels = 4 if color == 6 else 3
    pixels = (b"\0" + b"\x80" * width * channels) * height
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


def shot(identity, checksum, state="COMPLETE"):
    return {"id": identity, "type": "appScreenshots", "attributes": {
        "sourceFileChecksum": checksum, "fileName": identity + ".png",
        "assetDeliveryState": {"state": state}}}


class ReleaseSafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def asset(self, name="screenshot.png", data=b"screenshot"):
        return asc.Screenshot(self.root / name, data, hashlib.md5(data).hexdigest(), 1290, 2796)

    def test_manifest_validates_all_files_and_rejects_alpha_before_api_calls(self):
        (self.root / "docs").mkdir()
        (self.root / "docs/release-notes-5.0.2.md").write_text("# Sipli\n\nWater responds to tilt.")
        (self.root / "docs/appstore-description.txt").write_text("Track your water.")
        (self.root / "good.png").write_bytes(png())
        (self.root / "alpha.png").write_bytes(png(color=6))
        manifest = self.root / "manifest.json"
        manifest.write_text(json.dumps({"version": "5.0.2", "locales": {"en-US": {"APP_IPHONE_67": ["good.png", "alpha.png"]}}}))
        with patch.object(asc, "req") as api:
            with self.assertRaisesRegex(asc.ReleaseError, "RGB|alpha"):
                asc.load_plan(self.root, "5.0.2", "14", manifest)
            api.assert_not_called()

    def test_manifest_version_mismatch_is_rejected(self):
        manifest = self.root / "manifest.json"
        manifest.write_text(json.dumps({"version": "5.0", "locales": {}}))
        with self.assertRaisesRegex(asc.ReleaseError, "version"):
            asc.load_plan(self.root, "5.0.2", "14", manifest)

    def test_png_rejects_wrong_dimensions_and_corruption(self):
        path = self.root / "test.png"
        path.write_bytes(png(width=12, height=20))
        with self.assertRaisesRegex(asc.ReleaseError, "dimensions"):
            asc.read_screenshot(path, "APP_IPHONE_67")
        path.write_bytes(png()[:-8])
        with self.assertRaises(asc.ReleaseError):
            asc.read_screenshot(path, "APP_IPHONE_67")

    def test_upload_uses_exact_byte_ranges_without_api_authorization_and_retries(self):
        asset = self.asset(data=b"abcdefgh")
        reservation = shot("new", None, "AWAITING_UPLOAD")
        reservation["attributes"]["uploadOperations"] = [
            {"method": "PUT", "url": "https://upload.apple.com/signed-secret", "offset": 0, "length": 3,
             "requestHeaders": [{"name": "Content-Type", "value": "image/png"}]},
            {"method": "PUT", "url": "https://upload.apple.com/signed-secret", "offset": 3, "length": 5,
             "requestHeaders": []}]
        with patch.object(asc, "req", side_effect=[{"data": reservation}, {"data": shot("new", asset.checksum, "UPLOAD_COMPLETE")}]) as api, \
             patch.object(asc, "http_request", side_effect=[Mock(status_code=503), Mock(status_code=200), Mock(status_code=200)]) as upload, \
             patch.object(asc.time, "sleep"), patch.object(asc, "wait_for_screenshot", return_value=shot("new", asset.checksum)):
            self.assertEqual(asc.upload_screenshot("set", asset)["id"], "new")
        self.assertEqual([call.kwargs["data"] for call in upload.call_args_list], [b"abc", b"abc", b"defgh"])
        self.assertTrue(all("Authorization" not in call.kwargs["headers"] for call in upload.call_args_list))
        self.assertTrue(all(call.kwargs["allow_redirects"] is False for call in upload.call_args_list))
        self.assertEqual(api.call_args_list[-1].args[2]["data"]["attributes"], {"uploaded": True, "sourceFileChecksum": asset.checksum})

    def test_upload_rejects_incomplete_ranges_before_transferring(self):
        asset = self.asset(data=b"abcdefgh")
        reservation = shot("new", None, "AWAITING_UPLOAD")
        reservation["attributes"]["uploadOperations"] = [{"method": "PUT", "url": "https://upload.apple.com/private", "offset": 1, "length": 7, "requestHeaders": []}]
        with patch.object(asc, "req", return_value={"data": reservation}), patch.object(asc, "http_request") as upload:
            with self.assertRaisesRegex(asc.ReleaseError, "ranges"):
                asc.upload_screenshot("set", asset)
            upload.assert_not_called()

    def test_completed_upload_with_wrong_checksum_cannot_pass(self):
        clock = [0.0]
        with patch.object(asc, "req", return_value={"data": shot("new", "incorrect")}) as api, \
             patch.object(asc.time, "monotonic", side_effect=lambda: clock[0]), \
             patch.object(asc.time, "sleep", side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)):
            with self.assertRaisesRegex(asc.ReleaseError, "checksum"):
                asc.wait_for_screenshot("new", "expected")
        self.assertGreater(api.call_count, 1)
        self.assertLessEqual(clock[0], 30)

    def test_reuses_matching_screenshots_and_orders_without_reupload(self):
        first, second = self.asset("first.png", b"a"), self.asset("second.png", b"b")
        current = [shot("second", second.checksum), shot("first", first.checksum)]
        ordered = [current[1], current[0]]
        with patch.object(asc, "screenshots", side_effect=[current, ordered]), patch.object(asc, "req") as api, patch.object(asc, "upload_screenshot") as upload:
            asc.sync_screenshot_set("set", [first, second])
            upload.assert_not_called()
            self.assertEqual(api.call_args.args[2]["data"], [{"type": "appScreenshots", "id": "first"}, {"type": "appScreenshots", "id": "second"}])

    def test_failure_uploading_does_not_delete_existing_when_capacity_available(self):
        asset = self.asset()
        with patch.object(asc, "screenshots", return_value=[shot("old", "old")]), \
             patch.object(asc, "upload_screenshot", side_effect=asc.ReleaseError("upload failed")), patch.object(asc, "req") as api:
            with self.assertRaises(asc.ReleaseError):
                asc.sync_screenshot_set("set", [asset])
            self.assertFalse(any(call.args[0] == "DELETE" for call in api.call_args_list))

    def test_full_set_removes_only_one_obsolete_slot_before_successful_replacement(self):
        asset = self.asset()
        current = [shot(str(i), str(i)) for i in range(10)]
        events = []
        def api(method, path, payload=None, params=None):
            events.append((method, path))
            return {}
        def upload(set_id, value):
            events.append(("UPLOAD", set_id))
            return shot("new", asset.checksum)
        with patch.object(asc, "screenshots", side_effect=[current, [shot("new", asset.checksum)]]), \
             patch.object(asc, "req", side_effect=api), patch.object(asc, "upload_screenshot", side_effect=upload):
            asc.sync_screenshot_set("set", [asset])
        upload_position = next(i for i, event in enumerate(events) if event[0] == "UPLOAD")
        self.assertEqual(sum(event[0] == "DELETE" for event in events[:upload_position]), 1)
        self.assertEqual(sum(event[0] == "DELETE" for event in events), 10)

    def test_target_build_is_scoped_to_marketing_version(self):
        prerelease = {"id": "pre5", "attributes": {"version": "5.0.2", "platform": "IOS"}}
        build = {"id": "b14", "attributes": {"version": "14", "processingState": "VALID", "expired": False}}
        with patch.object(asc, "get_all", side_effect=[[prerelease], [build]]) as api:
            self.assertEqual(asc.find_build("app", "5.0.2", "14"), build)
            self.assertEqual(api.call_args.kwargs["params"]["filter[preReleaseVersion]"], "pre5")

    def test_new_version_is_created_as_automatic_release_without_submission(self):
        with patch.object(asc, "versions", return_value=[]), patch.object(asc, "req", return_value={"data": {"id": "new"}}) as api:
            self.assertEqual(asc.ensure_version("app", "5.0.2")["id"], "new")
        self.assertEqual(api.call_count, 1)
        payload = api.call_args.args[2]["data"]["attributes"]
        self.assertEqual(payload, {"platform": "IOS", "versionString": "5.0.2", "releaseType": "AFTER_APPROVAL"})

    def test_prepare_checks_local_files_before_any_provider_access(self):
        with patch.object(asc, "load_plan", side_effect=asc.ReleaseError("bad manifest")), patch.object(asc, "app_id") as app:
            with self.assertRaises(asc.ReleaseError):
                asc.cmd_prepare()
            app.assert_not_called()

    def test_existing_review_for_another_version_is_rejected(self):
        submission = {"id": "r", "attributes": {"state": "WAITING_FOR_REVIEW"}}
        item = {"id": "i", "relationships": {"appStoreVersion": {"data": {"id": "other", "type": "appStoreVersions"}}}}
        with patch.object(asc, "get_all", side_effect=[[submission], [item]]), patch.object(asc, "req") as api:
            with self.assertRaisesRegex(asc.ReleaseError, "different|another"):
                asc.submit_review("app", "desired")
            api.assert_not_called()

    def test_matching_waiting_review_is_idempotent(self):
        submission = {"id": "r", "attributes": {"state": "WAITING_FOR_REVIEW"}}
        item = {"id": "i", "relationships": {"appStoreVersion": {"data": {"id": "desired", "type": "appStoreVersions"}}}}
        with patch.object(asc, "get_all", side_effect=[[submission], [item]]), patch.object(asc, "req") as api:
            self.assertEqual(asc.submit_review("app", "desired")["id"], "r")
            api.assert_not_called()

    def test_verified_metadata_and_build_are_required_before_publish(self):
        with patch.object(asc, "prepare", side_effect=asc.ReleaseError("metadata mismatch")), patch.object(asc, "submit_review") as submit:
            with self.assertRaises(asc.ReleaseError):
                asc.cmd_publish()
            submit.assert_not_called()

    def test_metadata_readback_rejects_stale_copy(self):
        plan = asc.ReleasePlan("5.0.2", "14", "New water", "New description", {"en-US": {}})
        version = {"attributes": {"versionString": "5.0.2", "platform": "IOS", "releaseType": "AFTER_APPROVAL"}}
        build = {"attributes": {"version": "14", "processingState": "VALID", "expired": False}}
        prerelease = {"attributes": {"version": "5.0.2", "platform": "IOS"}}
        responses = [{"data": version}, {"data": {"id": "build"}}, {"data": build}, {"data": prerelease}]
        with patch.object(asc, "req", side_effect=responses), patch.object(asc, "localizations", return_value=[{"id": "loc", "attributes": {"locale": "en-US", "description": "Old description", "whatsNew": "New water"}}]):
            with self.assertRaisesRegex(asc.ReleaseError, "Metadata readback"):
                asc.verify_prepared("version", "build", plan)

    def test_attached_build_mismatch_stops_before_metadata_readback(self):
        plan = asc.ReleasePlan("5.0.2", "14", "New water", "New description", {})
        version = {"attributes": {"versionString": "5.0.2", "platform": "IOS", "releaseType": "AFTER_APPROVAL"}}
        with patch.object(asc, "req", side_effect=[{"data": version}, {"data": {"id": "other"}}]), patch.object(asc, "localizations") as metadata:
            with self.assertRaisesRegex(asc.ReleaseError, "Attached build"):
                asc.verify_prepared("version", "build", plan)
            metadata.assert_not_called()

    def test_unchanged_watch_set_is_never_modified(self):
        asset = self.asset()
        loc = {"id": "loc", "attributes": {"locale": "en-US", "whatsNew": "New water", "description": "Description"}}
        plan = asc.ReleasePlan("5.0.2", "14", "New water", "Description", {})
        sets = [{"id": "phone", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"}},
                {"id": "watch", "attributes": {"screenshotDisplayType": "APP_WATCH_SERIES_7"}}]
        with patch.object(asc, "screenshot_sets", return_value=sets), patch.object(asc, "sync_screenshot_set") as sync, patch.object(asc, "req") as api:
            asc.sync_localization(loc, {"APP_IPHONE_67": [asset]}, plan)
            sync.assert_called_once_with("phone", [asset])
            api.assert_not_called()

    def test_reordered_provider_readback_is_rejected(self):
        first, second = self.asset("first", b"a"), self.asset("second", b"b")
        with patch.object(asc, "screenshots", return_value=[shot("second", second.checksum), shot("first", first.checksum)]), \
             patch.object(asc, "wait_for_screenshot", side_effect=asc.ReleaseError("checksum mismatch")):
            with self.assertRaisesRegex(asc.ReleaseError, "order"):
                asc.verify_screenshot_set("set", [first, second])

    def test_inventory_never_emits_signed_upload_urls(self):
        item = shot("one", "checksum")
        item["attributes"]["uploadOperations"] = [{"url": "https://upload.example/secret-signature"}]
        item["attributes"]["imageAsset"] = {"templateUrl": "https://public.example/{w}.png"}
        with patch.object(asc, "screenshot_sets", return_value=[{"id": "set", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"}}]), patch.object(asc, "screenshots", return_value=[item]):
            encoded = json.dumps(asc.screenshot_inventory("loc"))
        self.assertNotIn("secret-signature", encoded)
        self.assertIn("public.example", encoded)

    def test_submission_waits_for_provider_confirmation(self):
        ready = {"id": "r", "attributes": {"state": "READY_FOR_REVIEW"}}
        waiting = {"id": "r", "attributes": {"state": "WAITING_FOR_REVIEW"}}
        with patch.object(asc, "req", side_effect=[{"data": ready}, {"data": waiting}]), patch.object(asc.time, "sleep"):
            self.assertEqual(asc.wait_for_review("r")["attributes"]["state"], "WAITING_FOR_REVIEW")

    def test_failed_upload_error_does_not_expose_signed_url(self):
        operation = {"method": "PUT", "url": "https://upload.example/secret-signature", "offset": 0, "length": 3, "requestHeaders": []}
        with patch.object(asc, "http_request", side_effect=RuntimeError("failed https://upload.example/secret-signature")), patch.object(asc.time, "sleep"):
            with self.assertRaises(asc.ReleaseError) as failure:
                asc.upload_parts([operation], b"abc")
            self.assertNotIn("secret-signature", str(failure.exception))

    def test_approved_release_rerun_does_not_create_review_or_write(self):
        plan = asc.ReleasePlan("5.0.2", "14", "New water", "Description", {})
        for state in ("ACCEPTED", "PENDING_APPLE_RELEASE"):
            with self.subTest(state=state):
                version = {"id": "version", "attributes": {"appVersionState": state}}
                with patch.object(asc, "prepare", return_value=("app", version, plan)), \
                     patch.object(asc, "get_all", return_value=[]), \
                     patch.object(asc, "req", side_effect=AssertionError("Unexpected provider write")) as api:
                    asc.cmd_publish()
                    api.assert_not_called()

    def test_completing_review_is_reused_without_creating_another(self):
        submission = {"id": "r", "attributes": {"state": "COMPLETING"}}
        item = {"id": "i", "relationships": {"appStoreVersion": {"data": {"id": "desired", "type": "appStoreVersions"}}}}
        with patch.object(asc, "get_all", side_effect=[[submission], [item]]), \
             patch.object(asc, "req", side_effect=AssertionError("Unexpected provider write")) as api:
            self.assertEqual(asc.submit_review("app", "desired")["id"], "r")
            api.assert_not_called()

    def test_completing_review_is_polled_until_complete(self):
        completing = {"id": "r", "attributes": {"state": "COMPLETING"}}
        complete = {"id": "r", "attributes": {"state": "COMPLETE"}}
        with patch.object(asc, "req", side_effect=[{"data": completing}, {"data": complete}]) as api, patch.object(asc.time, "sleep"):
            self.assertEqual(asc.wait_for_review("r")["attributes"]["state"], "COMPLETE")
            self.assertTrue(all(call.args[0] == "GET" for call in api.call_args_list))

    def test_failed_replacement_retry_evicts_incomplete_reservation_before_originals(self):
        asset = self.asset()
        for state in ("FAILED", "AWAITING_UPLOAD", "UPLOAD_COMPLETE", "UNKNOWN"):
            with self.subTest(state=state):
                current = [shot(f"original-{i}", str(i)) for i in range(9)] + [shot("retry-reservation", "obsolete", state)]
                with patch.object(asc, "screenshots", return_value=current), \
                     patch.object(asc, "upload_screenshot", side_effect=asc.ReleaseError("upload failed again")), \
                     patch.object(asc, "req") as api:
                    with self.assertRaisesRegex(asc.ReleaseError, "upload failed"):
                        asc.sync_screenshot_set("set", [asset])
                    api.assert_called_once_with("DELETE", "/v1/appScreenshots/retry-reservation")

    def test_complete_state_can_arrive_before_exact_checksum_readback(self):
        responses = [{"data": shot("new", None)}, {"data": shot("new", "stale")}, {"data": shot("new", "expected")}]
        with patch.object(asc, "req", side_effect=responses) as api, patch.object(asc.time, "sleep"):
            result = asc.wait_for_screenshot("new", "expected")
        self.assertEqual(result["attributes"]["sourceFileChecksum"], "expected")
        self.assertEqual(api.call_count, 3)

    def test_bulk_screenshot_readback_resolves_lagging_individual_checksums(self):
        asset = self.asset()
        resolved = shot("new", asset.checksum)
        for stale_checksum in (None, "old-checksum"):
            with self.subTest(stale_checksum=stale_checksum):
                with patch.object(asc, "screenshots", return_value=[shot("new", stale_checksum)]), \
                     patch.object(asc, "wait_for_screenshot", return_value=resolved) as refresh:
                    self.assertEqual(asc.verify_screenshot_set("set", [asset]), [resolved])
                    refresh.assert_called_once_with("new", asset.checksum, timeout=30)


if __name__ == "__main__":
    unittest.main()
