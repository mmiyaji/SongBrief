import CloudKit
import Foundation

/// Syncs daily listening-record snapshots with the user's private CloudKit
/// database. One record per day (recordName == dateKey) so devices on the
/// same Apple ID converge by max-merging monotonic counters.
enum SnapshotCloudSync {
  static let containerIdentifier = "iCloud.app.songbrief.songbrief"
  static let recordType = "DailySnapshot"
  private static let cloudSyncEnabledPreferenceKey =
    "flutter.songbrief_snapshot_cloud_sync_enabled_v1"
  private static let maxTrackedDays = 1095
  private static let modifyBatchSize = 200

  private static let payloadField = "payload"
  private static let capturedAtField = "capturedAtMillis"
  private static let trackCountField = "trackCount"
  private static let totalPlayField = "totalPlayCount"
  private static let totalSkipField = "totalSkipCount"
  private static let totalListeningField = "totalListeningSeconds"
  private static let summaryFields = [
    capturedAtField, trackCountField, totalPlayField, totalSkipField,
    totalListeningField,
  ]

  static var isEnabled: Bool {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: cloudSyncEnabledPreferenceKey) == nil {
      return true
    }
    return defaults.bool(forKey: cloudSyncEnabledPreferenceKey)
  }

  private static var database: CKDatabase {
    CKContainer(identifier: containerIdentifier).privateCloudDatabase
  }

  // MARK: - Full sync (foreground)

  /// Merges local and cloud snapshot histories in both directions.
  /// Completion payload: status plus downloaded/uploaded record counts.
  static func sync(completion: @escaping ([String: Any]) -> Void) {
    guard isEnabled else {
      finish(completion, status: "disabled")
      return
    }

    withAvailableAccount(completion) {
      let localSnapshots = SongBriefSnapshotRefresh.localSnapshots()
      let localByDateKey = snapshotsByDateKey(localSnapshots)
      let candidateIDs = candidateRecordIDs(localDateKeys: Set(localByDateKey.keys))

      fetchRecords(ids: candidateIDs, desiredKeys: summaryFields) { summaries, error in
        if let error, summaries.isEmpty {
          finish(completion, status: "error", message: error.localizedDescription)
          return
        }

        var payloadFetchIDs: [CKRecord.ID] = []
        var uploadOnlyDateKeys: [String] = []
        for dateKey in Set(localByDateKey.keys).union(summaries.keys.map(\.recordName)) {
          let local = localByDateKey[dateKey]
          let cloudSummary = summaries[CKRecord.ID(recordName: dateKey)]
          switch (local, cloudSummary) {
          case (nil, .some):
            payloadFetchIDs.append(CKRecord.ID(recordName: dateKey))
          case (.some(let local), .some(let cloud)):
            if summariesDiffer(local: local, cloud: cloud) {
              payloadFetchIDs.append(CKRecord.ID(recordName: dateKey))
            }
          case (.some, nil):
            uploadOnlyDateKeys.append(dateKey)
          case (nil, nil):
            break
          }
        }

        fetchRecords(ids: payloadFetchIDs, desiredKeys: nil) { fullRecords, fetchError in
          if let fetchError, fullRecords.isEmpty, !payloadFetchIDs.isEmpty {
            finish(completion, status: "error", message: fetchError.localizedDescription)
            return
          }

          var recordsToSave: [CKRecord] = []
          var mergedForLocal: [[String: Any]] = []
          for (recordID, record) in fullRecords {
            let dateKey = recordID.recordName
            guard let cloudSnapshot = snapshot(from: record) else {
              continue
            }
            let merged: [String: Any]
            if let local = localByDateKey[dateKey] {
              merged = SnapshotMerge.merge(local, cloudSnapshot)
            } else {
              merged = cloudSnapshot
            }
            if !NSDictionary(dictionary: merged).isEqual(to: cloudSnapshot) {
              recordsToSave.append(apply(snapshot: merged, to: record))
            }
            if localByDateKey[dateKey] == nil
              || !NSDictionary(dictionary: merged)
                .isEqual(to: localByDateKey[dateKey] ?? [:]) {
              mergedForLocal.append(merged)
            }
          }
          for dateKey in uploadOnlyDateKeys {
            guard let local = localByDateKey[dateKey] else {
              continue
            }
            let record = CKRecord(
              recordType: recordType,
              recordID: CKRecord.ID(recordName: dateKey)
            )
            recordsToSave.append(apply(snapshot: local, to: record))
          }

          let downloaded = mergedForLocal.count
          if downloaded > 0 {
            _ = SongBriefSnapshotRefresh.mergeExternalSnapshots(mergedForLocal)
          }

          saveRecords(recordsToSave) { uploaded, saveError in
            if let saveError, uploaded == 0, !recordsToSave.isEmpty {
              finish(
                completion,
                status: downloaded > 0 ? "partial" : "error",
                downloaded: downloaded,
                message: saveError.localizedDescription
              )
              return
            }
            finish(
              completion,
              status: downloaded > 0 || uploaded > 0 ? "synced" : "unchanged",
              downloaded: downloaded,
              uploaded: uploaded
            )
          }
        }
      }
    }
  }

  // MARK: - Single-day upload (background task)

  /// Uploads the local snapshot for one dateKey, max-merging with any
  /// existing cloud record. Used by the background refresh task.
  static func uploadLocalSnapshot(dateKey: String, completion: @escaping (Bool) -> Void) {
    guard isEnabled else {
      completion(false)
      return
    }
    guard
      let local = SongBriefSnapshotRefresh.localSnapshots().first(where: {
        $0["dateKey"] as? String == dateKey
      })
    else {
      completion(false)
      return
    }

    let recordID = CKRecord.ID(recordName: dateKey)
    database.fetch(withRecordID: recordID) { existing, _ in
      let merged: [String: Any]
      let record: CKRecord
      if let existing, let cloudSnapshot = snapshot(from: existing) {
        merged = SnapshotMerge.merge(local, cloudSnapshot)
        record = existing
      } else {
        merged = local
        record = CKRecord(recordType: recordType, recordID: recordID)
      }
      saveRecords([apply(snapshot: merged, to: record)]) { uploaded, _ in
        completion(uploaded > 0)
      }
    }
  }

  // MARK: - Deletion propagation

  /// Deletes cloud snapshots so records removed on this device do not
  /// reappear after the next sync. A nil cutoff deletes every tracked day;
  /// otherwise days strictly before the cutoff dateKey are deleted.
  static func deleteCloudSnapshots(
    olderThan cutoffDateKey: String?,
    completion: @escaping ([String: Any]) -> Void
  ) {
    withAvailableAccount(completion) {
      let localDateKeys = Set(SongBriefSnapshotRefresh.localSnapshots().compactMap {
        $0["dateKey"] as? String
      })
      let ids = candidateRecordIDs(localDateKeys: localDateKeys).filter { id in
        guard let cutoffDateKey else {
          return true
        }
        return id.recordName < cutoffDateKey
      }
      deleteRecords(ids) { deleted, error in
        if let error {
          finish(
            completion,
            status: deleted > 0 ? "partial" : "error",
            deleted: deleted,
            message: error.localizedDescription
          )
          return
        }
        finish(completion, status: "synced", deleted: deleted)
      }
    }
  }

  // MARK: - Account and helpers

  private static func withAvailableAccount(
    _ completion: @escaping ([String: Any]) -> Void,
    then body: @escaping () -> Void
  ) {
    CKContainer(identifier: containerIdentifier).accountStatus { status, _ in
      switch status {
      case .available:
        body()
      case .noAccount:
        finish(completion, status: "noAccount")
      default:
        finish(completion, status: "unavailable")
      }
    }
  }

  /// Record IDs worth inspecting: every locally known day plus the trailing
  /// tracked window, so queries need no CloudKit indexes.
  private static func candidateRecordIDs(localDateKeys: Set<String>) -> [CKRecord.ID] {
    var dateKeys = localDateKeys
    let calendar = Calendar.current
    let today = Date()
    for offset in 0..<maxTrackedDays {
      guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
        continue
      }
      let components = calendar.dateComponents([.year, .month, .day], from: day)
      dateKeys.insert(
        String(
          format: "%04d-%02d-%02d",
          components.year ?? 0,
          components.month ?? 0,
          components.day ?? 0
        )
      )
    }
    return dateKeys.sorted().map { CKRecord.ID(recordName: $0) }
  }

  private static func snapshotsByDateKey(
    _ snapshots: [[String: Any]]
  ) -> [String: [String: Any]] {
    var byDateKey: [String: [String: Any]] = [:]
    for snapshot in snapshots {
      if let dateKey = snapshot["dateKey"] as? String {
        byDateKey[dateKey] = snapshot
      }
    }
    return byDateKey
  }

  private static func summariesDiffer(local: [String: Any], cloud: CKRecord) -> Bool {
    func intValue(_ value: Any?) -> Int {
      if let value = value as? Int {
        return value
      }
      if let value = value as? Int64 {
        return Int(value)
      }
      if let value = value as? NSNumber {
        return value.intValue
      }
      return 0
    }

    return intValue(local["capturedAtMillis"]) != intValue(cloud[capturedAtField])
      || intValue(local["trackCount"]) != intValue(cloud[trackCountField])
      || intValue(local["totalPlayCount"]) != intValue(cloud[totalPlayField])
      || intValue(local["totalSkipCount"]) != intValue(cloud[totalSkipField])
      || intValue(local["totalListeningSeconds"]) != intValue(cloud[totalListeningField])
  }

  private static func snapshot(from record: CKRecord) -> [String: Any]? {
    guard
      let payload = record[payloadField] as? String,
      let data = payload.data(using: .utf8),
      let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return SnapshotMerge.normalized(decoded)
  }

  private static func apply(snapshot: [String: Any], to record: CKRecord) -> CKRecord {
    func intValue(_ value: Any?) -> Int64 {
      if let value = value as? NSNumber {
        return value.int64Value
      }
      return 0
    }

    let compactedSnapshot = SnapshotMerge.normalized(snapshot)
    if JSONSerialization.isValidJSONObject(compactedSnapshot),
       let data = try? JSONSerialization.data(withJSONObject: compactedSnapshot),
       let payload = String(data: data, encoding: .utf8) {
      record[payloadField] = payload as CKRecordValue
    }
    record[capturedAtField] = intValue(compactedSnapshot["capturedAtMillis"]) as CKRecordValue
    record[trackCountField] = intValue(compactedSnapshot["trackCount"]) as CKRecordValue
    record[totalPlayField] = intValue(compactedSnapshot["totalPlayCount"]) as CKRecordValue
    record[totalSkipField] = intValue(compactedSnapshot["totalSkipCount"]) as CKRecordValue
    record[totalListeningField] =
      intValue(compactedSnapshot["totalListeningSeconds"]) as CKRecordValue
    return record
  }

  private static func fetchRecords(
    ids: [CKRecord.ID],
    desiredKeys: [String]?,
    completion: @escaping ([CKRecord.ID: CKRecord], Error?) -> Void
  ) {
    guard !ids.isEmpty else {
      completion([:], nil)
      return
    }

    var results: [CKRecord.ID: CKRecord] = [:]
    var lastError: Error?
    let group = DispatchGroup()
    for chunk in stride(from: 0, to: ids.count, by: modifyBatchSize).map({
      Array(ids[$0..<min($0 + modifyBatchSize, ids.count)])
    }) {
      group.enter()
      let operation = CKFetchRecordsOperation(recordIDs: chunk)
      operation.desiredKeys = desiredKeys
      operation.perRecordCompletionBlock = { record, recordID, _ in
        if let record, let recordID {
          DispatchQueue.main.async {
            results[recordID] = record
          }
        }
      }
      operation.fetchRecordsCompletionBlock = { _, error in
        DispatchQueue.main.async {
          if let error, !isMissingItemError(error) {
            lastError = error
          }
          group.leave()
        }
      }
      database.add(operation)
    }
    group.notify(queue: .main) {
      completion(results, lastError)
    }
  }

  private static func saveRecords(
    _ records: [CKRecord],
    completion: @escaping (Int, Error?) -> Void
  ) {
    guard !records.isEmpty else {
      completion(0, nil)
      return
    }

    var savedCount = 0
    var lastError: Error?
    let group = DispatchGroup()
    for chunk in stride(from: 0, to: records.count, by: modifyBatchSize).map({
      Array(records[$0..<min($0 + modifyBatchSize, records.count)])
    }) {
      group.enter()
      let operation = CKModifyRecordsOperation(recordsToSave: chunk)
      operation.savePolicy = .allKeys
      operation.modifyRecordsCompletionBlock = { saved, _, error in
        DispatchQueue.main.async {
          savedCount += saved?.count ?? 0
          if let error {
            lastError = error
          }
          group.leave()
        }
      }
      database.add(operation)
    }
    group.notify(queue: .main) {
      completion(savedCount, lastError)
    }
  }

  private static func deleteRecords(
    _ ids: [CKRecord.ID],
    completion: @escaping (Int, Error?) -> Void
  ) {
    guard !ids.isEmpty else {
      completion(0, nil)
      return
    }

    var deletedCount = 0
    var lastError: Error?
    let group = DispatchGroup()
    for chunk in stride(from: 0, to: ids.count, by: modifyBatchSize).map({
      Array(ids[$0..<min($0 + modifyBatchSize, ids.count)])
    }) {
      group.enter()
      let operation = CKModifyRecordsOperation(recordIDsToDelete: chunk)
      operation.modifyRecordsCompletionBlock = { _, deleted, error in
        DispatchQueue.main.async {
          deletedCount += deleted?.count ?? 0
          if let error, !isMissingItemError(error) {
            lastError = error
          }
          group.leave()
        }
      }
      database.add(operation)
    }
    group.notify(queue: .main) {
      completion(deletedCount, lastError)
    }
  }

  private static func isMissingItemError(_ error: Error) -> Bool {
    guard let ckError = error as? CKError else {
      return false
    }
    if ckError.code == .unknownItem {
      return true
    }
    if ckError.code == .partialFailure,
       let partialErrors = ckError.partialErrorsByItemID {
      return partialErrors.values.allSatisfy { partialError in
        (partialError as? CKError)?.code == .unknownItem
      }
    }
    return false
  }

  private static func finish(
    _ completion: @escaping ([String: Any]) -> Void,
    status: String,
    downloaded: Int = 0,
    uploaded: Int = 0,
    deleted: Int = 0,
    message: String? = nil
  ) {
    var payload: [String: Any] = [
      "status": status,
      "downloaded": downloaded,
      "uploaded": uploaded,
      "deleted": deleted,
    ]
    if let message {
      payload["message"] = message
    }
    DispatchQueue.main.async {
      completion(payload)
    }
  }
}

