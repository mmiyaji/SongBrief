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
  private static let pendingUploadDateKeysPreferenceKey =
    "songbrief_snapshot_cloud_pending_date_keys_v1"
  private static let maxTrackedDays = 1095
  private static let modifyBatchSize = 200
  private static let maxConflictRetryCount = 3
  private static let maxBackgroundUploadsPerRun = 2
  private static let pendingUploadLock = NSRecursiveLock()
  private static let operationCoordinator = SnapshotOperationCoordinator(
    label: "app.songbrief.snapshot-cloud-operations"
  )

  private static let payloadField = "payload"
  private static let capturedAtField = "capturedAtMillis"
  private static let trackCountField = "trackCount"
  private static let totalPlayField = "totalPlayCount"
  private static let totalSkipField = "totalSkipCount"
  private static let totalListeningField = "totalListeningSeconds"
  private static let filterSignatureField = "filterSignature"
  private static let deletionPolicyRecordName = "_songbrief_deletion_policy_v1"
  private static let deletionPolicyKind = "songbriefDeletionPolicy"
  private static let deletionRedactionSignature = "songbriefDeletionRedactionV1"
  private static let summaryFields = [
    capturedAtField, trackCountField, totalPlayField, totalSkipField,
    totalListeningField, filterSignatureField,
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
    operationCoordinator.enqueue { finished in
      performSync { payload in
        completion(payload)
        finished()
      }
    }
  }

  private static func performSync(completion: @escaping ([String: Any]) -> Void) {
    guard isEnabled else {
      finish(completion, status: "disabled")
      return
    }

    withAvailableAccount(completion) {
      fetchDeletionPolicy { policy, _, policyError in
        if let policyError {
          finish(completion, status: "error", message: policyError.localizedDescription)
          return
        }

        let localCountBeforePolicy = SongBriefSnapshotRefresh.localSnapshots().count
        guard applyDeletionPolicyLocally(policy) else {
          finish(
            completion,
            status: "error",
            message: "The cloud deletion policy could not be applied to local history."
          )
          return
        }

        let localSnapshots = SongBriefSnapshotRefresh.localSnapshots()
        let locallyDeleted = max(0, localCountBeforePolicy - localSnapshots.count)
        let localByDateKey = snapshotsByDateKey(localSnapshots).filter {
          !policy.deletes($0.value)
        }
        let candidateIDs = candidateRecordIDs(localDateKeys: Set(localByDateKey.keys))

        fetchRecords(ids: candidateIDs, desiredKeys: summaryFields) { summaries, error in
          if let error {
            finish(
              completion,
              status: locallyDeleted > 0 ? "partial" : "error",
              deleted: locallyDeleted,
              message: error.localizedDescription
            )
            return
          }

          let staleSummaries = summaries.filter { recordID, record in
            policy.deletes(
              dateKey: recordID.recordName,
              capturedAtMillis: int64Value(record[capturedAtField])
            )
          }
          let activeSummaries = summaries.filter { staleSummaries[$0.key] == nil }
          let immediateRecordsToSave: [CKRecord] = staleSummaries.compactMap { recordID, record in
            if let local = localByDateKey[recordID.recordName] {
              return apply(
                snapshot: local,
                protectedBy: policy,
                to: record
              )
            }
            guard !isRedactedSummary(record) else {
              return nil
            }
            return apply(redactionFor: recordID.recordName, policy: policy, to: record)
          }

          var payloadFetchIDs: [CKRecord.ID] = []
          var uploadOnlyDateKeys: [String] = []
          for dateKey in Set(localByDateKey.keys).union(activeSummaries.keys.map(\.recordName)) {
            let local = localByDateKey[dateKey]
            let cloudSummary = activeSummaries[CKRecord.ID(recordName: dateKey)]
            switch (local, cloudSummary) {
            case (nil, .some):
              payloadFetchIDs.append(CKRecord.ID(recordName: dateKey))
            case (.some(let local), .some(let cloud)):
              if summariesDiffer(local: local, cloud: cloud) {
                payloadFetchIDs.append(CKRecord.ID(recordName: dateKey))
              }
            case (.some, nil):
              if staleSummaries[CKRecord.ID(recordName: dateKey)] == nil {
                uploadOnlyDateKeys.append(dateKey)
              }
            case (nil, nil):
              break
            }
          }

          fetchRecords(ids: payloadFetchIDs, desiredKeys: nil) { fullRecords, fetchError in
            if let fetchError {
              finish(
                completion,
                status: locallyDeleted > 0 ? "partial" : "error",
                deleted: locallyDeleted,
                message: fetchError.localizedDescription
              )
              return
            }

            var recordsToSave = immediateRecordsToSave
            var mergedForLocal: [[String: Any]] = []
            for (recordID, record) in fullRecords {
              let dateKey = recordID.recordName
              guard let cloudSnapshot = snapshot(from: record),
                    !policy.deletes(cloudSnapshot) else {
                continue
              }
              let merged: [String: Any]
              if let local = localByDateKey[dateKey] {
                merged = SnapshotMerge.merge(
                  local,
                  cloudSnapshot,
                  preferredFilterSignature: SongBriefSnapshotRefresh.activeFilterSignature
                )
              } else {
                guard SnapshotMerge.canImportCloudOnlySnapshot(
                  cloudSnapshot,
                  activeFilterSignature: SongBriefSnapshotRefresh.activeFilterSignature,
                  hasActiveExclusions: SongBriefSnapshotRefresh.hasActiveExclusions
                ) else {
                  continue
                }
                merged = cloudSnapshot
              }
              if !NSDictionary(dictionary: merged).isEqual(to: cloudSnapshot) {
                recordsToSave.append(apply(snapshot: merged, protectedBy: policy, to: record))
              }
              if localByDateKey[dateKey] == nil
                || !NSDictionary(dictionary: merged)
                  .isEqual(to: localByDateKey[dateKey] ?? [:]) {
                mergedForLocal.append(merged)
              }
            }
            let missingPayloadIDs = Set(payloadFetchIDs).subtracting(fullRecords.keys)
            for recordID in missingPayloadIDs {
              guard let local = localByDateKey[recordID.recordName],
                    !policy.deletes(local) else {
                continue
              }
              let record = CKRecord(recordType: recordType, recordID: recordID)
              recordsToSave.append(apply(snapshot: local, protectedBy: policy, to: record))
            }
            for dateKey in uploadOnlyDateKeys {
              guard let local = localByDateKey[dateKey], !policy.deletes(local) else {
                continue
              }
              let record = CKRecord(
                recordType: recordType,
                recordID: CKRecord.ID(recordName: dateKey)
              )
              recordsToSave.append(apply(snapshot: local, protectedBy: policy, to: record))
            }

            let downloaded = mergedForLocal.isEmpty
              ? 0 : SongBriefSnapshotRefresh.mergeExternalSnapshots(mergedForLocal)
            if downloaded < mergedForLocal.count {
              finish(
                completion,
                status: downloaded > 0 || locallyDeleted > 0 ? "partial" : "error",
                downloaded: downloaded,
                deleted: locallyDeleted,
                message: "Some cloud history could not be written to local storage."
              )
              return
            }

            saveRecords(recordsToSave) { uploaded, saveError in
              if let saveError {
                finish(
                  completion,
                  status: downloaded > 0 || uploaded > 0 || locallyDeleted > 0
                    ? "partial" : "error",
                  downloaded: downloaded,
                  uploaded: uploaded,
                  deleted: locallyDeleted,
                  message: saveError.localizedDescription
                )
                return
              }
              finish(
                completion,
                status: downloaded > 0 || uploaded > 0 || locallyDeleted > 0
                  ? "synced" : "unchanged",
                downloaded: downloaded,
                uploaded: uploaded,
                deleted: locallyDeleted
              )
            }
          }
        }
      }
    }
  }

  // MARK: - Single-day upload (background task)

  /// Uploads the local snapshot for one dateKey, max-merging with any
  /// existing cloud record. Used by the background refresh task.
  static func uploadLocalSnapshot(
    dateKey: String,
    shouldContinue: @escaping () -> Bool = { true },
    completion: @escaping (Bool) -> Void
  ) {
    enqueuePendingUpload(dateKey)
    operationCoordinator.enqueue { finished in
      performPendingUploads(
        triggeringDateKey: dateKey,
        shouldContinue: shouldContinue
      ) { uploaded in
        completion(uploaded)
        finished()
      }
    }
  }

  private static func performPendingUploads(
    triggeringDateKey: String,
    shouldContinue: @escaping () -> Bool,
    completion: @escaping (Bool) -> Void
  ) {
    guard isEnabled else {
      completion(false)
      return
    }
    let pending = pendingUploadDateKeys()
    var selected = [triggeringDateKey]
    if let oldest = pending.first(where: { $0 != triggeringDateKey }) {
      selected.append(oldest)
    }
    selected = Array(selected.prefix(maxBackgroundUploadsPerRun))

    func upload(at index: Int, triggeringDateUploaded: Bool) {
      guard index < selected.count else {
        completion(triggeringDateUploaded)
        return
      }
      guard shouldContinue(), isEnabled else {
        completion(triggeringDateUploaded)
        return
      }
      let dateKey = selected[index]
      performUploadLocalSnapshot(
        dateKey: dateKey,
        shouldContinue: shouldContinue
      ) { uploaded, removeFromQueue in
        if removeFromQueue {
          removePendingUpload(dateKey)
        }
        upload(
          at: index + 1,
          triggeringDateUploaded: triggeringDateUploaded || (dateKey == triggeringDateKey && uploaded)
        )
      }
    }
    upload(at: 0, triggeringDateUploaded: false)
  }

  private static func performUploadLocalSnapshot(
    dateKey: String,
    shouldContinue: @escaping () -> Bool,
    completion: @escaping (_ uploaded: Bool, _ removeFromQueue: Bool) -> Void
  ) {
    guard isEnabled, shouldContinue() else {
      completion(false, false)
      return
    }
    guard let local = SnapshotFileStore.readSnapshot(dateKey: dateKey) else {
      completion(false, true)
      return
    }
    let capturedAtBeforeUpload = int64Value(local["capturedAtMillis"])

    let policyID = CKRecord.ID(recordName: deletionPolicyRecordName)
    let recordID = CKRecord.ID(recordName: dateKey)
    fetchRecords(ids: [policyID, recordID], desiredKeys: nil) { records, fetchError in
      guard fetchError == nil else {
        completion(false, false)
        return
      }
      let policy: SnapshotDeletionPolicy
      if let policyRecord = records[policyID] {
        guard let parsedPolicy = deletionPolicy(from: policyRecord) else {
          completion(false, false)
          return
        }
        policy = parsedPolicy
      } else {
        policy = .empty
      }
      guard applyDeletionPolicyLocally(policy) else {
        completion(false, false)
        return
      }
      if policy.deletes(local) {
        completion(true, true)
        return
      }

      let merged: [String: Any]
      let record: CKRecord
      if let existing = records[recordID] {
        guard let cloudSnapshot = snapshot(from: existing) else {
          completion(false, false)
          return
        }
        if policy.deletes(cloudSnapshot) {
          merged = local
        } else {
          merged = SnapshotMerge.merge(
            local,
            cloudSnapshot,
            preferredFilterSignature: SongBriefSnapshotRefresh.activeFilterSignature
          )
        }
        record = existing
      } else {
        merged = local
        record = CKRecord(recordType: recordType, recordID: recordID)
      }
      guard isEnabled, shouldContinue() else {
        completion(false, false)
        return
      }
      let recordToSave: CKRecord
      if let cloudRecord = records[recordID],
         let cloudSnapshot = snapshot(from: cloudRecord),
         policy.deletes(cloudSnapshot) {
        recordToSave = apply(
          snapshot: merged,
          protectedBy: policy,
          to: record
        )
      } else {
        recordToSave = apply(snapshot: merged, protectedBy: policy, to: record)
      }
      saveRecords([recordToSave]) { uploaded, error in
        guard error == nil, uploaded > 0 else {
          completion(false, false)
          return
        }
        guard isEnabled, shouldContinue() else {
          completion(false, false)
          return
        }
        fetchRecords(ids: [policyID, recordID], desiredKeys: nil) {
          latestRecords, latestFetchError in
          guard latestFetchError == nil else {
            completion(false, false)
            return
          }
          let latestPolicy: SnapshotDeletionPolicy
          if let policyRecord = latestRecords[policyID] {
            guard let parsedPolicy = deletionPolicy(from: policyRecord) else {
              completion(false, false)
              return
            }
            latestPolicy = parsedPolicy
          } else {
            latestPolicy = .empty
          }
          if latestPolicy.deletes(local) {
            let removedLocally = applyDeletionPolicyLocally(latestPolicy)
            guard let latestRecord = latestRecords[recordID],
                  let latestSnapshot = snapshot(from: latestRecord) else {
              completion(removedLocally, removedLocally)
              return
            }
            guard latestPolicy.deletes(latestSnapshot) else {
              completion(removedLocally, removedLocally)
              return
            }
            let redacted = apply(
              redactionFor: dateKey,
              policy: latestPolicy,
              to: latestRecord
            )
            saveRecords([redacted]) { _, redactionError in
              let handled = removedLocally && redactionError == nil
              completion(handled, handled)
            }
            return
          }
          let latestLocal = SnapshotFileStore.readSnapshot(dateKey: dateKey)
          let captureIsUnchanged = latestLocal.map {
            int64Value($0["capturedAtMillis"]) == capturedAtBeforeUpload
          } ?? true
          completion(true, captureIsUnchanged)
        }
      }
    }
  }

  private static func enqueuePendingUpload(_ dateKey: String) {
    pendingUploadLock.lock()
    defer { pendingUploadLock.unlock() }
    var pending = Set(pendingUploadDateKeys())
    pending.insert(dateKey)
    UserDefaults.standard.set(pending.sorted(), forKey: pendingUploadDateKeysPreferenceKey)
  }

  private static func removePendingUpload(_ dateKey: String) {
    pendingUploadLock.lock()
    defer { pendingUploadLock.unlock() }
    let remaining = pendingUploadDateKeys().filter { $0 != dateKey }
    UserDefaults.standard.set(remaining, forKey: pendingUploadDateKeysPreferenceKey)
  }

  private static func pendingUploadDateKeys() -> [String] {
    pendingUploadLock.lock()
    defer { pendingUploadLock.unlock() }
    let stored = UserDefaults.standard.stringArray(
      forKey: pendingUploadDateKeysPreferenceKey
    ) ?? []
    return Array(Set(stored)).sorted()
  }

  // MARK: - Deletion propagation

  /// Deletes cloud snapshots so records removed on this device do not
  /// reappear after the next sync. A nil cutoff deletes every tracked day;
  /// otherwise days strictly before the cutoff dateKey are deleted.
  static func deleteCloudSnapshots(
    olderThan cutoffDateKey: String?,
    completion: @escaping ([String: Any]) -> Void
  ) {
    operationCoordinator.enqueue { finished in
      performDeleteCloudSnapshots(olderThan: cutoffDateKey) { payload in
        completion(payload)
        finished()
      }
    }
  }

  private static func performDeleteCloudSnapshots(
    olderThan cutoffDateKey: String?,
    completion: @escaping ([String: Any]) -> Void
  ) {
    withAvailableAccount(completion) {
      let requestedPolicy = SnapshotDeletionPolicy(
        deletedBeforeDateKey: cutoffDateKey,
        deleteAllThroughMillis: cutoffDateKey == nil
          ? Int64(Date().timeIntervalSince1970 * 1000) : nil
      )
      if cutoffDateKey != nil, requestedPolicy.deletedBeforeDateKey == nil {
        finish(completion, status: "error", message: "The deletion cutoff date is invalid.")
        return
      }
      fetchDeletionPolicy { existingPolicy, existingRecord, fetchError in
        if let fetchError {
          finish(completion, status: "error", message: fetchError.localizedDescription)
          return
        }

        let mergedPolicy = existingPolicy.merged(with: requestedPolicy)
        let savePolicy: (@escaping (Int, Error?) -> Void) -> Void = { saved in
          guard mergedPolicy != existingPolicy || existingRecord == nil else {
            saved(0, nil)
            return
          }
          let record = apply(
            deletionPolicy: mergedPolicy,
            to: existingRecord ?? CKRecord(
              recordType: recordType,
              recordID: CKRecord.ID(recordName: deletionPolicyRecordName)
            )
          )
          saveRecords([record], completion: saved)
        }

        savePolicy { policySaved, policySaveError in
          if let policySaveError {
            finish(completion, status: "error", message: policySaveError.localizedDescription)
            return
          }
          let localDateKeysBeforePolicy = Set(
            SongBriefSnapshotRefresh.localSnapshots().compactMap { $0["dateKey"] as? String }
          )
          guard applyDeletionPolicyLocally(mergedPolicy) else {
            finish(
              completion,
              status: "partial",
              uploaded: policySaved,
              message: "The cloud deletion policy was saved, but local history cleanup failed."
            )
            return
          }

          let candidateIDs = candidateRecordIDs(localDateKeys: localDateKeysBeforePolicy)
          fetchRecords(ids: candidateIDs, desiredKeys: summaryFields) { summaries, error in
            if let error {
              finish(
                completion,
                status: "partial",
                uploaded: policySaved,
                message: error.localizedDescription
              )
              return
            }
            let recordsToRedact: [CKRecord] = summaries.compactMap { recordID, record in
              guard !isRedactedSummary(record) else {
                return nil
              }
              return mergedPolicy.deletes(
                dateKey: recordID.recordName,
                capturedAtMillis: int64Value(record[capturedAtField])
              ) ? apply(
                redactionFor: recordID.recordName,
                policy: mergedPolicy,
                to: record
              ) : nil
            }
            saveRecords(recordsToRedact) { redacted, redactionError in
              if let redactionError {
                finish(
                  completion,
                  status: "partial",
                  uploaded: policySaved,
                  deleted: redacted,
                  message: redactionError.localizedDescription
                )
                return
              }
              finish(completion, status: "synced", uploaded: policySaved, deleted: redacted)
            }
          }
        }
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
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
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

  private static func fetchDeletionPolicy(
    completion: @escaping (SnapshotDeletionPolicy, CKRecord?, Error?) -> Void
  ) {
    let recordID = CKRecord.ID(recordName: deletionPolicyRecordName)
    fetchRecords(ids: [recordID], desiredKeys: nil) { records, error in
      if let error {
        completion(.empty, nil, error)
        return
      }
      guard let record = records[recordID] else {
        completion(.empty, nil, nil)
        return
      }
      guard let policy = deletionPolicy(from: record) else {
        completion(
          .empty,
          record,
          NSError(
            domain: "SnapshotCloudSync",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The cloud deletion policy is invalid."]
          )
        )
        return
      }
      completion(policy, record, nil)
    }
  }

  private static func deletionPolicy(from record: CKRecord) -> SnapshotDeletionPolicy? {
    guard
      let payload = record[payloadField] as? String,
      let data = payload.data(using: .utf8),
      let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return SnapshotDeletionPolicy(payload: decoded, expectedKind: deletionPolicyKind)
  }

  private static func apply(
    deletionPolicy: SnapshotDeletionPolicy,
    to record: CKRecord
  ) -> CKRecord {
    let payload = deletionPolicy.payload(kind: deletionPolicyKind)
    if let data = try? JSONSerialization.data(withJSONObject: payload),
       let value = String(data: data, encoding: .utf8) {
      record[payloadField] = value as CKRecordValue
    }
    return record
  }

  private static func apply(
    redactionFor dateKey: String,
    policy: SnapshotDeletionPolicy,
    to record: CKRecord
  ) -> CKRecord {
    let capturedAtMillis = int64Value(record[capturedAtField])
    let redacted: [String: Any] = [
      "dateKey": dateKey,
      "capturedAtMillis": capturedAtMillis,
      "source": "cloudDeletionRedaction",
      "filterSignature": deletionRedactionSignature,
      "trackCount": 0,
      "totalPlayCount": 0,
      "totalSkipCount": 0,
      "totalListeningSeconds": 0,
      "tracks": [],
      "_deletionPolicy": policy.payload(kind: deletionPolicyKind),
    ]
    return apply(snapshot: redacted, to: record)
  }

  private static func redactionPolicy(
    from snapshot: [String: Any]
  ) -> SnapshotDeletionPolicy? {
    guard snapshot["source"] as? String == "cloudDeletionRedaction",
          let payload = snapshot["_deletionPolicy"] as? [String: Any] else {
      return nil
    }
    return SnapshotDeletionPolicy(payload: payload, expectedKind: deletionPolicyKind)
  }

  private static func applyDeletionPolicyLocally(_ policy: SnapshotDeletionPolicy) -> Bool {
    guard !policy.isEmpty else {
      return true
    }
    let countBefore = SnapshotFileStore.snapshotCount()
    let deleted = SnapshotFileStore.deleteSnapshots(
      olderThan: policy.deletedBeforeDateKey,
      capturedAtOrBefore: policy.deleteAllThroughMillis
    )
    if deleted, SnapshotFileStore.snapshotCount() < countBefore {
      let recent = SnapshotFileStore.readRecentSnapshots(limit: 15)
      let summary = SongBriefWidgetDataStore.buildSummary(
        from: recent,
        snapshotCount: SnapshotFileStore.snapshotCount()
      )
      SongBriefWidgetDataStore.update(summary: summary)
    }
    return deleted
  }

  private static func int64Value(_ value: Any?) -> Int64 {
    if let value = value as? NSNumber {
      return value.int64Value
    }
    return 0
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
      || (local["filterSignature"] as? String) != (cloud[filterSignatureField] as? String)
  }

  private static func isRedactedSummary(_ record: CKRecord) -> Bool {
    record[filterSignatureField] as? String == deletionRedactionSignature
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
    if let signature = compactedSnapshot["filterSignature"] as? String,
       !signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      record[filterSignatureField] = signature as CKRecordValue
    } else {
      record[filterSignatureField] = nil
    }
    return record
  }

  private static func apply(
    snapshot: [String: Any],
    protectedBy policy: SnapshotDeletionPolicy,
    to record: CKRecord
  ) -> CKRecord {
    guard !policy.isEmpty else {
      return apply(snapshot: snapshot, to: record)
    }
    var tagged = snapshot
    tagged["_replacesDeletionPolicy"] = policy.payload(kind: deletionPolicyKind)
    return apply(snapshot: tagged, to: record)
  }

  private static func replacementPolicy(
    from snapshot: [String: Any]
  ) -> SnapshotDeletionPolicy? {
    guard let payload = snapshot["_replacesDeletionPolicy"] as? [String: Any] else {
      return nil
    }
    return SnapshotDeletionPolicy(payload: payload, expectedKind: deletionPolicyKind)
  }

  private static func removingReplacementPolicy(
    from snapshot: [String: Any]
  ) -> [String: Any] {
    var cleaned = snapshot
    cleaned.removeValue(forKey: "_replacesDeletionPolicy")
    return cleaned
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
      saveRecordChunk(chunk, retryCount: 0) { chunkSaved, error in
        savedCount += chunkSaved
        if let error {
          lastError = error
        }
        group.leave()
      }
    }
    group.notify(queue: .main) {
      completion(savedCount, lastError)
    }
  }

  private static func saveRecordChunk(
    _ records: [CKRecord],
    retryCount: Int,
    completion: @escaping (Int, Error?) -> Void
  ) {
    let operation = CKModifyRecordsOperation(recordsToSave: records)
    operation.isAtomic = false
    operation.savePolicy = .ifServerRecordUnchanged
    operation.modifyRecordsCompletionBlock = { saved, _, error in
      DispatchQueue.main.async {
        let savedIDs = Set((saved ?? []).map(\.recordID))
        let savedCount = savedIDs.count
        guard let error else {
          completion(savedCount, nil)
          return
        }

        let pending = records.filter { !savedIDs.contains($0.recordID) }
        var retryRecords: [CKRecord] = []
        var finalError: Error?
        for record in pending {
          let recordError = itemError(for: record.recordID, in: error) ?? error
          if retryCount < maxConflictRetryCount,
             let serverRecord = serverRecordChanged(in: recordError),
             let merged = mergeConflict(client: record, server: serverRecord) {
            retryRecords.append(merged)
          } else {
            finalError = recordError
          }
        }

        guard !retryRecords.isEmpty else {
          completion(savedCount, finalError ?? error)
          return
        }
        saveRecordChunk(retryRecords, retryCount: retryCount + 1) {
          retriedSaved, retryError in
          completion(savedCount + retriedSaved, finalError ?? retryError)
        }
      }
    }
    database.add(operation)
  }

  private static func itemError(for recordID: CKRecord.ID, in error: Error) -> Error? {
    guard let ckError = error as? CKError,
          ckError.code == .partialFailure,
          let partialErrors = ckError.partialErrorsByItemID else {
      return nil
    }
    return partialErrors[recordID]
  }

  private static func serverRecordChanged(in error: Error) -> CKRecord? {
    guard let ckError = error as? CKError, ckError.code == .serverRecordChanged else {
      return nil
    }
    return ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
  }

  static func mergeConflict(client: CKRecord, server: CKRecord) -> CKRecord? {
    if client.recordID.recordName == deletionPolicyRecordName {
      guard let clientPolicy = deletionPolicy(from: client),
            let serverPolicy = deletionPolicy(from: server) else {
        return nil
      }
      return apply(deletionPolicy: serverPolicy.merged(with: clientPolicy), to: server)
    }
    guard let clientSnapshot = snapshot(from: client),
          let serverSnapshot = snapshot(from: server) else {
      return nil
    }
    let embeddedPolicies = [
      replacementPolicy(from: clientSnapshot),
      redactionPolicy(from: clientSnapshot),
      replacementPolicy(from: serverSnapshot),
      redactionPolicy(from: serverSnapshot),
    ].compactMap { $0 }
    let policy = embeddedPolicies.reduce(SnapshotDeletionPolicy.empty) {
      $0.merged(with: $1)
    }
    let cleanClient = removingReplacementPolicy(from: clientSnapshot)
    let cleanServer = removingReplacementPolicy(from: serverSnapshot)
    if !policy.isEmpty {
      switch (policy.deletes(clientSnapshot), policy.deletes(serverSnapshot)) {
      case (true, true):
        return apply(
          redactionFor: server.recordID.recordName,
          policy: policy,
          to: server
        )
      case (true, false):
        return apply(snapshot: cleanServer, protectedBy: policy, to: server)
      case (false, true):
        return apply(snapshot: cleanClient, protectedBy: policy, to: server)
      case (false, false):
        let merged = SnapshotMerge.merge(
          cleanClient,
          cleanServer,
          preferredFilterSignature: SongBriefSnapshotRefresh.activeFilterSignature
        )
        return apply(snapshot: merged, protectedBy: policy, to: server)
      }
    }
    let merged = SnapshotMerge.merge(
      cleanClient,
      cleanServer,
      preferredFilterSignature: SongBriefSnapshotRefresh.activeFilterSignature
    )
    return apply(snapshot: merged, to: server)
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

struct SnapshotDeletionPolicy: Equatable {
  static let empty = SnapshotDeletionPolicy(
    deletedBeforeDateKey: nil,
    deleteAllThroughMillis: nil
  )

  let deletedBeforeDateKey: String?
  let deleteAllThroughMillis: Int64?

  var isEmpty: Bool {
    deletedBeforeDateKey == nil && deleteAllThroughMillis == nil
  }

  init(deletedBeforeDateKey: String?, deleteAllThroughMillis: Int64?) {
    self.deletedBeforeDateKey = Self.nonEmpty(deletedBeforeDateKey)
    if let deleteAllThroughMillis, deleteAllThroughMillis > 0 {
      self.deleteAllThroughMillis = deleteAllThroughMillis
    } else {
      self.deleteAllThroughMillis = nil
    }
  }

  init?(payload: [String: Any], expectedKind: String) {
    guard payload["kind"] as? String == expectedKind,
          (payload["version"] as? NSNumber)?.intValue == 1 else {
      return nil
    }
    let rawDateKey = payload["deletedBeforeDateKey"] as? String
    if payload["deletedBeforeDateKey"] != nil,
       (rawDateKey == nil || Self.validDateKey(rawDateKey) == nil) {
      return nil
    }
    let rawDeleteAllThrough = payload["deleteAllThroughMillis"] as? NSNumber
    if payload["deleteAllThroughMillis"] != nil,
       (rawDeleteAllThrough?.int64Value ?? 0) <= 0 {
      return nil
    }
    self.init(
      deletedBeforeDateKey: rawDateKey,
      deleteAllThroughMillis: rawDeleteAllThrough?.int64Value
    )
  }

  func merged(with other: SnapshotDeletionPolicy) -> SnapshotDeletionPolicy {
    SnapshotDeletionPolicy(
      deletedBeforeDateKey: Self.maximum(deletedBeforeDateKey, other.deletedBeforeDateKey),
      deleteAllThroughMillis: Self.maximum(
        deleteAllThroughMillis,
        other.deleteAllThroughMillis
      )
    )
  }

  func deletes(_ snapshot: [String: Any]) -> Bool {
    guard let dateKey = snapshot["dateKey"] as? String else {
      return false
    }
    let capturedAtMillis = (snapshot["capturedAtMillis"] as? NSNumber)?.int64Value ?? 0
    return deletes(dateKey: dateKey, capturedAtMillis: capturedAtMillis)
  }

  func deletes(dateKey: String, capturedAtMillis: Int64) -> Bool {
    if let deletedBeforeDateKey, dateKey < deletedBeforeDateKey {
      return true
    }
    if let deleteAllThroughMillis, capturedAtMillis <= deleteAllThroughMillis {
      return true
    }
    return false
  }

  func payload(kind: String) -> [String: Any] {
    var result: [String: Any] = ["kind": kind, "version": 1]
    if let deletedBeforeDateKey {
      result["deletedBeforeDateKey"] = deletedBeforeDateKey
    }
    if let deleteAllThroughMillis {
      result["deleteAllThroughMillis"] = deleteAllThroughMillis
    }
    return result
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return validDateKey(trimmed)
  }

  private static func validDateKey(_ value: String?) -> String? {
    guard let value,
          value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
      return nil
    }
    return value
  }

  private static func maximum<T: Comparable>(_ lhs: T?, _ rhs: T?) -> T? {
    switch (lhs, rhs) {
    case (.some(let lhs), .some(let rhs)):
      return max(lhs, rhs)
    case (.some(let lhs), nil):
      return lhs
    case (nil, .some(let rhs)):
      return rhs
    case (nil, nil):
      return nil
    }
  }
}

final class SnapshotOperationCoordinator {
  typealias Operation = (@escaping () -> Void) -> Void

  private struct PendingOperation {
    let identifier: UInt64
    let operation: Operation
  }

  private let queue: DispatchQueue
  private var pending: [PendingOperation] = []
  private var activeIdentifier: UInt64?
  private var nextIdentifier: UInt64 = 0

  init(label: String) {
    queue = DispatchQueue(label: label)
  }

  func enqueue(_ operation: @escaping Operation) {
    queue.async {
      let identifier = self.nextIdentifier
      self.nextIdentifier &+= 1
      self.pending.append(
        PendingOperation(identifier: identifier, operation: operation)
      )
      self.startNextIfNeeded()
    }
  }

  private func startNextIfNeeded() {
    guard activeIdentifier == nil, !pending.isEmpty else {
      return
    }
    let next = pending.removeFirst()
    activeIdentifier = next.identifier
    next.operation { [weak self] in
      self?.complete(next.identifier)
    }
  }

  private func complete(_ identifier: UInt64) {
    queue.async {
      guard self.activeIdentifier == identifier else {
        return
      }
      self.activeIdentifier = nil
      self.startNextIfNeeded()
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

  static func merge(
    _ a: [String: Any],
    _ b: [String: Any],
    preferredFilterSignature: String? = nil
  ) -> [String: Any] {
    let aCaptured = intValue(a["capturedAtMillis"])
    let bCaptured = intValue(b["capturedAtMillis"])
    let newer = aCaptured >= bCaptured ? a : b
    let older = aCaptured >= bCaptured ? b : a
    let aSignature = stringValue(a["filterSignature"])
    let bSignature = stringValue(b["filterSignature"])
    if aSignature != bSignature, aSignature != nil || bSignature != nil {
      if let preferred = stringValue(preferredFilterSignature) {
        if aSignature == preferred, bSignature != preferred {
          return normalized(a)
        }
        if bSignature == preferred, aSignature != preferred {
          return normalized(b)
        }
      }
      if aSignature != nil, bSignature == nil {
        return normalized(a)
      }
      if bSignature != nil, aSignature == nil {
        return normalized(b)
      }
      return normalized(morePrivacyPreserving(a, b, newer: newer))
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

  static func canImportCloudOnlySnapshot(
    _ snapshot: [String: Any],
    activeFilterSignature: String,
    hasActiveExclusions: Bool
  ) -> Bool {
    guard hasActiveExclusions else {
      return true
    }
    return stringValue(snapshot["filterSignature"])
      == stringValue(activeFilterSignature)
  }

  /// When neither snapshot matches this device's active profile, retain the
  /// observation exposing fewer library counters. This is deliberately
  /// conservative: profile intent cannot be reconstructed from a hash alone.
  private static func morePrivacyPreserving(
    _ a: [String: Any],
    _ b: [String: Any],
    newer: [String: Any]
  ) -> [String: Any] {
    let exposureKeys = [
      "trackCount", "totalPlayCount", "totalListeningSeconds", "totalSkipCount",
    ]
    for key in exposureKeys {
      let aValue = intValue(a[key])
      let bValue = intValue(b[key])
      if aValue != bValue {
        return aValue < bValue ? a : b
      }
    }
    return newer
  }

  /// Keeps the tracks selected by the newer capture. Matching counters are
  /// max-merged, then unused capacity is filled from the older snapshot.
  /// This prevents accumulated high-count history from evicting a recently
  /// played low-count track selected by the current capture.
  private static func mergeTracks(
    older: [[String: Any]],
    newer: [[String: Any]]
  ) -> [[String: Any]] {
    var olderByID: [String: [String: Any]] = [:]
    for track in older {
      if let id = track["id"] as? String {
        olderByID[id] = track
      }
    }
    var retainedByID: [String: [String: Any]] = [:]
    for track in newer {
      guard let id = track["id"] as? String else {
        continue
      }
      guard let existing = olderByID[id] else {
        retainedByID[id] = track
        continue
      }
      var mergedTrack = track
      for key in counterKeys {
        let maxValue = max(intValue(existing[key]), intValue(track[key]))
        if maxValue > 0 || existing[key] != nil || track[key] != nil {
          mergedTrack[key] = maxValue
        }
      }
      retainedByID[id] = mergedTrack
    }

    if retainedByID.count < maxMergedTracks {
      let olderRemainder = compactTracks(
        olderByID.compactMap { id, track in
          retainedByID[id] == nil ? track : nil
        }
      )
      for track in olderRemainder.prefix(maxMergedTracks - retainedByID.count) {
        if let id = track["id"] as? String {
          retainedByID[id] = track
        }
      }
    }
    return compactTracks(Array(retainedByID.values))
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
