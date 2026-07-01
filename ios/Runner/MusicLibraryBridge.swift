import Flutter
import MediaPlayer

final class MusicLibraryBridge {
  private init() {}

  static func register(with messenger: FlutterBinaryMessenger) {
    let bridge = MusicLibraryBridge()
    let channel = FlutterMethodChannel(
      name: "app.songbrief/music_library",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationStatus":
      result(Self.authorizationStatusString(MPMediaLibrary.authorizationStatus()))
    case "requestAuthorization":
      MPMediaLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          result(Self.authorizationStatusString(status))
        }
      }
    case "fetchTracks":
      fetchTracks(result: result)
    case "fetchArtwork":
      fetchArtwork(call, result: result)
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
      SongBriefSnapshotRefresh.schedule()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
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
      let query = MPMediaQuery.songs()
      let items = query.items ?? []
      let playlistNamesByItemID = Self.playlistNamesByItemID()
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

  private func fetchArtwork(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    DispatchQueue.global(qos: .userInitiated).async {
      guard
        let item = Self.mediaItem(withPersistentID: id),
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
      let id = Self.persistentID(from: arguments["id"]),
      let item = Self.mediaItem(withPersistentID: id)
    else {
      result(FlutterError(
        code: "track_not_found",
        message: "The requested track was not found in the music library.",
        details: nil
      ))
      return
    }

    let player = MPMusicPlayerController.systemMusicPlayer
    player.setQueue(with: MPMediaItemCollection(items: [item]))
    player.nowPlayingItem = item
    player.play()
    result(nil)
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
    if let lyrics = nonEmpty(
      item.value(forProperty: MPMediaItemPropertyLyrics) as? String
    ) {
      track["lyrics"] = lyrics
    }
    if !playlistNames.isEmpty {
      track["playlistNames"] = playlistNames
    }
    if let lastPlayedDate = item.lastPlayedDate {
      track["lastPlayedAtMillis"] = Int(lastPlayedDate.timeIntervalSince1970 * 1000)
    }

    return track
  }

  private static func playlistNamesByItemID() -> [UInt64: [String]] {
    var namesByID: [UInt64: Set<String>] = [:]
    let playlists = MPMediaQuery.playlists().collections ?? []

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
      return UInt64(value)
    }
    if let value = value as? Int {
      return UInt64(value)
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
