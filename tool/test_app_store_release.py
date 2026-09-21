import unittest

from app_store_release import prepare_release, submit_release


class FakeAPI:
    app_id = "app"

    def __init__(self, responses):
        self.responses = responses
        self.writes = []

    def request(self, path, method="GET", data=None, **params):
        if method != "GET":
            self.writes.append((method, path, data))
        return {"data": self.responses[(method, path)]}


def target(state="PREPARE_FOR_SUBMISSION"):
    return {"id": "version", "attributes": {"appStoreState": state}}


class ReleaseGuardTests(unittest.TestCase):
    def test_wrong_marketing_version_is_not_attached(self):
        api = FakeAPI({
            ("GET", "builds"): [{"id": "build", "attributes": {"processingState": "VALID"}}],
            ("GET", "builds/build/preReleaseVersion"): {"attributes": {"version": "1.0.2", "platform": "IOS"}},
        })
        with self.assertRaisesRegex(RuntimeError, "matching"):
            prepare_release(api, [], "1.0.3", "123")
        self.assertEqual(api.writes, [])

    def test_invalid_build_is_not_attached(self):
        api = FakeAPI({
            ("GET", "builds"): [{"id": "build", "attributes": {"processingState": "PROCESSING"}}],
            ("GET", "builds/build/preReleaseVersion"): {"attributes": {"version": "1.0.3", "platform": "IOS"}},
        })
        with self.assertRaisesRegex(RuntimeError, "valid and unexpired"):
            prepare_release(api, [], "1.0.3", "123")
        self.assertEqual(api.writes, [])

    def test_unrelated_review_items_block_submission(self):
        item = {"relationships": {"appStoreVersion": {"data": {"id": "version"}}}}
        api = FakeAPI({
            ("GET", "apps/app/reviewSubmissions"): [{"id": "review", "attributes": {"state": "READY_FOR_REVIEW"}}],
            ("GET", "reviewSubmissions/review/items"): [item, {"id": "unrelated"}],
        })
        with self.assertRaisesRegex(RuntimeError, "unrelated"):
            submit_release(api, target())
        self.assertEqual(api.writes, [])

    def test_only_verified_item_is_submitted(self):
        item = {"relationships": {"appStoreVersion": {"data": {"id": "version"}}}}
        api = FakeAPI({
            ("GET", "apps/app/reviewSubmissions"): [{"id": "review", "attributes": {"state": "READY_FOR_REVIEW"}}],
            ("GET", "reviewSubmissions/review/items"): [item],
            ("PATCH", "reviewSubmissions/review"): {"id": "review", "attributes": {"state": "WAITING_FOR_REVIEW"}},
        })
        self.assertEqual(submit_release(api, target())["state"], "WAITING_FOR_REVIEW")
        self.assertEqual(len(api.writes), 1)
        self.assertTrue(api.writes[0][2]["data"]["attributes"]["submitted"])

    def test_submitted_version_is_not_submitted_twice(self):
        api = FakeAPI({})
        self.assertTrue(submit_release(api, target("WAITING_FOR_REVIEW"))["alreadySubmitted"])
        self.assertEqual(api.writes, [])


if __name__ == "__main__":
    unittest.main()
