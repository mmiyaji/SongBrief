import XCTest
@testable import Runner

final class WidgetBackgroundTests: XCTestCase {
  func testBuildSummaryReconstructsLatestDeltaAndMergesSuppliedSnapshot() throws {
    let persisted = [
      snapshot(
        dateKey: "2026-07-20",
        capturedAt: 100,
        plays: 10,
        skips: 2,
        seconds: 600
      ),
      snapshot(
        dateKey: "2026-07-21",
        capturedAt: 200,
        plays: 12,
        skips: 3,
        seconds: 720
      ),
    ]
    let supplied = snapshot(
      dateKey: "2026-07-21",
      capturedAt: 300,
      plays: 15,
      skips: 4,
      seconds: 900
    )

    let summary = try XCTUnwrap(
      SongBriefWidgetDataStore.buildSummary(
        from: persisted,
        including: supplied
      )
    )

    XCTAssertEqual(number(summary["latestCapturedAtMillis"]), 300)
    XCTAssertEqual(number(summary["snapshotCount"]), 2)
    XCTAssertEqual(summary["hasComparableDelta"] as? Bool, true)
    XCTAssertEqual(number(summary["playDelta"]), 5)
    XCTAssertEqual(number(summary["skipDelta"]), 2)
    XCTAssertEqual(number(summary["listeningSecondsDelta"]), 300)
    XCTAssertEqual(number(summary["observedDays"]), 1)
    XCTAssertEqual(summary["topTrackTitle"] as? String, "Track 2026-07-21")
    XCTAssertEqual(summary["topTrackArtist"] as? String, "Artist")
    XCTAssertEqual(number(summary["topTrackPlayDelta"]), 5)
  }

  func testBuildSummaryMarksProfileChangeUnavailableAndClearsTopTrackFields() throws {
    let previous = snapshot(
      dateKey: "2026-07-20",
      capturedAt: 100,
      plays: 10,
      signature: "before"
    )
    let current = snapshot(
      dateKey: "2026-07-21",
      capturedAt: 200,
      plays: 15,
      signature: "after"
    )

    let summary = try XCTUnwrap(
      SongBriefWidgetDataStore.buildSummary(from: [previous, current])
    )

    XCTAssertEqual(number(summary["playDelta"]), 0)
    XCTAssertEqual(summary["hasComparableDelta"] as? Bool, false)
    XCTAssertEqual(number(summary["skipDelta"]), 0)
    XCTAssertEqual(number(summary["listeningSecondsDelta"]), 0)
    XCTAssertEqual(number(summary["observedDays"]), 0)
    XCTAssertNil(summary["topTrackTitle"])
    XCTAssertNil(summary["topTrackArtist"])
    XCTAssertNil(summary["topTrackPlayDelta"])
    let daily = summary["dailyPlayDeltas"] as? [[String: Any]]
    XCTAssertEqual(daily?.last?["hasData"] as? Bool, false)
  }

  func testBuildSummaryKeepsPersistedProfileWhenSuppliedCaptureIsStale() throws {
    let persisted = [
      snapshot(
        dateKey: "2026-07-20",
        capturedAt: 100,
        plays: 10,
        signature: "active"
      ),
      snapshot(
        dateKey: "2026-07-21",
        capturedAt: 200,
        plays: 20,
        signature: "active"
      ),
    ]
    let staleCapture = snapshot(
      dateKey: "2026-07-21",
      capturedAt: 300,
      plays: 99,
      signature: "stale"
    )

    let summary = try XCTUnwrap(
      SongBriefWidgetDataStore.buildSummary(
        from: persisted,
        including: staleCapture
      )
    )

    XCTAssertEqual(number(summary["latestCapturedAtMillis"]), 200)
    XCTAssertEqual(number(summary["playDelta"]), 10)
    XCTAssertEqual(summary["hasComparableDelta"] as? Bool, true)
  }

  func testBuildSummaryDoesNotCarryTopTrackFromAnOlderSummary() throws {
    let snapshots = [
      snapshot(dateKey: "2026-07-20", capturedAt: 100, plays: 10),
      snapshot(dateKey: "2026-07-21", capturedAt: 200, plays: 10),
    ]

    let summary = try XCTUnwrap(
      SongBriefWidgetDataStore.buildSummary(from: snapshots)
    )

    XCTAssertEqual(number(summary["playDelta"]), 0)
    XCTAssertNil(summary["topTrackTitle"])
    XCTAssertNil(summary["topTrackArtist"])
    XCTAssertNil(summary["topTrackPlayDelta"])
  }

  private func snapshot(
    dateKey: String,
    capturedAt: Int,
    plays: Int,
    skips: Int = 0,
    seconds: Int? = nil,
    signature: String = "same"
  ) -> [String: Any] {
    [
      "dateKey": dateKey,
      "capturedAtMillis": capturedAt,
      "source": "background",
      "filterSignature": signature,
      "trackCount": 1,
      "totalPlayCount": plays,
      "totalSkipCount": skips,
      "totalListeningSeconds": seconds ?? plays * 60,
      "tracks": [[
        "id": "track-1",
        "title": "Track \(dateKey)",
        "artist": "Artist",
        "albumTitle": "Album",
        "playCount": plays,
        "skipCount": skips,
        "listeningSeconds": seconds ?? plays * 60,
      ]],
    ]
  }

  private func number(_ value: Any?) -> Int {
    if let value = value as? Int {
      return value
    }
    return (value as? NSNumber)?.intValue ?? 0
  }
}
