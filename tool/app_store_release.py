"""Inspect or submit this repository's uploaded App Store release via CI secrets."""

import json
import os
from pathlib import Path
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import jwt

WHATS_NEW = {
    "ja": "動作の安定性を改善し、軽微な不具合を修正しました。",
    "en-US": "Improved stability and fixed minor bugs.",
}


class AppStoreAPI:
    def __init__(self):
        self.app_id = os.environ["APP_STORE_APPLE_ID"]
        issued_at = int(time.time())
        self.token = jwt.encode(
            {"iss": os.environ["APP_STORE_CONNECT_API_ISSUER_ID"],
             "iat": issued_at, "exp": issued_at + 600, "aud": "appstoreconnect-v1"},
            os.environ["APP_STORE_CONNECT_API_PRIVATE_KEY"],
            algorithm="ES256",
            headers={"kid": os.environ["APP_STORE_CONNECT_API_KEY_ID"], "typ": "JWT"},
        )

    def request(self, path, method="GET", data=None, optional=False, **params):
        url = "https://api.appstoreconnect.apple.com/v1/" + path
        if params:
            url += "?" + urlencode(params)
        request = Request(
            url, method=method,
            data=json.dumps(data).encode() if data is not None else None,
            headers={"Authorization": "Bearer " + self.token,
                     "Content-Type": "application/json"},
        )
        try:
            with urlopen(request, timeout=45) as response:
                body = response.read()
                return json.loads(body) if body else {}
        except HTTPError as error:
            if optional and error.code == 404:
                return {"data": None}
            payload = json.loads(error.read())
            details = [
                {key: item.get(key) for key in ("code", "title", "detail", "source")}
                for item in payload.get("errors", [])
            ]
            raise RuntimeError(
                f"{method} {path}: HTTP {error.code} {json.dumps(details)}"
            ) from None


def version_summary(api, version):
    version_id = version["id"]
    attrs = version["attributes"]
    build = api.request(f"appStoreVersions/{version_id}/build")["data"]
    locales = api.request(f"appStoreVersions/{version_id}/appStoreVersionLocalizations", limit=200)["data"]
    detail = api.request(f"appStoreVersions/{version_id}/appStoreReviewDetail", optional=True)["data"]
    localized = []
    for locale in locales:
        sets = api.request(f"appStoreVersionLocalizations/{locale['id']}/appScreenshotSets", limit=200)["data"]
        localized.append({
            "id": locale["id"], "locale": locale["attributes"]["locale"],
            "whatsNew": locale["attributes"].get("whatsNew"),
            "hasDescription": bool(locale["attributes"].get("description")),
            "screenshotSets": [item["attributes"].get("screenshotDisplayType") for item in sets],
        })
    return {
        "id": version_id, "version": attrs["versionString"],
        "state": attrs.get("appStoreState"), "releaseType": attrs.get("releaseType"),
        "copyright": attrs.get("copyright"),
        "build": build["attributes"].get("version") if build else None,
        "localizations": localized,
        "hasReviewContact": bool(detail and all(detail["attributes"].get(key) for key in (
            "contactFirstName", "contactLastName", "contactEmail", "contactPhone"))),
        "demoAccountRequired": detail["attributes"].get("demoAccountRequired") if detail else None,
    }


def prepare_release(api, versions, version_name, build_number):
    if not build_number:
        raise RuntimeError("An explicit RELEASE_BUILD_NUMBER is required.")
    builds = api.request("builds", **{
        "filter[app]": api.app_id, "filter[version]": build_number, "limit": 200,
    })["data"]
    matches = []
    for build in builds:
        pre_release = api.request(f"builds/{build['id']}/preReleaseVersion")["data"]["attributes"]
        if pre_release["version"] == version_name and pre_release["platform"] == "IOS":
            matches.append(build)
    if len(matches) != 1:
        raise RuntimeError("Exactly one matching iOS version/build must exist.")
    build = matches[0]
    if build["attributes"].get("expired") or build["attributes"].get("processingState") != "VALID":
        raise RuntimeError("The selected build must be valid and unexpired.")
    target = next((item for item in versions if item["attributes"]["versionString"] == version_name), None)
    if target and target["attributes"]["appStoreState"] in (
        "WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_APPLE_RELEASE", "READY_FOR_SALE",
    ):
        summary = version_summary(api, target)
        if summary["build"] != build_number:
            raise RuntimeError("The existing submitted version uses a different build.")
        return target, summary
    if target and target["attributes"]["appStoreState"] not in (
        "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
        "READY_FOR_REVIEW",
    ):
        raise RuntimeError("The target version is not editable; no changes were made.")
    if not target:
        previous = next((item for item in versions if item["attributes"]["appStoreState"] == "READY_FOR_SALE"), None)
        if previous is None:
            raise RuntimeError("A released version is required to preserve existing metadata.")
        target = api.request("appStoreVersions", method="POST", data={"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": version_name,
                           "releaseType": "AFTER_APPROVAL",
                           "copyright": previous["attributes"]["copyright"]},
            "relationships": {"app": {"data": {"type": "apps", "id": api.app_id}}},
        }})["data"]
    version_id = target["id"]
    api.request(f"appStoreVersions/{version_id}", method="PATCH", data={"data": {
        "type": "appStoreVersions", "id": version_id,
        "attributes": {"releaseType": "AFTER_APPROVAL"},
    }})
    api.request(f"appStoreVersions/{version_id}/relationships/build", method="PATCH", data={
        "data": {"type": "builds", "id": build["id"]},
    })
    locales = api.request(f"appStoreVersions/{version_id}/appStoreVersionLocalizations", limit=200)["data"]
    if {locale["attributes"]["locale"] for locale in locales} != set(WHATS_NEW):
        raise RuntimeError("Localized metadata must contain the existing Japanese and English locales.")
    for locale in locales:
        api.request(f"appStoreVersionLocalizations/{locale['id']}", method="PATCH", data={"data": {
            "type": "appStoreVersionLocalizations", "id": locale["id"],
            "attributes": {"whatsNew": WHATS_NEW[locale["attributes"]["locale"]]},
        }})
    target = api.request(f"appStoreVersions/{version_id}")["data"]
    summary = version_summary(api, target)
    if summary["build"] != build_number or summary["releaseType"] != "AFTER_APPROVAL":
        raise RuntimeError("Build or automatic release setting could not be verified.")
    if not summary["hasReviewContact"]:
        raise RuntimeError("Review contact details were not inherited; preparation is incomplete.")
    for locale in summary["localizations"]:
        if not locale["hasDescription"] or not locale["screenshotSets"]:
            raise RuntimeError("Existing description/screenshots were not inherited.")
        if locale["whatsNew"] != WHATS_NEW[locale["locale"]]:
            raise RuntimeError("Release notes could not be verified.")
    return target, summary


