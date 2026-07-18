import Foundation
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testSnapshotRefreshReplacesOnlyRequestsBeyondTheSixHourWindow() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    XCTAssertFalse(
      SongBriefSnapshotRefresh.shouldReplacePendingRequest(
        earliestBeginDate: nil,
        now: now
      )
    )
    XCTAssertFalse(
      SongBriefSnapshotRefresh.shouldReplacePendingRequest(
        earliestBeginDate: now.addingTimeInterval(6 * 60 * 60),
        now: now
      )
    )
    XCTAssertFalse(
      SongBriefSnapshotRefresh.shouldReplacePendingRequest(
        earliestBeginDate: now.addingTimeInterval(6 * 60 * 60 + 5 * 60),
        now: now
      )
    )
    XCTAssertTrue(
      SongBriefSnapshotRefresh.shouldReplacePendingRequest(
        earliestBeginDate: now.addingTimeInterval(6 * 60 * 60 + 5 * 60 + 1),
        now: now
      )
    )
  }

  func testSnapshotOperationCoordinatorRunsAsyncWorkInFIFOOrder() {
    let coordinator = SnapshotOperationCoordinator(
      label: "app.songbrief.tests.snapshot-operation-coordinator"
    )
    let firstStarted = expectation(description: "first operation started")
    let secondStarted = expectation(description: "second operation started")
    let lock = NSLock()
    var starts: [String] = []
    var finishFirst: (() -> Void)?

    coordinator.enqueue { finished in
      lock.lock()
      starts.append("first")
      finishFirst = finished
      lock.unlock()
      firstStarted.fulfill()
    }
    coordinator.enqueue { finished in
      lock.lock()
      starts.append("second")
      lock.unlock()
      secondStarted.fulfill()
      finished()
    }

    wait(for: [firstStarted], timeout: 1)
    lock.lock()
    XCTAssertEqual(starts, ["first"])
    let release = finishFirst
    lock.unlock()

    release?()
    wait(for: [secondStarted], timeout: 1)
    lock.lock()
    XCTAssertEqual(starts, ["first", "second"])
    lock.unlock()
  }

  func testSnapshotMergeKeepsMonotonicCountersForSameFilterProfile() {
    let older = snapshot(capturedAt: 100, signature: "same", plays: 8)
    let newer = snapshot(capturedAt: 200, signature: "same", plays: 3)

    let merged = SnapshotMerge.merge(older, newer)

    XCTAssertEqual(number(merged["totalPlayCount"]), 8)
    XCTAssertEqual(merged["filterSignature"] as? String, "same")
  }

  func testSnapshotMergeUsesConservativeCountersWhenFilterProfileChanges() {
    let unfiltered = snapshot(capturedAt: 100, signature: "old", plays: 8)
    let filtered = snapshot(capturedAt: 200, signature: "new", plays: 3)

    let merged = SnapshotMerge.merge(unfiltered, filtered)

    XCTAssertEqual(number(merged["totalPlayCount"]), 3)
    XCTAssertEqual(merged["filterSignature"] as? String, "new")
    let tracks = merged["tracks"] as? [[String: Any]]
    XCTAssertEqual(tracks?.count, 1)
    XCTAssertEqual(tracks?.first?["id"] as? String, "track-new")
  }

  func testSnapshotMergePrefersTheActiveFilterProfileOverNewerLegacyData() {
    let filtered = snapshot(capturedAt: 100, signature: "filtered", plays: 3)
    let unfiltered = snapshot(capturedAt: 200, signature: "unfiltered", plays: 8)

    let merged = SnapshotMerge.merge(
      filtered,
      unfiltered,
      preferredFilterSignature: "filtered"
    )

    XCTAssertEqual(number(merged["totalPlayCount"]), 3)
    XCTAssertEqual(merged["filterSignature"] as? String, "filtered")
  }

  func testSnapshotMergeAllowsAnIntentionalChangeToTheActiveProfile() {
    let filtered = snapshot(capturedAt: 100, signature: "filtered", plays: 3)
    let unfiltered = snapshot(capturedAt: 200, signature: "unfiltered", plays: 8)

    let merged = SnapshotMerge.merge(
      filtered,
      unfiltered,
      preferredFilterSignature: "unfiltered"
    )

    XCTAssertEqual(number(merged["totalPlayCount"]), 8)
    XCTAssertEqual(merged["filterSignature"] as? String, "unfiltered")
  }

  func testSnapshotMergePrefersSignedDataToLegacyUnsignedData() {
    let filtered = snapshot(capturedAt: 100, signature: "filtered", plays: 3)
    var legacy = snapshot(capturedAt: 200, signature: "legacy", plays: 8)
    legacy.removeValue(forKey: "filterSignature")

    let merged = SnapshotMerge.merge(filtered, legacy)

    XCTAssertEqual(number(merged["totalPlayCount"]), 3)
    XCTAssertEqual(merged["filterSignature"] as? String, "filtered")
  }

  func testCloudOnlyImportRejectsAProfileMismatchWhenExclusionsAreActive() {
    let unfiltered = snapshot(capturedAt: 200, signature: "unfiltered", plays: 8)

    XCTAssertFalse(
      SnapshotMerge.canImportCloudOnlySnapshot(
        unfiltered,
        activeFilterSignature: "filtered",
        hasActiveExclusions: true
      )
    )
    XCTAssertTrue(
      SnapshotMerge.canImportCloudOnlySnapshot(
        unfiltered,
        activeFilterSignature: "unfiltered",
        hasActiveExclusions: true
      )
    )
    XCTAssertTrue(
      SnapshotMerge.canImportCloudOnlySnapshot(
        unfiltered,
        activeFilterSignature: "filtered",
        hasActiveExclusions: false
      )
    )
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
