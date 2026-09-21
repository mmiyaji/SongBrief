"""Read app-scoped TestFlight status without logging credentials or tester data."""

import json
import os
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import jwt


def main():
    required = (
        "APP_STORE_CONNECT_API_KEY_ID",
        "APP_STORE_CONNECT_API_ISSUER_ID",
        "APP_STORE_CONNECT_API_PRIVATE_KEY",
        "APP_STORE_APPLE_ID",
    )
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit("Missing environment variables: " + ", ".join(missing))
    issued_at = int(time.time())
    token = jwt.encode(
        {
            "iss": os.environ["APP_STORE_CONNECT_API_ISSUER_ID"],
            "iat": issued_at,
            "exp": issued_at + 600,
            "aud": "appstoreconnect-v1",
        },
        os.environ["APP_STORE_CONNECT_API_PRIVATE_KEY"],
        algorithm="ES256",
        headers={"kid": os.environ["APP_STORE_CONNECT_API_KEY_ID"], "typ": "JWT"},
    )

    def get(path, **params):
        url = "https://api.appstoreconnect.apple.com/v1/" + path
        if params:
            url += "?" + urlencode(params)
        request = Request(url, headers={"Authorization": "Bearer " + token})
        try:
            with urlopen(request, timeout=45) as response:
                return json.load(response)
        except HTTPError as error:
            # Do not log request headers, tokens, or unfiltered server payloads.
            raise RuntimeError(f"App Store Connect GET {path}: HTTP {error.code}") from None

    app_id = os.environ["APP_STORE_APPLE_ID"]
    builds = get("builds", **{"filter[app]": app_id, "sort": "-uploadedDate", "limit": 5})
    groups = get("betaGroups", **{"filter[app]": app_id, "limit": 200})
    result = {"builds": [], "groups": []}
    for group in groups.get("data", []):
        attributes = group["attributes"]
        result["groups"].append(
            {
                "id": group["id"],
                "name": attributes.get("name"),
                "internal": attributes.get("isInternalGroup"),
                "allBuilds": attributes.get("hasAccessToAllBuilds"),
            }
        )
    for build in builds.get("data", []):
        build_id = build["id"]
        version = get(f"builds/{build_id}/preReleaseVersion")["data"]["attributes"]
        beta = get(f"builds/{build_id}/buildBetaDetail")["data"]["attributes"]
        assigned_groups = get(f"builds/{build_id}/betaGroups", limit=200)
        attributes = build["attributes"]
        result["builds"].append(
            {
                "id": build_id,
                "version": version.get("version"),
                "build": attributes.get("version"),
                "uploadedAt": attributes.get("uploadedDate"),
                "processingState": attributes.get("processingState"),
                "expired": attributes.get("expired"),
                "internalBuildState": beta.get("internalBuildState"),
                "externalBuildState": beta.get("externalBuildState"),
                "groupIds": [group["id"] for group in assigned_groups.get("data", [])],
            }
        )
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"TestFlight status check failed: {type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