def submit_release(api, target):
    version_id = target["id"]
    if target["attributes"]["appStoreState"] in (
        "WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_APPLE_RELEASE", "READY_FOR_SALE",
    ):
        return {"alreadySubmitted": True, "versionState": target["attributes"]["appStoreState"]}
    submissions = api.request(f"apps/{api.app_id}/reviewSubmissions", limit=200)["data"]
    selected = None
    existing_items = []
    for submission in submissions:
        if submission["attributes"].get("state") != "READY_FOR_REVIEW":
            continue
        items = api.request(f"reviewSubmissions/{submission['id']}/items", include="appStoreVersion", limit=200)["data"]
        version_ids = [item.get("relationships", {}).get("appStoreVersion", {}).get("data", {}).get("id")
                       for item in items if item.get("relationships", {}).get("appStoreVersion", {}).get("data")]
        if version_id in version_ids:
            if len(items) != 1:
                raise RuntimeError("The review submission contains unrelated items; refusing to submit them.")
            selected, existing_items = submission, items
            break
        if not items and submission["attributes"].get("platform") in (None, "IOS"):
            selected, existing_items = submission, items
    if selected is None:
        selected = api.request("reviewSubmissions", method="POST", data={"data": {
            "type": "reviewSubmissions",
            "relationships": {"app": {"data": {"type": "apps", "id": api.app_id}}},
        }})["data"]
    submission_id = selected["id"]
    if not existing_items:
        api.request("reviewSubmissionItems", method="POST", data={"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
            },
        }})
    # Recheck the exact contents immediately before the irreversible submission.
    items = api.request(f"reviewSubmissions/{submission_id}/items", include="appStoreVersion", limit=200)["data"]
    if len(items) != 1 or items[0].get("relationships", {}).get("appStoreVersion", {}).get("data", {}).get("id") != version_id:
        raise RuntimeError("Review contents changed before submission.")
    submitted = api.request(f"reviewSubmissions/{submission_id}", method="PATCH", data={"data": {
        "type": "reviewSubmissions", "id": submission_id,
        "attributes": {"submitted": True},
    }})["data"]
    return {"id": submitted["id"], "state": submitted["attributes"].get("state")}


def main():
    api = AppStoreAPI()
    version_name = next(
        line.split(":", 1)[1].strip().split("+")[0]
        for line in Path("pubspec.yaml").read_text().splitlines()
        if line.startswith("version:")
    )
    versions = api.request(f"apps/{api.app_id}/appStoreVersions", **{
        "filter[platform]": "IOS", "limit": 200,
    })["data"]
    action = os.environ.get("APP_STORE_ACTION", "inspect")
    if action in ("prepare", "submit"):
        target, summary = prepare_release(api, versions, version_name, os.environ.get("RELEASE_BUILD_NUMBER"))
        print(json.dumps({"prepared": summary}, ensure_ascii=False, indent=2), flush=True)
        if action == "submit":
            submission = submit_release(api, target)
            target = api.request(f"appStoreVersions/{target['id']}")["data"]
            print(json.dumps({"submission": submission, "verified": version_summary(api, target)},
                             ensure_ascii=False, indent=2), flush=True)
        return
    if action != "inspect":
        raise RuntimeError("Unsupported App Store action.")
    summaries = [version_summary(api, version) for version in versions[:5]]
    submissions = api.request(f"apps/{api.app_id}/reviewSubmissions", limit=200)["data"]
    print(json.dumps({
        "targetVersion": version_name, "versions": summaries,
        "submissions": [{"id": item["id"], "state": item["attributes"].get("state")}
                        for item in submissions],
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"App Store operation failed: {type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
