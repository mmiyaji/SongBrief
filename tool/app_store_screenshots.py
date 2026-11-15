"""Replace only an editable version's screenshots using an approved manifest."""

import hashlib
import json
import os
from pathlib import Path
import struct
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "READY_FOR_REVIEW"}
DISPLAYS = {"APP_IPHONE_65", "APP_IPAD_PRO_3GEN_129", "APP_IPHONE_DUO"}


def read_manifest(path):
    path = Path(path).resolve()
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("approved") is not True or manifest.get("style") != "raw":
        raise RuntimeError("An explicitly approved raw screenshot manifest is required.")
    groups = manifest["groups"]
    if {(g["locale"], g["display"]) for g in groups} != {
        (locale, display) for locale in ("ja", "en-US") for display in DISPLAYS
    } or len(groups) != 6:
        raise RuntimeError("Expected exactly the approved six language/device groups.")
    for group in groups:
        if not 1 <= len(group["images"]) <= 10:
            raise RuntimeError("Each device group must contain 1–10 screenshots.")
        for image in group["images"]:
            source = (path.parent / image["file"]).resolve()
            if not source.is_relative_to(path.parent):
                raise RuntimeError("Screenshot path escapes the manifest directory.")
            data = source.read_bytes()
            if hashlib.sha256(data).hexdigest() != image["sha256"]:
                raise RuntimeError("Screenshot bytes changed after validation.")
            if data[:8] != b"\x89PNG\r\n\x1a\n" or data[25] not in (0, 2):
                raise RuntimeError("Screenshots must be opaque PNG images.")
            if list(struct.unpack(">II", data[16:24])) != group["dimensions"]:
                raise RuntimeError("Screenshot dimensions do not match the approved device group.")
            image["path"] = source
            image["md5"] = hashlib.md5(data, usedforsecurity=False).hexdigest()
    return manifest


def checked_target(api, manifest):
    versions = api.request(f"apps/{api.app_id}/appStoreVersions", **{
        "filter[platform]": "IOS", "limit": 200,
    })["data"]
    matches = [v for v in versions if v["attributes"]["versionString"] == manifest["version"]]
    if len(matches) != 1 or matches[0]["attributes"]["appStoreState"] not in EDITABLE:
        raise RuntimeError("Only the exact editable release version may be changed.")
    target = matches[0]
    build = api.request(f"appStoreVersions/{target['id']}/build")["data"]
    if not build or build["attributes"]["version"] != manifest["build"]:
        raise RuntimeError("The editable version does not use the approved TestFlight build.")
    locales = api.request(f"appStoreVersions/{target['id']}/appStoreVersionLocalizations", limit=200)["data"]
    if {l["attributes"]["locale"] for l in locales} != {"ja", "en-US"}:
        raise RuntimeError("Unexpected release localizations; refusing partial updates.")
    return target, {l["attributes"]["locale"]: l for l in locales}, versions


def screenshot_sets(api, locale):
    result = api.request(f"appStoreVersionLocalizations/{locale['id']}/appScreenshotSets", limit=200)
    if result.get("links", {}).get("next"):
        raise RuntimeError("Screenshot set pagination requires review.")
    return result["data"]


def screenshots(api, set_id):
    result = api.request(f"appScreenshotSets/{set_id}/appScreenshots", limit=200)
    if result.get("links", {}).get("next"):
        raise RuntimeError("Screenshot pagination requires review.")
    return result["data"]