/// Profile-aware merge for daily snapshots. Counters are max-merged only when
/// both snapshots used the same library-exclusion profile. A changed profile
/// replaces the prior observation so excluded tracks cannot survive forever.
enum SnapshotMerge {
  private static let maxMergedTracks = 500
  private static let counterKeys = [
    "playCount", "skipCount", "listeningSeconds", "lastPlayedAtMillis",
  ]

  static func normalized(_ snapshot: [String: Any]) -> [String: Any] {
    guard let tracks = snapshot["tracks"] as? [[String: Any]],
          tracks.count > maxMergedTracks else {
      return snapshot
    }
    var compacted = snapshot
    compacted["tracks"] = compactTracks(tracks)
    return compacted
  }

  static func merge(_ a: [String: Any], _ b: [String: Any]) -> [String: Any] {
    let aCaptured = intValue(a["capturedAtMillis"])
    let bCaptured = intValue(b["capturedAtMillis"])
    let newer = aCaptured >= bCaptured ? a : b
    let older = aCaptured >= bCaptured ? b : a
    let aSignature = stringValue(a["filterSignature"])
    let bSignature = stringValue(b["filterSignature"])
    if aSignature != bSignature, aSignature != nil || bSignature != nil {
      return normalized(newer)
    }

    var merged: [String: Any] = [:]
    merged["dateKey"] = newer["dateKey"] ?? older["dateKey"] ?? ""
    merged["capturedAtMillis"] = max(aCaptured, bCaptured)
    merged["source"] = newer["source"] ?? "foreground"
    if let filterSignature = aSignature ?? bSignature {
      merged["filterSignature"] = filterSignature
    }
    merged["trackCount"] = max(intValue(a["trackCount"]), intValue(b["trackCount"]))
    merged["totalPlayCount"] = max(
      intValue(a["totalPlayCount"]), intValue(b["totalPlayCount"])
    )
    merged["totalSkipCount"] = max(
      intValue(a["totalSkipCount"]), intValue(b["totalSkipCount"])
    )
    merged["totalListeningSeconds"] = max(
      intValue(a["totalListeningSeconds"]), intValue(b["totalListeningSeconds"])
    )
    merged["tracks"] = mergeTracks(
      older: older["tracks"] as? [[String: Any]] ?? [],
      newer: newer["tracks"] as? [[String: Any]] ?? []
    )
    return merged
  }

