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
    this.lyrics,
    this.playlistNames = const <String>[],
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
  final String? lyrics;
  final List<String> playlistNames;

  int get listeningSeconds => duration.inSeconds * playCount;

  LibraryTrack copyWith({
    int? playCount,
    int? skipCount,
    DateTime? lastPlayedAt,
  }) {
    return LibraryTrack(
      id: id,
      title: title,
      artist: artist,
      albumTitle: albumTitle,
      albumArtist: albumArtist,
      genre: genre,
      artworkAsset: artworkAsset,
      duration: duration,
      playCount: playCount ?? this.playCount,
      skipCount: skipCount ?? this.skipCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isCloudItem: isCloudItem,
      lyrics: lyrics,
      playlistNames: playlistNames,
    );
  }

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
      lyrics: _readNullableString(map, 'lyrics'),
      playlistNames: _readStringList(map, 'playlistNames'),
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

  static List<String> _readStringList(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is! Iterable) {
      return const <String>[];
    }

    final names = <String>{};
    for (final item in value) {
      if (item is! String) {
        continue;
      }
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        names.add(trimmed);
      }
    }

    if (names.isEmpty) {
      return const <String>[];
    }

    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List.unmodifiable(sorted);
  }
}