def upload_image(api, set_id, image):
    data = image["path"].read_bytes()
    resource = api.request("appScreenshots", method="POST", data={"data": {
        "type": "appScreenshots", "attributes": {"fileName": image["name"], "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
    }})["data"]
    for operation in resource["attributes"]["uploadOperations"]:
        offset, length = operation["offset"], operation["length"]
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        request = Request(operation["url"], data=data[offset:offset + length], headers=headers, method=operation["method"])
        try:
            with urlopen(request, timeout=90) as response:
                response.read()
        except HTTPError as error:
            # A presigned upload URL must never be printed in logs.
            raise RuntimeError(f"Screenshot byte upload failed: HTTP {error.code}") from None
    api.request(f"appScreenshots/{resource['id']}", method="PATCH", data={"data": {
        "type": "appScreenshots", "id": resource["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": image["md5"]},
    }})
    print(f"Uploaded {image['name']}", flush=True)
    return resource["id"]


def verify_uploaded(api, manifest):
    target, locales, _ = checked_target(api, manifest)
    summary = []
    for group in manifest["groups"]:
        sets = [s for s in screenshot_sets(api, locales[group["locale"]])
                if s["attributes"]["screenshotDisplayType"] == group["display"]]
        if len(sets) != 1:
            raise RuntimeError("The expected screenshot set is missing or duplicated.")
        actual = screenshots(api, sets[0]["id"])
        if len(actual) != len(group["images"]):
            raise RuntimeError("Screenshot count differs from the approved manifest.")
        for resource, expected in zip(actual, group["images"]):
            attrs = resource["attributes"]
            if attrs["fileName"] != expected["name"] or attrs.get("sourceFileChecksum") != expected["md5"]:
                raise RuntimeError("Screenshot order or checksum differs from the approved manifest.")
            state = attrs.get("assetDeliveryState", {}).get("state")
            if state == "FAILED":
                raise RuntimeError("Screenshot processing failed.")
            if state != "COMPLETE":
                raise RuntimeError(f"Screenshot processing is not complete: {state}")
        summary.append({"locale": group["locale"], "display": group["display"], "count": len(actual), "state": "COMPLETE"})
    return {"version": manifest["version"], "build": manifest["build"], "versionState": target["attributes"]["appStoreState"], "screenshots": summary}


def update_screenshots(api, manifest):
    target, locales, versions = checked_target(api, manifest)
    # Inherited draft resources must be distinct from the currently live version.
    published = next((v for v in versions if v["attributes"]["appStoreState"] == "READY_FOR_SALE"), None)
    protected = set()
    if published:
        live_locales = api.request(f"appStoreVersions/{published['id']}/appStoreVersionLocalizations", limit=200)["data"]
        for locale in live_locales:
            protected.add(locale["id"])
            for screenshot_set in screenshot_sets(api, locale):
                protected.add(screenshot_set["id"])
                protected.update(s["id"] for s in screenshots(api, screenshot_set["id"]))
    planned = []
    for group in manifest["groups"]:
        locale = locales[group["locale"]]
        found = [s for s in screenshot_sets(api, locale) if s["attributes"]["screenshotDisplayType"] == group["display"]]
        if len(found) != 1:
            raise RuntimeError("Expected exactly one inherited device screenshot set.")
        screenshot_set = found[0]
        old = screenshots(api, screenshot_set["id"])
        if any(identifier in protected for identifier in [locale["id"], screenshot_set["id"], *(s["id"] for s in old)]):
            raise RuntimeError("Draft screenshots overlap live resources; refusing modification.")
        planned.append((group, screenshot_set, old))
    for group, screenshot_set, old in planned:
        latest = api.request(f"appStoreVersions/{target['id']}")["data"]
        if latest["attributes"]["appStoreState"] not in EDITABLE:
            raise RuntimeError("The release became non-editable; stopping screenshot changes.")
        set_id = screenshot_set["id"]
        # Only remove this draft's inherited screenshots. The live listing is protected above.
        for image in old:
            api.request(f"appScreenshots/{image['id']}", method="DELETE")
        ids = [upload_image(api, set_id, image) for image in group["images"]]
        api.request(f"appScreenshotSets/{set_id}/relationships/appScreenshots", method="PATCH", data={
            "data": [{"type": "appScreenshots", "id": identifier} for identifier in ids],
        })
    deadline = time.monotonic() + 240
    while True:
        try:
            return verify_uploaded(api, manifest)
        except RuntimeError as error:
            if "processing is not complete" not in str(error) or time.monotonic() >= deadline:
                raise
            print("Waiting for screenshot processing", flush=True)
            time.sleep(5)


def main():
    from app_store_release import AppStoreAPI
    version = next(line.split(":", 1)[1].strip().split("+")[0]
                   for line in Path("pubspec.yaml").read_text().splitlines() if line.startswith("version:"))
    manifest = read_manifest(Path("store_assets") / f"v{version}" / "upload-manifest.json")
    if manifest["version"] != version or manifest["build"] != os.environ.get("RELEASE_BUILD_NUMBER"):
        raise RuntimeError("The explicit release build/version must match the screenshot manifest.")
    summary = update_screenshots(AppStoreAPI(), manifest)
    print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Exception chains may contain presigned URLs; print only the safe summary.
        detail = str(error) if isinstance(error, RuntimeError) else "Inspect the failed operation; upload URLs are not logged."
        print(f"Screenshot update failed: {type(error).__name__}: {detail}")
        raise SystemExit(1)
