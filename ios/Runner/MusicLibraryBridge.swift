import Flutter
import MediaPlayer
import MusicKit
import UIKit

final class MusicLibraryBridge: NSObject, FlutterStreamHandler {
  private let player = MPMusicPlayerController.systemMusicPlayer
  private let snapshotStoreQueue = DispatchQueue(
    label: "app.songbrief.snapshot-store-channel",
    qos: .utility
  )
  private var eventSink: FlutterEventSink?
  private var recentlyPlayedArtwork: [String: Artwork] = [:]
  private static let playbackQueueWindowSize = 200

  private override init() {
    super.init()
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let bridge = MusicLibraryBridge()
    let channel = FlutterMethodChannel(
      name: "app.songbrief/music_library",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: "app.songbrief/music_playback",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(bridge)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationStatus":
      result(Self.authorizationStatusString(MPMediaLibrary.authorizationStatus()))
    case "requestAuthorization":
      MPMediaLibrary.requestAuthorization { status in
        Task { @MainActor in
          // Permission prompts belong only to this explicit user action.
          if status == .authorized, MusicAuthorization.currentStatus == .notDetermined {
            _ = await MusicAuthorization.request()
          }
          result(Self.authorizationStatusString(status))
        }
      }
    case "openAppSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    case "fetchTracks":
      fetchTracks(result: result)
    case "fetchRecentlyPlayedTracks":
      fetchRecentlyPlayedTracks(result: result)
    case "currentPlayback":
      result(playbackMap())
    case "fetchArtwork":
      fetchArtwork(call, result: result)
    case "fetchLyrics":
      fetchLyrics(call, result: result)
    case "playTrack":
      playTrack(call, result: result)
    case "play":
      MPMusicPlayerController.systemMusicPlayer.play()
      result(nil)
    case "pause":
      MPMusicPlayerController.systemMusicPlayer.pause()
      result(nil)
    case "skipToNext":
      MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
      result(nil)
    case "skipToPrevious":
      MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
      result(nil)
    case "scheduleSnapshotRefresh":
      let arguments = call.arguments as? [String: Any]
      let replaceExisting = arguments?["replaceExisting"] as? Bool ?? false
      SongBriefSnapshotRefresh.schedule(replaceExisting: replaceExisting)
      result(nil)
    case "snapshotRefreshDiagnostics":
      SongBriefSnapshotRefresh.diagnostics { payload in
        DispatchQueue.main.async {
          result(payload)
        }
      }
    case "exportSnapshotRefreshLogs":
      runSnapshotStoreOperation(result: result) {
        SongBriefSnapshotRefresh.exportDiagnosticsLog()
      }
    case "syncSnapshotHistory":
      SnapshotCloudSync.sync { payload in
        result(payload)
      }
    case "updateHomeWidget":
      let arguments = call.arguments as? [String: Any]
      let summary = arguments?["summary"] as? [String: Any]
      SongBriefWidgetDataStore.update(summary: summary)
      result(nil)
    case "deleteCloudSnapshots":
      let arguments = call.arguments as? [String: Any]
      let cutoffDateKey = arguments?["olderThanDateKey"] as? String
      SnapshotCloudSync.deleteCloudSnapshots(olderThan: cutoffDateKey) { payload in
        result(payload)
      }
    case "loadLocalSnapshotHistory":
      let arguments = call.arguments as? [String: Any]
      let requestedLimit = (arguments?["detailedLimit"] as? NSNumber)?.intValue ?? 400
      let detailedLimit = max(0, min(requestedLimit, 500))
      runSnapshotStoreOperation(result: result) {
        SnapshotFileStore.readSnapshotsForFlutter(detailedLimit: detailedLimit)
      }
    case "writeLocalSnapshot":
      guard let arguments = call.arguments as? [String: Any],
            let snapshot = arguments["snapshot"] as? [String: Any] else {
        result(false)
        return
      }
      runSnapshotStoreOperation(result: result) {
        SnapshotFileStore.write(snapshot: snapshot)
      }
    case "deleteLocalSnapshots":
      let arguments = call.arguments as? [String: Any]
      let cutoffDateKey = arguments?["olderThanDateKey"] as? String
      runSnapshotStoreOperation(result: result) {
        SnapshotFileStore.deleteSnapshots(olderThan: cutoffDateKey)
      }
    case "clearLocalSnapshotHistory":
      runSnapshotStoreOperation(result: result) {
        SnapshotFileStore.deleteSnapshots(olderThan: nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func runSnapshotStoreOperation(
    result: @escaping FlutterResult,
    operation: @escaping () -> Any?
  ) {
    snapshotStoreQueue.async {
      let payload = operation()
      DispatchQueue.main.async {
        result(payload)
      }
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    player.beginGeneratingPlaybackNotifications()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(playbackDidChange),
      name: .MPMusicPlayerControllerNowPlayingItemDidChange,
      object: player
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(playbackDidChange),
      name: .MPMusicPlayerControllerPlaybackStateDidChange,
      object: player
    )
    events(playbackMap())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self,
      name: .MPMusicPlayerControllerNowPlayingItemDidChange,
      object: player
    )
    NotificationCenter.default.removeObserver(
      self,
      name: .MPMusicPlayerControllerPlaybackStateDidChange,
      object: player
    )
    player.endGeneratingPlaybackNotifications()
    eventSink = nil
    return nil
  }

  @objc private func playbackDidChange() {
    eventSink?(playbackMap())
  }

  private func playbackMap() -> [String: Any] {
    var playback: [String: Any] = [
      "isPlaying": player.playbackState == .playing
    ]

    if let item = player.nowPlayingItem {
      if item.persistentID != 0 {
        playback["trackId"] = String(item.persistentID)
      }
      // Songs streamed from Apple Music without being added to the library
      // are not in MPMediaQuery, so send enough to show them anyway.
      if let title = Self.nonEmpty(item.title) {
        playback["title"] = title
        playback["artist"] = Self.nonEmpty(item.artist) ?? "Unknown Artist"
        playback["albumTitle"] = Self.nonEmpty(item.albumTitle) ?? "Unknown Album"
        playback["durationSeconds"] = Int(item.playbackDuration.rounded())
      }
    }

    return playback
  }

  private func fetchTracks(result: @escaping FlutterResult) {
    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      result(FlutterError(
        code: "music_library_not_authorized",
        message: "Music library access has not been authorized.",
        details: nil
      ))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let items: [MPMediaItem]
      let playlistNamesByItemID: [UInt64: [String]]
      do {
        items = try Self.requireQueryResult(MPMediaQuery.songs().items)
        playlistNamesByItemID = try Self.playlistNamesByItemID()
      } catch {
        DispatchQueue.main.async {
          result(Self.libraryQueryError())
        }
        return
      }
      let tracks = items.map { item in
        Self.trackMap(
          from: item,
          playlistNames: playlistNamesByItemID[item.persistentID] ?? []
        )
      }

      DispatchQueue.main.async {
        result(tracks)
      }
    }
  }

  private func fetchRecentlyPlayedTracks(result: @escaping FlutterResult) {
    let supported: Bool
    if #available(iOS 16.0, *) {
      supported = true
    } else {
      supported = false
    }
    if let error = Self.recentlyPlayedAccessError(
      isSupported: supported,
      authorizationStatus: MusicAuthorization.currentStatus
    ) {
      DispatchQueue.main.async { result(error) }
      return
    }
    guard #available(iOS 16.0, *) else { return }

    Task { @MainActor in
      do {
        var tracks: [[String: Any]] = []
        var artwork: [String: Artwork] = [:]
        var seenIDs = Set<String>()
        // Bound the work while looking beyond only the first page. The API
        // returns recent resources, not a complete log of individual plays.
        for page in 0..<4 {
          var request = MusicRecentlyPlayedRequest<Song>()
          request.limit = 30
          request.offset = page * 30
          let response = try await request.response()
          for song in response.items {
            let id = "musickit:\(song.id.rawValue)"
            guard seenIDs.insert(id).inserted else { continue }
            tracks.append(Self.recentlyPlayedTrackMap(
              catalogID: song.id.rawValue,
              title: song.title,
              artist: song.artistName,
              albumTitle: song.albumTitle,
              duration: song.duration,
              genre: song.genreNames.first,
              lastPlayedDate: song.lastPlayedDate
            ))
            artwork[id] = song.artwork
          }
          if !response.items.hasNextBatch { break }
        }
        self.recentlyPlayedArtwork = artwork
        result(tracks)
      } catch {
        let nativeError = error as NSError
        result(FlutterError(
          code: "music_recently_played_unavailable",
          message: "Recently played Apple Music songs could not be read. Check your connection, Apple Music account, and MusicKit configuration.",
          details: ["domain": nativeError.domain, "code": nativeError.code]
        ))
      }
    }
  }

  static func recentlyPlayedAccessError(
    isSupported: Bool,
    authorizationStatus: MusicAuthorization.Status
  ) -> FlutterError? {
    guard isSupported else {
      return FlutterError(
        code: "music_recently_played_unsupported",
        message: "Recently played Apple Music songs require iOS 16 or later.",
        details: nil
      )
    }
    guard authorizationStatus == .authorized else {
      return FlutterError(
        code: "music_recently_played_not_authorized",
        message: "Apple Music access has not been authorized. Grant access from the app's authorization action or Settings.",
        details: nil
      )
    }
    return nil
  }

  // Keep transport mapping testable without a network request or a MusicKit
  // Song initializer. A missing last-played date must stay missing.
  static func recentlyPlayedTrackMap(
    catalogID: String,
    title: String,
    artist: String,
    albumTitle: String?,
    duration: TimeInterval?,
    genre: String?,
    lastPlayedDate: Date?
  ) -> [String: Any] {
    let seconds = duration.flatMap { $0.isFinite ? max(0, $0) : nil } ?? 0
    var track: [String: Any] = [
      "id": "musickit:\(catalogID)",
      "appleMusicStoreId": catalogID,
      "title": nonEmpty(title) ?? "Untitled",
      "artist": nonEmpty(artist) ?? "Unknown Artist",
      "albumTitle": nonEmpty(albumTitle) ?? "Unknown Album",
      "durationSeconds": Int(seconds.rounded()),
      "playCount": 0,
      "skipCount": 0,
      "isCloudItem": true
    ]
    if let genre = nonEmpty(genre) { track["genre"] = genre }
    if let lastPlayedDate {
      track["lastPlayedAtMillis"] = Int(lastPlayedDate.timeIntervalSince1970 * 1000)
    }
    return track
  }

  private func fetchArtwork(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if let arguments = call.arguments as? [String: Any],
       let id = arguments["id"] as? String, id.hasPrefix("musickit:") {
      let size = max(80, min(arguments["size"] as? Int ?? 640, 1200))
      guard let url = recentlyPlayedArtwork[id]?.url(width: size, height: size) else {
        result(nil)
        return
      }
      Task { @MainActor in
        do {
          let (data, response) = try await URLSession.shared.data(from: url)
          guard let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode), !data.isEmpty else {
            result(nil)
            return
          }
          // Flutter decodes the original image. Avoid decoding and re-encoding
          // cloud artwork on the main actor while switching player screens.
          result(FlutterStandardTypedData(bytes: data))
        } catch {
          result(nil)
        }
      }
      return
    }
    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      result(FlutterError(
        code: "music_library_not_authorized",
        message: "Music library access has not been authorized.",
        details: nil
      ))
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let id = Self.persistentID(from: arguments["id"])
    else {
      result(FlutterError(
        code: "invalid_track_id",
        message: "A valid track id is required.",
        details: nil
      ))
      return
    }

    let size = max(80, min(arguments["size"] as? Int ?? 640, 1200))
    // The player must be read on the main thread; its item covers songs that
    // are playing but not in the library.
    let nowPlaying = player.nowPlayingItem.flatMap { $0.persistentID == id ? $0 : nil }
    DispatchQueue.global(qos: .userInitiated).async {
      guard
        let item = Self.mediaItem(withPersistentID: id) ?? nowPlaying,
        let image = item.artwork?.image(at: CGSize(width: size, height: size)),
        let data = image.jpegData(compressionQuality: 0.88)
      else {
        DispatchQueue.main.async {
          result(nil)
        }
        return
      }

      DispatchQueue.main.async {
        result(FlutterStandardTypedData(bytes: data))
      }
    }
  }

