import BackgroundTasks
import Foundation
import Flutter
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    SongBriefSnapshotRefresh.register()
    SongBriefSnapshotRefresh.schedule()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    MusicLibraryBridge.register(with: engineBridge.applicationRegistrar.messenger())
  }
}

enum SongBriefSnapshotRefresh {
  private static let taskIdentifier = "app.songbrief.snapshot-refresh"
  private static let recordingEnabledPreferenceKey =
    "flutter.songbrief_snapshot_recording_enabled_v1"
  private static let excludedPlaylistsPreferenceKey =
    "flutter.songbrief_excluded_playlists_v1"
  private static let excludedGenresPreferenceKey =
    "flutter.songbrief_excluded_genres_v1"
  private static let excludedKeywordsPreferenceKey =
    "flutter.songbrief_excluded_keywords_v1"
  private static let maxSnapshotTracks = 500
  private static let refreshIntervalHours = 6
  private static let pendingRequestToleranceMinutes = 5
  private static let cloudUploadWaitSeconds: TimeInterval = 10

  static func register() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: taskIdentifier,
      using: nil
    ) { task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(refreshTask)
    }
  }

  static func schedule(replaceExisting: Bool = false) {
    guard isRecordingEnabled else {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
      SnapshotRefreshLogStore.record(
        event: "schedule_cancelled",
        details: ["reason": "recording_disabled"]
      )
      return
    }

    if replaceExisting {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
      submitScheduleRequest(reason: "settings_changed")
      return
    }

    BGTaskScheduler.shared.getPendingTaskRequests { requests in
      if let existing = requests.first(where: { $0.identifier == taskIdentifier }) {
        if shouldReplacePendingRequest(
          earliestBeginDate: existing.earliestBeginDate,
          now: Date()
        ) {
          var details: [String: Any] = ["reason": "legacy_interval"]
          if let previous = existing.earliestBeginDate {
            details["previousEarliestBeginAtMillis"] = Int(
              previous.timeIntervalSince1970 * 1000
            )
          }
          BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
          SnapshotRefreshLogStore.record(
            event: "schedule_replaced",
            details: details
          )
          submitScheduleRequest(reason: "legacy_interval")
          return
        }
        var details: [String: Any] = [:]
        if let next = existing.earliestBeginDate {
          details["nextEarliestBeginAtMillis"] = Int(
            next.timeIntervalSince1970 * 1000
          )
        }
        SnapshotRefreshLogStore.record(
          event: "schedule_kept",
          details: details
        )
        return
      }
      submitScheduleRequest(reason: "no_pending_request")
    }
  }

  static func shouldReplacePendingRequest(
    earliestBeginDate: Date?,
    now: Date
  ) -> Bool {
    guard let earliestBeginDate else {
      return false
    }
    let latestExpectedDate = now.addingTimeInterval(
      TimeInterval(
        refreshIntervalHours * 60 * 60 + pendingRequestToleranceMinutes * 60
      )
    )
    return earliestBeginDate > latestExpectedDate
  }

  private static func submitScheduleRequest(reason: String) {
    let intervalHours = refreshIntervalHours
    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(
      timeIntervalSinceNow: TimeInterval(intervalHours * 60 * 60)
    )
    do {
      try BGTaskScheduler.shared.submit(request)
      SnapshotRefreshLogStore.record(
        event: "schedule_submitted",
        details: [
          "intervalHours": intervalHours,
          "reason": reason,
          "nextEarliestBeginAtMillis": Int(
            (request.earliestBeginDate ?? Date()).timeIntervalSince1970 * 1000
          )
        ]
      )
    } catch {
      let failure = error as NSError
      SnapshotRefreshLogStore.record(
        event: "schedule_failed",
        details: [
          "errorDomain": failure.domain,
          "errorCode": failure.code,
          "intervalHours": intervalHours,
          "reason": reason
        ]
      )
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    let runID = UUID().uuidString
    SnapshotRefreshLogStore.record(
      event: "task_started",
      details: ["runId": runID, "intervalHours": refreshIntervalHours]
    )
    schedule()

    let completion = SnapshotRefreshCompletion(task)
    task.expirationHandler = {
      completion.completeForExpiration { localCaptureSucceeded in
        if localCaptureSucceeded {
          SnapshotRefreshLogStore.record(
            event: "cloud_upload_deferred",
            details: ["runId": runID, "reason": "task_expired"]
          )
        } else {
          SnapshotRefreshLogStore.record(
            event: "task_expired",
            details: ["runId": runID]
          )
        }
        SnapshotRefreshLogStore.record(
          event: "task_completed",
          details: ["runId": runID, "success": localCaptureSucceeded]
        )
      }
    }

    DispatchQueue.global(qos: .utility).async {
      guard !completion.isCompleted, let dateKey = captureSnapshot(runID: runID) else {
        completion.complete(success: false) {
          SnapshotRefreshLogStore.record(
            event: "task_completed",
            details: ["runId": runID, "success": false]
          )
        }
        return
      }

      // The local capture already succeeded; the cloud upload is best effort
      // and must not fail the refresh task.
      guard completion.markLocalCaptureSucceeded() else {
        return
      }
      guard SnapshotCloudSync.isEnabled else {
        SnapshotRefreshLogStore.record(
          event: "cloud_upload_skipped",
          details: ["runId": runID, "reason": "disabled"]
        )
        completion.complete(success: true) {
          SnapshotRefreshLogStore.record(
            event: "task_completed",
            details: ["runId": runID, "success": true]
          )
        }
        return
      }
      SnapshotRefreshLogStore.record(
        event: "cloud_upload_started",
        details: ["runId": runID]
      )
      DispatchQueue.global(qos: .utility).asyncAfter(
        deadline: .now() + cloudUploadWaitSeconds
      ) {
        completion.complete(success: true) {
          SnapshotRefreshLogStore.record(
            event: "cloud_upload_deferred",
            details: ["runId": runID, "reason": "timeout"]
          )
          SnapshotRefreshLogStore.record(
            event: "task_completed",
            details: ["runId": runID, "success": true]
          )
        }
      }
      SnapshotCloudSync.uploadLocalSnapshot(dateKey: dateKey) { uploaded in
        completion.complete(success: true) {
          SnapshotRefreshLogStore.record(
            event: "cloud_upload_completed",
            details: ["runId": runID, "uploaded": uploaded]
          )
          SnapshotRefreshLogStore.record(
            event: "task_completed",
            details: ["runId": runID, "success": true]
          )
        }
      }
    }
  }

  private static func captureSnapshot(runID: String) -> String? {
    let startedAt = Date()
    guard isRecordingEnabled else {
      SnapshotRefreshLogStore.record(
        event: "capture_skipped",
        details: ["runId": runID, "reason": "recording_disabled"]
      )
      return nil
    }

    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      SnapshotRefreshLogStore.record(
        event: "capture_skipped",
        details: ["runId": runID, "reason": "music_not_authorized"]
      )
      return nil
    }

    let rules = exclusionRules
    let items = filteredLibraryItems(using: rules)

    let now = Date()
    let tracks = compactTrackSnapshots(from: items)
    let totalPlayCount = items.reduce(0) { total, item in
      total + item.playCount
    }
    let totalSkipCount = items.reduce(0) { total, item in
      total + item.skipCount
    }
    let totalListeningSeconds = items.reduce(0) { total, item in
      total + Int(item.playbackDuration.rounded()) * item.playCount
    }

    let capturedDateKey = dateKey(for: now)
    let snapshot: [String: Any] = [
      "dateKey": capturedDateKey,
      "capturedAtMillis": Int(now.timeIntervalSince1970 * 1000),
      "source": "background",
      "trackCount": items.count,
      "totalPlayCount": totalPlayCount,
      "totalSkipCount": totalSkipCount,
      "totalListeningSeconds": totalListeningSeconds,
      "tracks": tracks,
      "filterSignature": rules.signature
    ]

    guard write(snapshot: snapshot) else {
      SnapshotRefreshLogStore.record(
        event: "snapshot_write_failed",
        details: [
          "runId": runID,
          "durationMillis": Int(Date().timeIntervalSince(startedAt) * 1000),
          "trackCount": items.count
        ]
      )
      return nil
    }
    SongBriefWidgetDataStore.updateAfterBackgroundCapture(snapshot: snapshot)
    SnapshotRefreshLogStore.record(
      event: "capture_succeeded",
      details: [
        "runId": runID,
        "dateKey": capturedDateKey,
        "durationMillis": Int(Date().timeIntervalSince(startedAt) * 1000),
        "trackCount": items.count,
        "storedTrackCounterCount": tracks.count
      ]
    )
    return capturedDateKey
  }

  static func diagnostics(completion: @escaping ([String: Any]) -> Void) {
    let availability = backgroundRefreshAvailability
    BGTaskScheduler.shared.getPendingTaskRequests { requests in
      let pending = requests.first(where: { $0.identifier == taskIdentifier })
      var payload = SnapshotRefreshLogStore.summary()
      payload["availability"] = availability
      payload["intervalHours"] = refreshIntervalHours
      payload["detailedLoggingEnabled"] = SnapshotRefreshLogStore.isEnabled
      if let next = pending?.earliestBeginDate {
        payload["nextEarliestBeginAtMillis"] = Int(next.timeIntervalSince1970 * 1000)
      }
      completion(payload)
    }
  }

  static func exportDiagnosticsLog() -> String {
    SnapshotRefreshLogStore.exportJSONLines()
  }

  static func localSnapshots() -> [[String: Any]] {
    SnapshotFileStore.readSnapshots()
  }

  static func filteredLibraryItems() -> [MPMediaItem] {
    filteredLibraryItems(using: exclusionRules)
  }

  static var activeFilterSignature: String {
    exclusionRules.signature
  }

  static var hasActiveExclusions: Bool {
    !exclusionRules.isEmpty
  }

  /// Replaces the given dateKeys in the stored history with already merged
  /// snapshots coming from cloud sync.
  static func mergeExternalSnapshots(_ incoming: [[String: Any]]) -> Bool {
    guard !incoming.isEmpty else {
      return false
    }

    var changed = false
    for snapshot in incoming {
      guard snapshot["dateKey"] as? String != nil else {
        continue
      }
      changed = SnapshotFileStore.write(snapshot: snapshot) || changed
    }
    return changed
  }

  private static func write(snapshot: [String: Any]) -> Bool {
    SnapshotFileStore.write(snapshot: snapshot)
  }

  private static var isRecordingEnabled: Bool {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: recordingEnabledPreferenceKey) == nil {
      return true
    }
    return defaults.bool(forKey: recordingEnabledPreferenceKey)
  }

  private static var backgroundRefreshAvailability: String {
    switch UIApplication.shared.backgroundRefreshStatus {
    case .available:
      return "available"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    @unknown default:
      return "unsupported"
    }
  }

  private static var exclusionRules: LibraryExclusionRules {
    let defaults = UserDefaults.standard
    return LibraryExclusionRules(
      excludedPlaylists: normalizedRules(
        defaults.stringArray(forKey: excludedPlaylistsPreferenceKey) ?? []
      ),
      excludedGenres: normalizedRules(
        defaults.stringArray(forKey: excludedGenresPreferenceKey) ?? []
      ),
      excludedKeywords: normalizedRules(
        defaults.stringArray(forKey: excludedKeywordsPreferenceKey) ?? []
      )
    )
  }

  private static func filteredLibraryItems(
    using rules: LibraryExclusionRules
  ) -> [MPMediaItem] {
    let playlistNamesByItemID: [UInt64: [String]] = rules.needsPlaylistNames
      ? MusicLibraryBridge.playlistNamesByItemID()
      : [:]
    return (MPMediaQuery.songs().items ?? []).filter { item in
      !rules.excludes(
        item,
        playlistNames: playlistNamesByItemID[item.persistentID] ?? []
      )
    }
  }

  private static func normalizedRules(_ values: [String]) -> [String] {
    Array(Set(values.compactMap { value -> String? in
      let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      return normalized.isEmpty ? nil : normalized
    })).sorted()
  }

  private static func trackSnapshot(from item: MPMediaItem) -> [String: Any] {
    var track: [String: Any] = [
      "id": String(item.persistentID),
      "title": nonEmpty(item.title) ?? "Untitled",
      "artist": nonEmpty(item.artist) ?? "Unknown Artist",
      "albumTitle": nonEmpty(item.albumTitle) ?? "Unknown Album",
      "playCount": item.playCount,
      "skipCount": item.skipCount,
      "listeningSeconds": Int(item.playbackDuration.rounded()) * item.playCount
    ]

    if let albumArtist = nonEmpty(item.albumArtist) {
      track["albumArtist"] = albumArtist
    }
    if let genre = nonEmpty(item.genre) {
      track["genre"] = genre
    }
    if let releaseDate = item.value(forProperty: MPMediaItemPropertyReleaseDate) as? Date {
      track["releaseDateMillis"] = Int(releaseDate.timeIntervalSince1970 * 1000)
    }
    if let lastPlayedDate = item.lastPlayedDate {
      track["lastPlayedAtMillis"] = Int(lastPlayedDate.timeIntervalSince1970 * 1000)
    }

    return track
  }

  private static func compactTrackSnapshots(from items: [MPMediaItem]) -> [[String: Any]] {
    var selected: [UInt64: MPMediaItem] = [:]

    func add(_ candidates: [MPMediaItem], limit: Int) {
      var added = 0
      for item in candidates {
        selected[item.persistentID] = selected[item.persistentID] ?? item
        added += 1
        if added >= limit || selected.count >= maxSnapshotTracks {
          return
        }
      }
    }

    add(
      items.sorted {
        if $0.playCount != $1.playCount {
          return $0.playCount > $1.playCount
        }
        return ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending
      },
      limit: 260
    )
    add(
      items.sorted {
        let lhs = $0.lastPlayedDate ?? Date.distantPast
        let rhs = $1.lastPlayedDate ?? Date.distantPast
        if lhs != rhs {
          return lhs > rhs
        }
        return ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending
      },
      limit: 160
    )
    add(
      items.sorted {
        if $0.skipCount != $1.skipCount {
          return $0.skipCount > $1.skipCount
        }
        return ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending
      },
      limit: 80
    )
    if selected.count < maxSnapshotTracks {
      add(
        items.sorted {
          ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending
        },
        limit: maxSnapshotTracks
      )
    }

    return selected.values
      .sorted { $0.persistentID < $1.persistentID }
      .map(trackSnapshot)
  }

  private static func dateKey(for date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private struct LibraryExclusionRules {
    let excludedPlaylists: [String]
    let excludedGenres: [String]
    let excludedKeywords: [String]

    var isEmpty: Bool {
      excludedPlaylists.isEmpty && excludedGenres.isEmpty && excludedKeywords.isEmpty
    }

    var needsPlaylistNames: Bool {
      !excludedPlaylists.isEmpty || !excludedKeywords.isEmpty
    }

    var signature: String {
      let canonical = [
        "p:\(excludedPlaylists.joined(separator: "\u{001f}"))",
        "g:\(excludedGenres.joined(separator: "\u{001f}"))",
        "k:\(excludedKeywords.joined(separator: "\u{001f}"))",
      ].joined(separator: "\u{001e}")
      var hash: UInt32 = 0x811c9dc5
      for codeUnit in canonical.utf16 {
        hash ^= UInt32(codeUnit)
        hash = hash &* 0x01000193
      }
      return String(format: "%08x", hash)
    }

    func excludes(_ item: MPMediaItem, playlistNames: [String]) -> Bool {
      if !excludedPlaylists.isEmpty {
        let playlistKeys = Set(playlistNames.map {
          $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        if excludedPlaylists.contains(where: { playlistKeys.contains($0) }) {
          return true
        }
      }

      if let genre = SongBriefSnapshotRefresh.nonEmpty(item.genre)?.lowercased(),
         excludedGenres.contains(genre) {
        return true
      }

      guard !excludedKeywords.isEmpty else {
        return false
      }
      let searchValues: [String?] = [
        item.title,
        item.artist,
        item.albumTitle,
        item.albumArtist,
        item.genre,
      ] + playlistNames.map(Optional.some)
      let searchText = searchValues
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        .lowercased()
      return excludedKeywords.contains { searchText.contains($0) }
    }
  }
}

enum SnapshotFileStore {
  private static let snapshotFileNamePattern =
    #"^\d{4}-\d{2}-\d{2}\.json$"#
  private static let snapshotIndexFileName = "_snapshot_index_v1.json"
  private static let snapshotIndexVersion = 1
  private static let operationLock = NSRecursiveLock()

  static func readSnapshots() -> [[String: Any]] {
    operationLock.lock()
    defer { operationLock.unlock() }
    guard let directory = snapshotsDirectory(create: false) else {
      return []
    }
    return readSnapshots(in: directory)
  }

  static func readSnapshotsForFlutter(detailedLimit: Int) -> [[String: Any]] {
    operationLock.lock()
    defer { operationLock.unlock() }
    guard let directory = snapshotsDirectory(create: false) else {
      return []
    }
    let snapshots = readSnapshots(in: directory)
    let summaryCount = max(0, snapshots.count - max(0, detailedLimit))
    return snapshots.enumerated().map { index, snapshot in
      index < summaryCount ? summarySnapshot(snapshot) : snapshot
    }
  }

  static func write(snapshot: [String: Any]) -> Bool {
    operationLock.lock()
    defer { operationLock.unlock() }
    guard
      let dateKey = snapshot["dateKey"] as? String,
      isValidDateKey(dateKey),
      let directory = snapshotsDirectory(create: true)
    else {
      return false
    }

    let incoming = SnapshotMerge.normalized(snapshot)
    let url = directory.appendingPathComponent("\(dateKey).json")
    let normalized: [String: Any]
    if let existing = readSnapshot(from: url) {
      normalized = SnapshotMerge.merge(
        existing,
        incoming,
        preferredFilterSignature: SongBriefSnapshotRefresh.activeFilterSignature
      )
    } else {
      normalized = incoming
    }
    guard
      JSONSerialization.isValidJSONObject(normalized),
      let data = try? JSONSerialization.data(withJSONObject: normalized)
    else {
      return false
    }

    do {
      try data.write(to: url, options: [.atomic])
      updateIndex(afterWriting: normalized, in: directory)
      return true
    } catch {
      return false
    }
  }

  static func deleteSnapshots(olderThan cutoffDateKey: String?) -> Bool {
    operationLock.lock()
    defer { operationLock.unlock() }
    guard let directory = snapshotsDirectory(create: false) else {
      return true
    }
    do {
      let files = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      )
      for url in files where isSnapshotFile(url) {
        let dateKey = url.deletingPathExtension().lastPathComponent
        if cutoffDateKey.map({ dateKey < $0 }) ?? true {
          try FileManager.default.removeItem(at: url)
        }
      }
      return rebuildIndex(in: directory)
    } catch {
      _ = rebuildIndex(in: directory)
      return false
    }
  }

  private static func readSnapshot(from url: URL) -> [String: Any]? {
    guard isSnapshotFile(url),
          let data = try? Data(contentsOf: url),
          let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return SnapshotMerge.normalized(decoded)
  }

  private static func snapshotsDirectory(create: Bool) -> URL? {
    guard let support = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      return nil
    }
    let directory = support
      .appendingPathComponent("SongBrief", isDirectory: true)
      .appendingPathComponent("Snapshots", isDirectory: true)
    if create {
      do {
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true
        )
      } catch {
        return nil
      }
    }
    return directory
  }

  private static func updateIndex(afterWriting snapshot: [String: Any], in directory: URL) {
    guard let dateKey = snapshot["dateKey"] as? String else {
      return
    }
    var snapshots = readIndexSnapshots(in: directory) ?? readSnapshots(in: directory)
    snapshots.removeAll { ($0["dateKey"] as? String) == dateKey }
    snapshots.append(summarySnapshot(snapshot))
    snapshots.sort {
      ($0["dateKey"] as? String ?? "") < ($1["dateKey"] as? String ?? "")
    }

    _ = writeIndex(snapshots: snapshots, in: directory)
  }

  private static func rebuildIndex(in directory: URL) -> Bool {
    let snapshots = readSnapshots(in: directory)
    if snapshots.isEmpty {
      let indexURL = directory.appendingPathComponent(snapshotIndexFileName)
      guard FileManager.default.fileExists(atPath: indexURL.path) else {
        return true
      }
      do {
        try FileManager.default.removeItem(at: indexURL)
        return true
      } catch {
        return false
      }
    }
    return writeIndex(snapshots: snapshots, in: directory)
  }

  private static func readSnapshots(in directory: URL) -> [[String: Any]] {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    ) else {
      return []
    }
    return files.compactMap { readSnapshot(from: $0) }.sorted { lhs, rhs in
      (lhs["dateKey"] as? String ?? "") < (rhs["dateKey"] as? String ?? "")
    }
  }

  private static func writeIndex(
    snapshots: [[String: Any]],
    in directory: URL
  ) -> Bool {
    let payload: [String: Any] = [
      "version": snapshotIndexVersion,
      "updatedAtMillis": Int(Date().timeIntervalSince1970 * 1000),
      "files": snapshotFileStates(in: directory),
      "snapshots": snapshots.map(summarySnapshot),
    ]
    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return false
    }
    let url = directory.appendingPathComponent(snapshotIndexFileName)
    do {
      try data.write(to: url, options: [.atomic])
      return true
    } catch {
      return false
    }
  }

  private static func readIndexSnapshots(in directory: URL) -> [[String: Any]]? {
    let url = directory.appendingPathComponent(snapshotIndexFileName)
    guard let data = try? Data(contentsOf: url),
          let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let snapshots = decoded["snapshots"] as? [[String: Any]] else {
      return nil
    }
    return snapshots
  }

  private static func snapshotFileStates(in directory: URL) -> [[String: Any]] {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey]
    ) else {
      return []
    }
    return files.compactMap { url -> [String: Any]? in
      guard isSnapshotFile(url) else {
        return nil
      }
      let dateKey = url.deletingPathExtension().lastPathComponent
      let modified = (try? url.resourceValues(
        forKeys: [.contentModificationDateKey]
      ).contentModificationDate) ?? Date(timeIntervalSince1970: 0)
      return [
        "dateKey": dateKey,
        "modifiedMillis": Int(modified.timeIntervalSince1970 * 1000),
      ]
    }.sorted {
      ($0["dateKey"] as? String ?? "") < ($1["dateKey"] as? String ?? "")
    }
  }

  private static func summarySnapshot(_ snapshot: [String: Any]) -> [String: Any] {
    var summary = snapshot
    summary.removeValue(forKey: "tracks")
    return summary
  }

  private static func isSnapshotFile(_ url: URL) -> Bool {
    url.lastPathComponent.range(
      of: snapshotFileNamePattern,
      options: .regularExpression
    ) != nil
  }

  private static func isValidDateKey(_ value: String) -> Bool {
    value.range(
      of: #"^\d{4}-\d{2}-\d{2}$"#,
      options: .regularExpression
    ) != nil
  }
}

