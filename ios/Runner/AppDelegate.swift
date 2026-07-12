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
  private static let excludedPlaylistsPreferenceKey =
    "flutter.songbrief_excluded_playlists_v1"
  private static let excludedGenresPreferenceKey =
    "flutter.songbrief_excluded_genres_v1"
  private static let excludedKeywordsPreferenceKey =
    "flutter.songbrief_excluded_keywords_v1"
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
      return nil
    }
    SongBriefWidgetDataStore.updateAfterBackgroundCapture(snapshot: snapshot)
    return capturedDateKey
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