  private func playTrack(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      result(FlutterError(
        code: "music_library_not_authorized",
        message: "Music library access has not been authorized.",
        details: nil
      ))
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let id = Self.persistentID(from: arguments["id"])
    else {
      result(FlutterError(
        code: "track_not_found",
        message: "The requested track was not found in the music library.",
        details: nil
      ))
      return
    }

    // Library queries can take seconds on large libraries, so keep them off the main thread.
    DispatchQueue.global(qos: .userInitiated).async {
      guard let item = Self.mediaItem(withPersistentID: id) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "track_not_found",
            message: "The requested track was not found in the music library.",
            details: nil
          ))
        }
        return
      }

      let libraryItems: [MPMediaItem]
      do {
        libraryItems = try SongBriefSnapshotRefresh.filteredLibraryItems()
      } catch {
        DispatchQueue.main.async {
          result(Self.libraryQueryError())
        }
        return
      }

      // Queue only a window starting at the target track instead of the whole library.
      let queueItems: [MPMediaItem]
      if let targetIndex = libraryItems.firstIndex(where: {
        $0.persistentID == item.persistentID
      }) {
        let endIndex = min(
          libraryItems.count,
          targetIndex + 1 + Self.playbackQueueWindowSize
        )
        queueItems = Array(libraryItems[targetIndex..<endIndex])
      } else {
        queueItems = [item] + Array(libraryItems.prefix(Self.playbackQueueWindowSize))
      }

      DispatchQueue.main.async {
        let player = MPMusicPlayerController.systemMusicPlayer
        player.setQueue(with: MPMediaItemCollection(items: queueItems))
        player.nowPlayingItem = item
        player.currentPlaybackTime = 0
        player.play()
        result(nil)
      }
    }
  }

  private func fetchLyrics(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if let arguments = call.arguments as? [String: Any],
       let id = arguments["id"] as? String, id.hasPrefix("musickit:") {
      // MusicKit does not expose catalog lyrics as text.
      result(nil)
      return
    }
    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      result(FlutterError(
        code: "music_library_not_authorized",
        message: "Music library access has not been authorized.",
        details: nil
      ))
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let id = Self.persistentID(from: arguments["id"])
    else {
      result(FlutterError(
        code: "invalid_track_id",
        message: "A valid track id is required.",
        details: nil
      ))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let lyrics = Self.mediaItem(withPersistentID: id).flatMap { item in
        Self.nonEmpty(item.value(forProperty: MPMediaItemPropertyLyrics) as? String)
      }

      DispatchQueue.main.async {
        result(lyrics)
      }
    }
  }

  private static func trackMap(
    from item: MPMediaItem,
    playlistNames: [String] = []
  ) -> [String: Any] {
    var track: [String: Any] = [
      "id": String(item.persistentID),
      "title": nonEmpty(item.title) ?? "Untitled",
      "artist": nonEmpty(item.artist) ?? "Unknown Artist",
      "albumTitle": nonEmpty(item.albumTitle) ?? "Unknown Album",
      "durationSeconds": Int(item.playbackDuration.rounded()),
      "playCount": item.playCount,
      "skipCount": item.skipCount,
      "isCloudItem": item.isCloudItem
    ]

    if let albumArtist = nonEmpty(item.albumArtist) {
      track["albumArtist"] = albumArtist
    }
    if let genre = nonEmpty(item.genre) {
      track["genre"] = genre
    }
    if item.playbackStoreID != "0",
       let appleMusicStoreID = nonEmpty(item.playbackStoreID) {
      track["appleMusicStoreId"] = appleMusicStoreID
    }
    if let releaseDate = item.value(forProperty: MPMediaItemPropertyReleaseDate) as? Date {
      track["releaseDateMillis"] = Int(releaseDate.timeIntervalSince1970 * 1000)
    }
    if !playlistNames.isEmpty {
      track["playlistNames"] = playlistNames
    }
    if let lastPlayedDate = item.lastPlayedDate {
      track["lastPlayedAtMillis"] = Int(lastPlayedDate.timeIntervalSince1970 * 1000)
    }

    return track
  }

  static func playlistNamesByItemID() throws -> [UInt64: [String]] {
    var namesByID: [UInt64: Set<String>] = [:]
    let playlists = try requireQueryResult(MPMediaQuery.playlists().collections)

    for collection in playlists {
      guard
        let playlist = collection as? MPMediaPlaylist,
        let playlistName = nonEmpty(playlist.name)
      else {
        continue
      }

      for item in playlist.items {
        var names = namesByID[item.persistentID] ?? []
        names.insert(playlistName)
        namesByID[item.persistentID] = names
      }
    }

    return namesByID.mapValues { names in
      names.sorted {
        $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
      }
    }
  }

  // MediaPlayer distinguishes an empty query result from a failed query (nil).
  static func requireQueryResult<T>(_ values: [T]?) throws -> [T] {
    guard let values else {
      throw NSError(domain: "app.songbrief.music-library", code: 1)
    }
    return values
  }

  private static func libraryQueryError() -> FlutterError {
    FlutterError(
      code: "music_library_unavailable",
      message: "The music library could not be read. Please try again.",
      details: nil
    )
  }

  private static func mediaItem(withPersistentID id: UInt64) -> MPMediaItem? {
    let query = MPMediaQuery.songs()
    let predicate = MPMediaPropertyPredicate(
      value: NSNumber(value: id),
      forProperty: MPMediaItemPropertyPersistentID
    )
    query.addFilterPredicate(predicate)
    return query.items?.first
  }

  private static func persistentID(from value: Any?) -> UInt64? {
    if let value = value as? String {
      return UInt64(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if let value = value as? UInt64 {
      return value
    }
    if let value = value as? Int64 {
      return UInt64(exactly: value)
    }
    if let value = value as? Int {
      return UInt64(exactly: value)
    }
    if let value = value as? NSNumber {
      return UInt64(exactly: value.int64Value)
    }
    return nil
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func authorizationStatusString(
    _ status: MPMediaLibraryAuthorizationStatus
  ) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .authorized:
      return "authorized"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    @unknown default:
      return "restricted"
    }
  }
}