/// Stores privacy-safe diagnostics for the native background refresh path.
/// Flutter may not be running when a refresh task launches, so this log must
/// live entirely on the iOS side.
enum SnapshotRefreshLogStore {
  private static let detailedLoggingEnabledPreferenceKey =
    "flutter.songbrief_snapshot_detailed_logging_enabled_v1"
  private static let lastEventPreferenceKey =
    "songbrief_snapshot_refresh_last_event_v1"
  private static let lastEventAtPreferenceKey =
    "songbrief_snapshot_refresh_last_event_at_v1"
  private static let lastTaskStartedAtPreferenceKey =
    "songbrief_snapshot_refresh_last_task_started_at_v1"
  private static let lastSuccessfulCaptureAtPreferenceKey =
    "songbrief_snapshot_refresh_last_success_at_v1"
  private static let recentEventsPreferenceKey =
    "songbrief_snapshot_refresh_recent_events_v1"
  private static let logFilePrefix = "snapshot-refresh-"
  private static let logFileSuffix = ".jsonl"
  private static let operationLock = NSRecursiveLock()
  private static let maximumFileBytes = 512 * 1024
  private static let maximumTotalBytes = 2 * 1024 * 1024
  private static let maximumRecentEvents = 12
  private static let allowedDetailKeys: Set<String> = [
    "dateKey",
    "durationMillis",
    "errorCode",
    "errorDomain",
    "intervalHours",
    "nextEarliestBeginAtMillis",
    "previousEarliestBeginAtMillis",
    "reason",
    "runId",
    "storedTrackCounterCount",
    "success",
    "trackCount",
    "uploaded",
  ]