  /// Union by track id. Metadata comes from the newer snapshot when both
  /// have the track; counters take the max of both observations.
  private static func mergeTracks(
    older: [[String: Any]],
    newer: [[String: Any]]
  ) -> [[String: Any]] {
    var byID: [String: [String: Any]] = [:]
    for track in older {
      if let id = track["id"] as? String {
        byID[id] = track
      }
    }
    for track in newer {
      guard let id = track["id"] as? String else {
        continue
      }
      guard let existing = byID[id] else {
        byID[id] = track
        continue
      }
      var mergedTrack = track
      for key in counterKeys {
        let maxValue = max(intValue(existing[key]), intValue(track[key]))
        if maxValue > 0 || existing[key] != nil || track[key] != nil {
          mergedTrack[key] = maxValue
        }
      }
      byID[id] = mergedTrack
    }
    return compactTracks(Array(byID.values))
  }

  private static func compactTracks(_ tracks: [[String: Any]]) -> [[String: Any]] {
    let ranked = tracks.sorted { lhs, rhs in
      let lhsPlay = intValue(lhs["playCount"])
      let rhsPlay = intValue(rhs["playCount"])
      if lhsPlay != rhsPlay {
        return lhsPlay > rhsPlay
      }
      let lhsSkip = intValue(lhs["skipCount"])
      let rhsSkip = intValue(rhs["skipCount"])
      if lhsSkip != rhsSkip {
        return lhsSkip > rhsSkip
      }
      let lhsLastPlayed = intValue(lhs["lastPlayedAtMillis"])
      let rhsLastPlayed = intValue(rhs["lastPlayedAtMillis"])
      if lhsLastPlayed != rhsLastPlayed {
        return lhsLastPlayed > rhsLastPlayed
      }
      return trackID(lhs) < trackID(rhs)
    }
    return Array(ranked.prefix(maxMergedTracks)).sorted {
      trackID($0) < trackID($1)
    }
  }

  private static func intValue(_ value: Any?) -> Int {
    if let value = value as? NSNumber {
      return value.intValue
    }
    return 0
  }

  private static func trackID(_ track: [String: Any]) -> String {
    track["id"] as? String ?? ""
  }

  private static func stringValue(_ value: Any?) -> String? {
    guard let value = value as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
