import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from app_store_screenshots import DISPLAYS, checked_target, read_manifest, update_screenshots, verify_uploaded
from test_app_store_release import FakeAPI


class ScreenshotGuardTests(unittest.TestCase):
    def test_changed_image_is_rejected_before_api_access(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def chunk(kind, body):
                return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
            png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00")) + chunk(b"IEND", b"")
            image = root / "shot.png"
            image.write_bytes(png)
            manifest = {"approved": True, "style": "raw", "groups": [
                {"locale": locale, "display": display, "dimensions": [1, 1], "images": [
                    {"file": "shot.png", "sha256": hashlib.sha256(png).hexdigest()},
                ]} for locale in ("ja", "en-US") for display in DISPLAYS
            ]}
            path = root / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            self.assertEqual(len(read_manifest(path)["groups"]), 6)
            image.write_bytes(png + b"changed")
            with self.assertRaisesRegex(RuntimeError, "changed after validation"):
                read_manifest(path)

    def test_live_version_cannot_be_edited(self):
        api = FakeAPI({("GET", "apps/app/appStoreVersions"): [
            {"id": "live", "attributes": {"versionString": "1.2.8", "appStoreState": "READY_FOR_SALE"}},
        ]})
        with self.assertRaisesRegex(RuntimeError, "editable"):
            checked_target(api, {"version": "1.2.8", "build": "123"})
        self.assertEqual(api.writes, [])

    def base_api(self):
        target = {"id": "draft", "attributes": {"versionString": "1.2.8", "appStoreState": "PREPARE_FOR_SUBMISSION"}}
        locales = [{"id": locale, "attributes": {"locale": locale}} for locale in ("ja", "en-US")]
        return FakeAPI({
            ("GET", "apps/app/appStoreVersions"): [target],
            ("GET", "appStoreVersions/draft/build"): {"attributes": {"version": "123"}},
            ("GET", "appStoreVersions/draft/appStoreVersionLocalizations"): locales,
        })

    def test_wrong_build_cannot_change_screenshots(self):
        api = self.base_api()
        with self.assertRaisesRegex(RuntimeError, "approved TestFlight build"):
            checked_target(api, {"version": "1.2.8", "build": "other"})
        self.assertEqual(api.writes, [])

    def test_shared_live_resources_are_protected_before_any_delete(self):
        api = self.base_api()
        api.responses[("GET", "apps/app/appStoreVersions")].append({"id": "live", "attributes": {"versionString": "1.2.7", "appStoreState": "READY_FOR_SALE"}})
        api.responses.update({
            ("GET", "appStoreVersions/live/appStoreVersionLocalizations"): [{"id": "ja"}],
            ("GET", "appStoreVersionLocalizations/ja/appScreenshotSets"): [{"id": "shared", "attributes": {"screenshotDisplayType": "APP_IPHONE_65"}}],
            ("GET", "appScreenshotSets/shared/appScreenshots"): [{"id": "live-image"}],
        })
        with self.assertRaisesRegex(RuntimeError, "overlap live"):
            update_screenshots(api, {"version": "1.2.8", "build": "123", "groups": [{"locale": "ja", "display": "APP_IPHONE_65", "images": []}]})
        self.assertEqual(api.writes, [])

    def test_incomplete_assets_cannot_pass_submission_verification(self):
        api = self.base_api()
        api.responses.update({
            ("GET", "appStoreVersionLocalizations/ja/appScreenshotSets"): [{"id": "set", "attributes": {"screenshotDisplayType": "APP_IPHONE_65"}}],
            ("GET", "appScreenshotSets/set/appScreenshots"): [{"attributes": {"fileName": "shot.png", "sourceFileChecksum": "checksum", "assetDeliveryState": {"state": "UPLOAD_COMPLETE"}}}],
        })
        manifest = {"version": "1.2.8", "build": "123", "groups": [{"locale": "ja", "display": "APP_IPHONE_65", "images": [{"name": "shot.png", "md5": "checksum"}]}]}
        with self.assertRaisesRegex(RuntimeError, "processing is not complete"):
            verify_uploaded(api, manifest)
        self.assertEqual(api.writes, [])


if __name__ == "__main__":
    unittest.main()