  static let retentionDays = 14

  static var isEnabled: Bool {
    UserDefaults.standard.bool(forKey: detailedLoggingEnabledPreferenceKey)
  }

  static func record(event: String, details: [String: Any] = [:]) {
    operationLock.lock()
    defer { operationLock.unlock() }

    let now = Date()
    let defaults = UserDefaults.standard
    defaults.set(event, forKey: lastEventPreferenceKey)
    defaults.set(
      Int(now.timeIntervalSince1970 * 1000),
      forKey: lastEventAtPreferenceKey
    )
    if event == "task_started" {
      defaults.set(
        Int(now.timeIntervalSince1970 * 1000),
        forKey: lastTaskStartedAtPreferenceKey
      )
    } else if event == "capture_succeeded" {
      defaults.set(
        Int(now.timeIntervalSince1970 * 1000),
        forKey: lastSuccessfulCaptureAtPreferenceKey
      )
    }
    appendRecentEvent(
      event,
      details: details,
      at: now,
      defaults: defaults
    )

    if let existingDirectory = logsDirectory(create: false) {
      pruneLogs(in: existingDirectory, now: now)
    }
    guard isEnabled, let directory = logsDirectory(create: true) else {
      return
    }

    var payload: [String: Any] = [
      "formatVersion": 1,
      "timestamp": isoTimestamp(now),
      "timestampMillis": Int(now.timeIntervalSince1970 * 1000),
      "event": event,
    ]
    let safeDetails = sanitized(details)
    if !safeDetails.isEmpty {
      payload["details"] = safeDetails
    }
    guard JSONSerialization.isValidJSONObject(payload),
          var data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
          ) else {
      return
    }
    data.append(0x0A)

