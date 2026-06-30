class LibraryTrack {
  const LibraryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumTitle,
    required this.duration,
    required this.playCount,
    required this.skipCount,
    required this.isCloudItem,
    this.albumArtist,
    this.genre,
    this.artworkAsset,
    this.lastPlayedAt,
  });

  final String id;
  final String title;
  final String artist;
  final String albumTitle;
  final String? albumArtist;
  final String? genre;
  final String? artworkAsset;
  final Duration duration;
  final int playCount;
  final int skipCount;
  final DateTime? lastPlayedAt;
  final bool isCloudItem;

  int get listeningSeconds => duration.inSeconds * playCount;

  factory LibraryTrack.fromPlatformMap(Map<Object?, Object?> map) {
    return LibraryTrack(
      id: _readString(map, 'id', fallback: 'unknown'),
      title: _readString(map, 'title', fallback: 'Untitled'),
      artist: _readString(map, 'artist', fallback: 'Unknown Artist'),
      albumTitle: _readString(map, 'albumTitle', fallback: 'Unknown Album'),
      albumArtist: _readNullableString(map, 'albumArtist'),
      genre: _readNullableString(map, 'genre'),
      duration: Duration(seconds: _readInt(map, 'durationSeconds')),
      playCount: _readInt(map, 'playCount'),
      skipCount: _readInt(map, 'skipCount'),
      lastPlayedAt: _readDateTime(map, 'lastPlayedAtMillis'),
      isCloudItem: _readBool(map, 'isCloudItem'),
    );
  }

  static String _readString(
    Map<Object?, Object?> map,
    String key, {
    required String fallback,
  }) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static String? _readNullableString(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static int _readInt(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return 0;
  }

  static bool _readBool(Map<Object?, Object?> map, String key) {
    final value = map[key];
    return value is bool && value;
  }

  static DateTime? _readDateTime(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is int && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    return null;
  }
}
