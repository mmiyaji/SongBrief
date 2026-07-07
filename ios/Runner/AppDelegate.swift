import BackgroundTasks
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
  private static let maxSnapshotTracks = 500

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

  static func schedule() {
    guard isRecordingEnabled else {
      return
    }

    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // iOS may reject scheduling when Background App Refresh is disabled or
      // the system decides not to grant a slot. Foreground scans remain the
      // source of truth, so this is intentionally best effort.
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    schedule()

    let completion = SnapshotRefreshCompletion(task)
    task.expirationHandler = {
      completion.complete(success: false)
    }

    DispatchQueue.global(qos: .utility).async {
      guard !completion.isCompleted, let dateKey = captureSnapshot() else {
        completion.complete(success: false)
        return
      }

      // The local capture already succeeded; the cloud upload is best effort
      // and must not fail the refresh task.
      guard SnapshotCloudSync.isEnabled, !completion.isCompleted else {
        completion.complete(success: true)
        return
      }
      SnapshotCloudSync.uploadLocalSnapshot(dateKey: dateKey) { _ in
        completion.complete(success: true)
      }
    }
  }

  private static func captureSnapshot() -> String? {
    guard isRecordingEnabled else {
      return nil
    }

    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      return nil
    }

    let items = MPMediaQuery.songs().items ?? []
    guard !items.isEmpty else {
      return nil
    }

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
      "tracks": tracks
    ]

    return write(snapshot: snapshot) ? capturedDateKey : nil
  }

  static func localSnapshots() -> [[String: Any]] {
    SnapshotFileStore.readSnapshots()
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
}

enum SnapshotFileStore {
  private static let snapshotFileNamePattern =
    #"^\d{4}-\d{2}-\d{2}\.json$"#

  static func readSnapshots() -> [[String: Any]] {
    guard let directory = snapshotsDirectory(create: false),
          let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
          ) else {
      return []
    }

    let snapshots = files.compactMap { readSnapshot(from: $0) }.sorted { lhs, rhs in
      (lhs["dateKey"] as? String ?? "") < (rhs["dateKey"] as? String ?? "")
    }
    return snapshots
  }

  static func write(snapshot: [String: Any]) -> Bool {
    guard
      let dateKey = snapshot["dateKey"] as? String,
      isValidDateKey(dateKey),
      let directory = snapshotsDirectory(create: true)
    else {
      return false
    }

    let normalized = SnapshotMerge.normalized(snapshot)
    guard
      JSONSerialization.isValidJSONObject(normalized),
      let data = try? JSONSerialization.data(withJSONObject: normalized)
    else {
      return false
    }

    let url = directory.appendingPathComponent("\(dateKey).json")
    do {
      try data.write(to: url, options: [.atomic])
      return true
    } catch {
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

/// Guarantees `setTaskCompleted` is called exactly once even when the
/// expiration handler races the cloud upload completion.
private final class SnapshotRefreshCompletion {
  private let lock = NSLock()
  private var completed = false
  private let task: BGAppRefreshTask

  init(_ task: BGAppRefreshTask) {
    self.task = task
  }

  var isCompleted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return completed
  }

  func complete(success: Bool) {
    lock.lock()
    let alreadyCompleted = completed
    completed = true
    lock.unlock()
    if alreadyCompleted {
      return
    }
    task.setTaskCompleted(success: success)
  }
}
