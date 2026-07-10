import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testSnapshotMergeKeepsMonotonicCountersForSameFilterProfile() {
    let older = snapshot(capturedAt: 100, signature: "same", plays: 8)
    let newer = snapshot(capturedAt: 200, signature: "same", plays: 3)

    let merged = SnapshotMerge.merge(older, newer)

    XCTAssertEqual(number(merged["totalPlayCount"]), 8)
    XCTAssertEqual(merged["filterSignature"] as? String, "same")
  }

  func testSnapshotMergeReplacesCountersWhenFilterProfileChanges() {
    let unfiltered = snapshot(capturedAt: 100, signature: "old", plays: 8)
    let filtered = snapshot(capturedAt: 200, signature: "new", plays: 3)

    let merged = SnapshotMerge.merge(unfiltered, filtered)

    XCTAssertEqual(number(merged["totalPlayCount"]), 3)
    XCTAssertEqual(merged["filterSignature"] as? String, "new")
    let tracks = merged["tracks"] as? [[String: Any]]
    XCTAssertEqual(tracks?.count, 1)
    XCTAssertEqual(tracks?.first?["id"] as? String, "track-new")
  }

  private func snapshot(
    capturedAt: Int,
    signature: String,
    plays: Int
  ) -> [String: Any] {
    [
      "dateKey": "2026-07-10",
      "capturedAtMillis": capturedAt,
      "source": "foreground",
      "filterSignature": signature,
      "trackCount": 1,
      "totalPlayCount": plays,
      "totalSkipCount": 0,
      "totalListeningSeconds": plays * 180,
      "tracks": [[
        "id": "track-\(signature)",
        "title": "Track",
        "artist": "Artist",
        "albumTitle": "Album",
        "playCount": plays,
        "skipCount": 0,
        "listeningSeconds": plays * 180,
      ]],
    ]
  }

  private func number(_ value: Any?) -> Int {
    (value as? NSNumber)?.intValue ?? 0
  }
}
