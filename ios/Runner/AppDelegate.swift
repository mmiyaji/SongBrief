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
  private static let preferencesKey = "flutter.songbrief_daily_snapshots_v1"
  private static let maxSnapshots = 180

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

    var expired = false
    task.expirationHandler = {
      expired = true
    }

    DispatchQueue.global(qos: .utility).async {
      let success = !expired && captureSnapshot()
      DispatchQueue.main.async {
        task.setTaskCompleted(success: success)
      }
    }
  }

  private static func captureSnapshot() -> Bool {
    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      return false
    }

    let items = MPMediaQuery.songs().items ?? []
    guard !items.isEmpty else {
      return false
    }

    let now = Date()
    let tracks = items.map(trackSnapshot)
    let totalPlayCount = items.reduce(0) { total, item in
      total + item.playCount
    }
    let totalSkipCount = items.reduce(0) { total, item in
      total + item.skipCount
    }
    let totalListeningSeconds = items.reduce(0) { total, item in
      total + Int(item.playbackDuration.rounded()) * item.playCount
    }

    let snapshot: [String: Any] = [
      "dateKey": dateKey(for: now),
      "capturedAtMillis": Int(now.timeIntervalSince1970 * 1000),
      "source": "background",
      "trackCount": items.count,
      "totalPlayCount": totalPlayCount,
      "totalSkipCount": totalSkipCount,
      "totalListeningSeconds": totalListeningSeconds,
      "tracks": tracks
    ]

    return write(snapshot: snapshot)
  }

  private static func write(snapshot: [String: Any]) -> Bool {
    guard let dateKey = snapshot["dateKey"] as? String else {
      return false
    }

    let defaults = UserDefaults.standard
    let existing = defaults.string(forKey: preferencesKey)
    var snapshots = readSnapshots(from: existing)
    snapshots.removeAll { item in
      item["dateKey"] as? String == dateKey
    }
    snapshots.append(snapshot)
    snapshots.sort { lhs, rhs in
      (lhs["dateKey"] as? String ?? "") < (rhs["dateKey"] as? String ?? "")
    }
    if snapshots.count > maxSnapshots {
      snapshots = Array(snapshots.suffix(maxSnapshots))
    }

    let payload: [String: Any] = [
      "version": 1,
      "updatedAtMillis": Int(Date().timeIntervalSince1970 * 1000),
      "snapshots": snapshots
    ]

    guard
      JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let json = String(data: data, encoding: .utf8)
    else {
      return false
    }

    defaults.set(json, forKey: preferencesKey)
    return true
  }

  private static func readSnapshots(from json: String?) -> [[String: Any]] {
    guard
      let json,
      let data = json.data(using: .utf8),
      let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let snapshots = decoded["snapshots"] as? [[String: Any]]
    else {
      return []
    }
    return snapshots
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
    if let lastPlayedDate = item.lastPlayedDate {
      track["lastPlayedAtMillis"] = Int(lastPlayedDate.timeIntervalSince1970 * 1000)
    }

    return track
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
