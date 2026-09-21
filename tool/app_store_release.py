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
    if os.environ.get("APP_STORE_ACTION", "inspect") != "inspect":
        raise RuntimeError("Submission implementation requires inspection first.")
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
