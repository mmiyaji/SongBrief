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
  private static let preferencesKey = "flutter.songbrief_daily_snapshots_v2"
  private static let maxSnapshots = 180
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

    let expiration = SnapshotRefreshExpiration()
    task.expirationHandler = {
      expiration.expire()
    }

    DispatchQueue.global(qos: .utility).async {
      let success = !expiration.isExpired && captureSnapshot()
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

private final class SnapshotRefreshExpiration {
  private let lock = NSLock()
  private var expired = false

  var isExpired: Bool {
    lock.lock()
    defer { lock.unlock() }
    return expired
  }

  func expire() {
    lock.lock()
    expired = true
    lock.unlock()
  }
}