    let logURL = directory.appendingPathComponent(
      "\(logFilePrefix)\(dateKey(now))\(logFileSuffix)"
    )
    append(data, to: logURL)
    trimFileIfNeeded(logURL)
    pruneLogs(in: directory, now: now)
  }

  static func summary() -> [String: Any] {
    operationLock.lock()
    defer { operationLock.unlock() }

    let defaults = UserDefaults.standard
    var payload: [String: Any] = [
      "retentionDays": retentionDays,
      "logFileCount": 0,
      "logBytes": 0,
    ]
    if let lastEvent = defaults.string(forKey: lastEventPreferenceKey) {
      payload["lastEvent"] = lastEvent
    }
    let lastEventAt = defaults.object(forKey: lastEventAtPreferenceKey) as? NSNumber
    if let lastEventAt {
      payload["lastEventAtMillis"] = lastEventAt.int64Value
    }
    let lastTaskStarted = defaults.object(
      forKey: lastTaskStartedAtPreferenceKey
    ) as? NSNumber
    if let lastTaskStarted {
      payload["lastTaskStartedAtMillis"] = lastTaskStarted.int64Value
    }
    let lastSuccess = defaults.object(
      forKey: lastSuccessfulCaptureAtPreferenceKey
    ) as? NSNumber
    if let lastSuccess {
      payload["lastSuccessfulCaptureAtMillis"] = lastSuccess.int64Value
    }
    payload["recentEvents"] = recentEvents(defaults: defaults)

    guard let directory = logsDirectory(create: false) else {
      return payload
    }
    pruneLogs(in: directory, now: Date())
    let files = logFiles(in: directory)
    payload["logFileCount"] = files.count
    payload["logBytes"] = files.reduce(0) { total, url in
      total + fileSize(url)
    }
    return payload
  }

  static func exportJSONLines() -> String {
    operationLock.lock()
    defer { operationLock.unlock() }

    guard let directory = logsDirectory(create: false) else {
      return ""
    }
    pruneLogs(in: directory, now: Date())
    return logFiles(in: directory).compactMap { url in
      guard let data = try? Data(contentsOf: url) else {
        return nil
      }
      return String(data: data, encoding: .utf8)
    }.joined()
  }

  private static func appendRecentEvent(
    _ event: String,
    details: [String: Any],
    at date: Date,
    defaults: UserDefaults
  ) {
    guard let displayEvent = recentEventName(event, details: details) else {
      return
    }
    var events = recentEvents(defaults: defaults)
    let entry: [String: Any] = [
      "event": displayEvent,
      "timestampMillis": Int(date.timeIntervalSince1970 * 1000),
    ]
    appendCoalesced(entry, to: &events)
    if events.count > maximumRecentEvents {
      events.removeFirst(events.count - maximumRecentEvents)
    }
    defaults.set(events, forKey: recentEventsPreferenceKey)
  }

  private static func recentEvents(
    defaults: UserDefaults
  ) -> [[String: Any]] {
    guard let rawEvents = defaults.array(
      forKey: recentEventsPreferenceKey
    ) as? [[String: Any]] else {
      return []
    }
    return normalizedRecentEvents(rawEvents)
  }

  static func normalizedRecentEvents(
    _ rawEvents: [[String: Any]]
  ) -> [[String: Any]] {
    var normalized: [[String: Any]] = []
    for entry in rawEvents {
      guard let event = entry["event"] as? String,
            !event.isEmpty,
            let timestamp = entry["timestampMillis"] as? NSNumber else {
        continue
      }
      var displayEvent = recentEventName(event, details: entry)
      if event == "task_expired",
         let lastRecord = normalized.last(where: {
           ($0["event"] as? String) == "record_updated"
         }),
         let lastRecordAt = lastRecord["timestampMillis"] as? NSNumber,
         timestamp.int64Value >= lastRecordAt.int64Value,
         timestamp.int64Value - lastRecordAt.int64Value <= 5 * 60 * 1000 {
        displayEvent = "icloud_sync_deferred"
      }
      guard let displayEvent else {
        continue
      }
      appendCoalesced([
        "event": displayEvent,
        "timestampMillis": timestamp.int64Value,
      ], to: &normalized)
    }
    return Array(normalized.suffix(maximumRecentEvents))
  }

  static func recentEventName(
    _ event: String,
    details: [String: Any] = [:]
  ) -> String? {
    switch event {
    case "schedule_kept", "schedule_replaced", "schedule_submitted":
      return "schedule_queued"
    case "schedule_failed":
      return "schedule_failed"
    case "capture_succeeded":
      return "record_updated"
    case "snapshot_write_failed":
      return "record_failed"
    case "capture_skipped":
      return "record_skipped"
    case "task_expired":
      return "background_update_interrupted"
    case "cloud_upload_deferred":
      return "icloud_sync_deferred"
    case "cloud_upload_completed":
      return (details["uploaded"] as? Bool) == true
        ? "icloud_sync_completed"
        : "icloud_sync_deferred"
    case "schedule_queued", "record_updated", "record_failed",
         "record_skipped", "background_update_interrupted",
         "icloud_sync_completed", "icloud_sync_deferred":
      return event
    default:
      return nil
    }
  }

  private static func appendCoalesced(
    _ entry: [String: Any],
    to events: inout [[String: Any]]
  ) {
    if let last = events.last,
       last["event"] as? String == entry["event"] as? String,
       let lastAt = last["timestampMillis"] as? NSNumber,
       let entryAt = entry["timestampMillis"] as? NSNumber,
       abs(entryAt.int64Value - lastAt.int64Value) <= 60 * 1000 {
      events[events.count - 1] = entry
      return
    }
    events.append(entry)
  }

  private static func sanitized(_ details: [String: Any]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in details where allowedDetailKeys.contains(key) {
      switch value {
      case let string as String:
        result[key] = String(string.prefix(160))
      case let number as NSNumber:
        result[key] = number
      case is NSNull:
        result[key] = NSNull()
      default:
        continue
      }
    }
    return result
  }

  private static func append(_ data: Data, to url: URL) {
    if !FileManager.default.fileExists(atPath: url.path) {
      do {
        try data.write(to: url, options: [.atomic])
        protect(url)
      } catch {
        return
      }
      return
    }
    guard let handle = try? FileHandle(forWritingTo: url) else {
      return
    }
    handle.seekToEndOfFile()
    handle.write(data)
    handle.closeFile()
  }

  private static func trimFileIfNeeded(_ url: URL) {
    guard fileSize(url) > maximumFileBytes,
          let data = try? Data(contentsOf: url),
          let contents = String(data: data, encoding: .utf8) else {
      return
    }
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
    var kept: [Substring] = []
    var keptBytes = 0
    for line in lines.reversed() {
      let lineBytes = line.utf8.count + 1
      if keptBytes + lineBytes > maximumFileBytes {
        break
      }
      kept.append(line)
      keptBytes += lineBytes
    }
    let trimmed = kept.reversed().map(String.init).joined(separator: "\n") + "\n"
    guard let trimmedData = trimmed.data(using: .utf8) else {
      return
    }
    try? trimmedData.write(to: url, options: [.atomic])
    protect(url)
  }

  private static func pruneLogs(in directory: URL, now: Date) {
    let calendar = Calendar.autoupdatingCurrent
    let oldestDate = calendar.date(
      byAdding: .day,
      value: -(retentionDays - 1),
      to: now
    ) ?? now
    let oldestKey = dateKey(oldestDate)
    var files = logFiles(in: directory)
    for url in files where fileDateKey(url) < oldestKey {
      try? FileManager.default.removeItem(at: url)
    }

    files = logFiles(in: directory)
    var totalBytes = files.reduce(0) { $0 + fileSize($1) }
    for url in files where totalBytes > maximumTotalBytes {
      let bytes = fileSize(url)
      do {
        try FileManager.default.removeItem(at: url)
        totalBytes = max(0, totalBytes - bytes)
      } catch {
        continue
      }
    }
  }

  private static func logsDirectory(create: Bool) -> URL? {
    guard let support = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      return nil
    }
    let directory = support
      .appendingPathComponent("SongBrief", isDirectory: true)
      .appendingPathComponent("Logs", isDirectory: true)
    if create {
      do {
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true
        )
        protect(directory)
      } catch {
        return nil
      }
    }
    return directory
  }

  private static func logFiles(in directory: URL) -> [URL] {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.fileSizeKey]
    ) else {
      return []
    }
    return files.filter { url in
      url.lastPathComponent.range(
        of: #"^snapshot-refresh-\d{4}-\d{2}-\d{2}\.jsonl$"#,
        options: .regularExpression
      ) != nil
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  private static func fileDateKey(_ url: URL) -> String {
    let name = url.lastPathComponent
    return String(
      name.dropFirst(logFilePrefix.count).dropLast(logFileSuffix.count)
    )
  }

  private static func fileSize(_ url: URL) -> Int {
    (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
  }

  private static func protect(_ url: URL) {
    try? FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: url.path
    )
    var protectedURL = url
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    try? protectedURL.setResourceValues(resourceValues)
  }

  private static func dateKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private static func isoTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

/// Guarantees `setTaskCompleted` is called exactly once even when the
/// expiration handler races the cloud upload completion.
private final class SnapshotRefreshCompletion {
  private let lock = NSLock()
  private var completed = false
  private var capturedLocally = false
  private let task: BGAppRefreshTask

  init(_ task: BGAppRefreshTask) {
    self.task = task
  }

  var isCompleted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return completed
  }

  @discardableResult
  func markLocalCaptureSucceeded() -> Bool {
    lock.lock()
    guard !completed else {
      lock.unlock()
      return false
    }
    capturedLocally = true
    lock.unlock()
    return true
  }

  @discardableResult
  func completeForExpiration(
    beforeTaskCompletion: (Bool) -> Void
  ) -> Bool {
    lock.lock()
    guard !completed else {
      lock.unlock()
      return false
    }
    completed = true
    let success = capturedLocally
    lock.unlock()
    beforeTaskCompletion(success)
    task.setTaskCompleted(success: success)
    return true
  }

  @discardableResult
  func complete(
    success: Bool,
    beforeTaskCompletion: () -> Void = {}
  ) -> Bool {
    lock.lock()
    let alreadyCompleted = completed
    completed = true
    lock.unlock()
    if alreadyCompleted {
      return false
    }
    beforeTaskCompletion()
    task.setTaskCompleted(success: success)
    return true
  }
}
