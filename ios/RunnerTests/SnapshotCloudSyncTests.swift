import CloudKit
import Foundation
import XCTest
@testable import Runner

final class SnapshotCloudSyncTests: XCTestCase {
  func testDeletionPolicyMergesBothMonotonicFrontiers() {
    let first = SnapshotDeletionPolicy(
      deletedBeforeDateKey: "2026-01-01",
      deleteAllThroughMillis: 100
    )
    let second = SnapshotDeletionPolicy(
      deletedBeforeDateKey: "2025-01-01",
      deleteAllThroughMillis: 200
    )

    let merged = first.merged(with: second)

    XCTAssertEqual(merged.deletedBeforeDateKey, "2026-01-01")
    XCTAssertEqual(merged.deleteAllThroughMillis, 200)
  }

  func testDeleteAllFrontierAllowsALaterCaptureOnTheSameDay() {
    let policy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: nil,
      deleteAllThroughMillis: 200
    )

    XCTAssertTrue(
      policy.deletes(snapshot(dateKey: "2026-09-21", capturedAtMillis: 200))
    )
    XCTAssertFalse(
      policy.deletes(snapshot(dateKey: "2026-09-21", capturedAtMillis: 201))
    )
  }

  func testDateFrontierAlwaysDeletesOlderDays() {
    let policy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: "2026-09-21",
      deleteAllThroughMillis: nil
    )

    XCTAssertTrue(
      policy.deletes(snapshot(dateKey: "2026-09-20", capturedAtMillis: 999))
    )
    XCTAssertFalse(
      policy.deletes(snapshot(dateKey: "2026-09-21", capturedAtMillis: 1))
    )
  }

  func testDeletionPolicyPayloadRoundTripsWithoutNewCloudKitFields() {
    let policy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: "2026-01-01",
      deleteAllThroughMillis: 123
    )

    let decoded = SnapshotDeletionPolicy(
      payload: policy.payload(kind: "songbriefDeletionPolicy"),
      expectedKind: "songbriefDeletionPolicy"
    )

    XCTAssertEqual(decoded, policy)
  }

  func testDeletionPolicyRejectsMalformedControlPayload() {
    XCTAssertNil(
      SnapshotDeletionPolicy(
        payload: [
          "kind": "songbriefDeletionPolicy",
          "version": 1,
          "deletedBeforeDateKey": 123,
        ],
        expectedKind: "songbriefDeletionPolicy"
      )
    )
    XCTAssertNil(
      SnapshotDeletionPolicy(
        payload: [
          "kind": "songbriefDeletionPolicy",
          "version": 2,
          "deleteAllThroughMillis": 123,
        ],
        expectedKind: "songbriefDeletionPolicy"
      )
    )
  }

  func testConflictRetriesKeepReplacementPolicyAcrossMultipleStaleServers() throws {
    let policy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: nil,
      deleteAllThroughMillis: 200
    )
    var fresh = cloudSnapshot(capturedAtMillis: 300, plays: 3)
    fresh["_replacesDeletionPolicy"] = policy.payload(kind: "songbriefDeletionPolicy")
    let firstClient = cloudRecord(snapshot: fresh)
    let firstStaleServer = cloudRecord(
      snapshot: cloudSnapshot(capturedAtMillis: 100, plays: 100)
    )

    let firstRetry = try XCTUnwrap(
      SnapshotCloudSync.mergeConflict(client: firstClient, server: firstStaleServer)
    )
    let secondStaleServer = cloudRecord(
      snapshot: cloudSnapshot(capturedAtMillis: 150, plays: 200)
    )
    let secondRetry = try XCTUnwrap(
      SnapshotCloudSync.mergeConflict(client: firstRetry, server: secondStaleServer)
    )
    let resolved = try decodedSnapshot(from: secondRetry)

    XCTAssertEqual((resolved["totalPlayCount"] as? NSNumber)?.intValue, 3)
    XCTAssertNotNil(resolved["_replacesDeletionPolicy"])
  }

  func testServerReplacementPolicyRejectsAStaleClientConflict() throws {
    let policy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: nil,
      deleteAllThroughMillis: 200
    )
    var fresh = cloudSnapshot(capturedAtMillis: 300, plays: 3)
    fresh["_replacesDeletionPolicy"] = policy.payload(kind: "songbriefDeletionPolicy")
    let freshServer = cloudRecord(snapshot: fresh)
    let staleClient = cloudRecord(
      snapshot: cloudSnapshot(capturedAtMillis: 100, plays: 100)
    )

    let resolvedRecord = try XCTUnwrap(
      SnapshotCloudSync.mergeConflict(client: staleClient, server: freshServer)
    )
    let resolved = try decodedSnapshot(from: resolvedRecord)

    XCTAssertEqual((resolved["totalPlayCount"] as? NSNumber)?.intValue, 3)
  }

  func testFreshConflictPreservesPolicyForALaterStaleConflict() throws {
    let olderPolicy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: nil,
      deleteAllThroughMillis: 150
    )
    let newerPolicy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: nil,
      deleteAllThroughMillis: 200
    )
    var firstFresh = cloudSnapshot(capturedAtMillis: 300, plays: 3)
    firstFresh["_replacesDeletionPolicy"] = newerPolicy.payload(
      kind: "songbriefDeletionPolicy"
    )
    var secondFresh = cloudSnapshot(capturedAtMillis: 350, plays: 4)
    secondFresh["_replacesDeletionPolicy"] = olderPolicy.payload(
      kind: "songbriefDeletionPolicy"
    )

    let firstResolution = try XCTUnwrap(
      SnapshotCloudSync.mergeConflict(
        client: cloudRecord(snapshot: firstFresh),
        server: cloudRecord(snapshot: secondFresh)
      )
    )
    let stale = cloudRecord(snapshot: cloudSnapshot(capturedAtMillis: 100, plays: 100))
    let secondResolution = try XCTUnwrap(
      SnapshotCloudSync.mergeConflict(client: stale, server: firstResolution)
    )
    let resolved = try decodedSnapshot(from: secondResolution)

    XCTAssertEqual((resolved["totalPlayCount"] as? NSNumber)?.intValue, 4)
    let payload = try XCTUnwrap(resolved["_replacesDeletionPolicy"] as? [String: Any])
    let retainedPolicy = try XCTUnwrap(
      SnapshotDeletionPolicy(
        payload: payload,
        expectedKind: "songbriefDeletionPolicy"
      )
    )
    XCTAssertEqual(retainedPolicy.deleteAllThroughMillis, 200)
  }

  func testNewerDeletionRedactsAnOlderProtectedRecapture() throws {
    let olderPolicy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: nil,
      deleteAllThroughMillis: 200
    )
    let newerPolicy = SnapshotDeletionPolicy(
      deletedBeforeDateKey: nil,
      deleteAllThroughMillis: 400
    )
    var recapture = cloudSnapshot(capturedAtMillis: 300, plays: 3)
    recapture["_replacesDeletionPolicy"] = olderPolicy.payload(
      kind: "songbriefDeletionPolicy"
    )
    var redaction = cloudSnapshot(capturedAtMillis: 150, plays: 0)
    redaction["source"] = "cloudDeletionRedaction"
    redaction["filterSignature"] = "songbriefDeletionRedactionV1"
    redaction["tracks"] = []
    redaction["_deletionPolicy"] = newerPolicy.payload(kind: "songbriefDeletionPolicy")

    let resolvedRecord = try XCTUnwrap(
      SnapshotCloudSync.mergeConflict(
        client: cloudRecord(snapshot: recapture),
        server: cloudRecord(snapshot: redaction)
      )
    )
    let resolved = try decodedSnapshot(from: resolvedRecord)

    XCTAssertEqual(resolved["source"] as? String, "cloudDeletionRedaction")
    XCTAssertEqual((resolved["totalPlayCount"] as? NSNumber)?.intValue, 0)
  }

  func testMergeRetainsTracksSelectedByTheNewerCapture() {
    let olderTracks: [[String: Any]] = (0..<500).map { index in
      [
        "id": "old-\(index)",
        "playCount": 1_000 - index,
        "skipCount": 0,
        "listeningSeconds": 10_000,
      ]
    }
    let newerTrack: [String: Any] = [
      "id": "new-low-count",
      "playCount": 1,
      "skipCount": 0,
      "listeningSeconds": 60,
    ]
    let older = librarySnapshot(capturedAtMillis: 100, tracks: olderTracks)
    let newer = librarySnapshot(capturedAtMillis: 200, tracks: [newerTrack])

    let merged = SnapshotMerge.merge(older, newer)
    let tracks = merged["tracks"] as? [[String: Any]]

    XCTAssertEqual(tracks?.count, 500)
    XCTAssertTrue(tracks?.contains { $0["id"] as? String == "new-low-count" } == true)
  }

  func testMergeMaxesCountersForATrackRetainedByTheNewerCapture() {
    let older = librarySnapshot(
      capturedAtMillis: 100,
      tracks: [["id": "same", "playCount": 10, "listeningSeconds": 600]]
    )
    let newer = librarySnapshot(
      capturedAtMillis: 200,
      tracks: [["id": "same", "playCount": 3, "listeningSeconds": 180]]
    )

    let merged = SnapshotMerge.merge(older, newer)
    let track = (merged["tracks"] as? [[String: Any]])?.first

    XCTAssertEqual((track?["playCount"] as? NSNumber)?.intValue, 10)
    XCTAssertEqual((track?["listeningSeconds"] as? NSNumber)?.intValue, 600)
  }

  private func snapshot(dateKey: String, capturedAtMillis: Int64) -> [String: Any] {
    [
      "dateKey": dateKey,
      "capturedAtMillis": capturedAtMillis,
    ]
  }

  private func librarySnapshot(
    capturedAtMillis: Int,
    tracks: [[String: Any]]
  ) -> [String: Any] {
    [
      "dateKey": "2026-09-21",
      "capturedAtMillis": capturedAtMillis,
      "source": "background",
      "filterSignature": "same",
      "trackCount": tracks.count,
      "totalPlayCount": 10,
      "totalSkipCount": 0,
      "totalListeningSeconds": 600,
      "tracks": tracks,
    ]
  }

  private func cloudSnapshot(capturedAtMillis: Int, plays: Int) -> [String: Any] {
    [
      "dateKey": "2026-09-21",
      "capturedAtMillis": capturedAtMillis,
      "source": "background",
      "filterSignature": "same",
      "trackCount": 1,
      "totalPlayCount": plays,
      "totalSkipCount": 0,
      "totalListeningSeconds": plays * 60,
      "tracks": [[
        "id": "track",
        "playCount": plays,
        "skipCount": 0,
        "listeningSeconds": plays * 60,
      ]],
    ]
  }

  private func cloudRecord(snapshot: [String: Any]) -> CKRecord {
    let record = CKRecord(
      recordType: SnapshotCloudSync.recordType,
      recordID: CKRecord.ID(recordName: "2026-09-21")
    )
    let data = try! JSONSerialization.data(withJSONObject: snapshot)
    record["payload"] = String(data: data, encoding: .utf8)! as CKRecordValue
    record["capturedAtMillis"] =
      ((snapshot["capturedAtMillis"] as? NSNumber)?.int64Value ?? 0) as CKRecordValue
    return record
  }

  private func decodedSnapshot(from record: CKRecord) throws -> [String: Any] {
    let payload = try XCTUnwrap(record["payload"] as? String)
    let data = try XCTUnwrap(payload.data(using: .utf8))
    return try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
  }
}
