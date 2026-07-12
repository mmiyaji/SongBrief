import 'library_track.dart';

enum RankingScope { tracks, artists, albums, recent }

enum RankingEntryKind { track, artist, album }

class RankingEntry {
  const RankingEntry({
    required this.title,
    required this.subtitle,
    required this.playCount,
    required this.skipCount,
    required this.listeningSeconds,
    required this.kind,
    this.representativeTrackId,
    this.lastPlayedAt,
  });

  final String title;
  final String subtitle;
  final int playCount;
  final int skipCount;
  final int listeningSeconds;
  final RankingEntryKind kind;
  final String? representativeTrackId;
  final DateTime? lastPlayedAt;
}

class LibraryOverview {
  LibraryOverview({
    required this.tracks,
    required this.topTracks,
    required this.topArtists,
    required this.topAlbums,
    required this.recentTracks,
    required this.recentTrackDetails,
    required this.totalPlayCount,
    required this.totalSkipCount,
    required this.totalListeningSeconds,
    required this.totalArtists,
    required this.totalAlbums,
    required this.generatedAt,
    required this.isDemo,
    required Map<String, LibraryTrack> tracksById,
    required Map<String, List<LibraryTrack>> tracksByArtist,
    required Map<String, List<LibraryTrack>> tracksByAlbumArtist,
    required Map<String, List<LibraryTrack>> tracksByAlbum,
    required Map<String, List<LibraryTrack>> tracksByGenre,
    required Map<String, List<LibraryTrack>> tracksByPlaylist,
    required List<String> searchTexts,
    required this.tracksByRecent,
    required this.tracksByPlayCount,
    required this.tracksBySkipCount,
    required this.tracksByTitle,
  }) : _tracksById = tracksById,
       _tracksByArtist = tracksByArtist,
       _tracksByAlbumArtist = tracksByAlbumArtist,
       _tracksByAlbum = tracksByAlbum,
       _tracksByGenre = tracksByGenre,
       _tracksByPlaylist = tracksByPlaylist,
       _searchTexts = searchTexts;

  final List<LibraryTrack> tracks;
  final List<RankingEntry> topTracks;
  final List<RankingEntry> topArtists;
  final List<RankingEntry> topAlbums;
  final List<RankingEntry> recentTracks;
  final List<LibraryTrack> recentTrackDetails;
  final List<LibraryTrack> tracksByRecent;
  final List<LibraryTrack> tracksByPlayCount;
  final List<LibraryTrack> tracksBySkipCount;
  final List<LibraryTrack> tracksByTitle;
  final int totalPlayCount;
  final int totalSkipCount;
  final int totalListeningSeconds;
  final int totalArtists;
  final int totalAlbums;
  final DateTime generatedAt;
  final bool isDemo;
  final Map<String, LibraryTrack> _tracksById;
  final Map<String, List<LibraryTrack>> _tracksByArtist;
  final Map<String, List<LibraryTrack>> _tracksByAlbumArtist;
  final Map<String, List<LibraryTrack>> _tracksByAlbum;
  final Map<String, List<LibraryTrack>> _tracksByGenre;
  final Map<String, List<LibraryTrack>> _tracksByPlaylist;
  final List<String> _searchTexts;
  final Map<String, List<LibraryTrack>> _filteredTrackCache = {};

  int get totalTracks => tracks.length;

  bool get hasTracks => tracks.isNotEmpty;

  LibraryTrack? trackById(String? id) {
    if (id == null) {
      return null;
    }

    return _tracksById[id];
  }

  LibraryTrack? get latestTrack {
    final recent = recentTrackDetails;
    if (recent.isNotEmpty) {
      return recent.first;
    }
    return tracksByPlayCount.isEmpty ? null : tracksByPlayCount.first;
  }

  List<RankingEntry> entriesFor(RankingScope scope) {
    return switch (scope) {
      RankingScope.tracks => topTracks,
      RankingScope.artists => topArtists,
      RankingScope.albums => topAlbums,
      RankingScope.recent => recentTracks,
    };
  }

  List<LibraryTrack> tracksForArtist(String artist) {
    return _tracksByArtist[artist] ?? const [];
  }

  List<LibraryTrack> tracksForAlbumArtist(String albumArtist) {
    return _tracksByAlbumArtist[albumArtist] ?? const [];
  }

  List<LibraryTrack> tracksForAlbum(LibraryTrack album) {
    return _tracksByAlbum[_albumKey(album)] ?? const [];
  }

  List<LibraryTrack> tracksForGenre(String genre) {
    return _tracksByGenre[genre] ?? const [];
  }

  List<LibraryTrack> tracksForPlaylist(String playlistName) {
    return _tracksByPlaylist[playlistName] ?? const [];
  }

  List<LibraryTrack> filteredTracks(String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return tracks;
    }

    final cached = _filteredTrackCache[normalizedQuery];
    if (cached != null) {
      return cached;
    }

    final matches = <LibraryTrack>[];
    for (var index = 0; index < tracks.length; index += 1) {
      if (_searchTexts[index].contains(normalizedQuery)) {
        matches.add(tracks[index]);
      }
    }

    final result = List<LibraryTrack>.unmodifiable(matches);
    if (_filteredTrackCache.length >= 24) {
      _filteredTrackCache.clear();
    }
    _filteredTrackCache[normalizedQuery] = result;
    return result;
  }

  factory LibraryOverview.empty({required bool isDemo}) {
    return LibraryOverview(
      tracks: const [],
      topTracks: const [],
      topArtists: const [],
      topAlbums: const [],
      recentTracks: const [],
      recentTrackDetails: const [],
      totalPlayCount: 0,
      totalSkipCount: 0,
      totalListeningSeconds: 0,
      totalArtists: 0,
      totalAlbums: 0,
      generatedAt: DateTime.now(),
      isDemo: isDemo,
      tracksById: const {},
      tracksByArtist: const {},
      tracksByAlbumArtist: const {},
      tracksByAlbum: const {},
      tracksByGenre: const {},
      tracksByPlaylist: const {},
      searchTexts: const [],
      tracksByRecent: const [],
      tracksByPlayCount: const [],
      tracksBySkipCount: const [],
      tracksByTitle: const [],
    );
  }

  factory LibraryOverview.fromTracks(
    List<LibraryTrack> tracks, {
    required bool isDemo,
  }) {
    final tracksById = <String, LibraryTrack>{};
    final tracksByArtist = <String, List<LibraryTrack>>{};
    final tracksByAlbumArtist = <String, List<LibraryTrack>>{};
    final tracksByAlbum = <String, List<LibraryTrack>>{};
    final tracksByGenre = <String, List<LibraryTrack>>{};
    final tracksByPlaylist = <String, List<LibraryTrack>>{};
    final searchTexts = <String>[];
    final recentTrackDetails = <LibraryTrack>[];
    var totalPlayCount = 0;
    var totalSkipCount = 0;
    var totalListeningSeconds = 0;

    for (final track in tracks) {
      tracksById[track.id] = track;
      tracksByArtist.putIfAbsent(track.artist, () => []).add(track);
      final albumArtist = track.albumArtist ?? track.artist;
      tracksByAlbumArtist.putIfAbsent(albumArtist, () => []).add(track);
      tracksByAlbum.putIfAbsent(_albumKey(track), () => []).add(track);
      final genre = track.genre?.trim();
      if (genre != null && genre.isNotEmpty) {
        tracksByGenre.putIfAbsent(genre, () => []).add(track);
      }
      for (final playlistName in track.playlistNames) {
        tracksByPlaylist.putIfAbsent(playlistName, () => []).add(track);
      }
      searchTexts.add(_trackSearchText(track));
      if (track.lastPlayedAt != null) {
        recentTrackDetails.add(track);
      }
      totalPlayCount += track.playCount;
      totalSkipCount += track.skipCount;
      totalListeningSeconds += track.listeningSeconds;
    }

    recentTrackDetails.sort(_compareTrackRecentDesc);
    final tracksByRecent = tracks.toList(growable: false)
      ..sort(_compareTrackRecentDesc);
    final tracksByPlayCount = tracks.toList(growable: false)
      ..sort(_rankTracksByPlays);
    final tracksBySkipCount = tracks.toList(growable: false)
      ..sort(_rankTracksBySkips);
    final tracksByTitle = tracks.toList(growable: false)
      ..sort(_compareTrackTitle);

    final trackEntries = tracksByPlayCount
        .map(
          (track) => RankingEntry(
            title: track.title,
            subtitle: '${track.artist} - ${track.albumTitle}',
            playCount: track.playCount,
            skipCount: track.skipCount,
            listeningSeconds: track.listeningSeconds,
            kind: RankingEntryKind.track,
            representativeTrackId: track.id,
            lastPlayedAt: track.lastPlayedAt,
          ),
        )
        .toList(growable: false);

    final recentEntries = recentTrackDetails
        .map(
          (track) => RankingEntry(
            title: track.title,
            subtitle: track.artist,
            playCount: track.playCount,
            skipCount: track.skipCount,
            listeningSeconds: track.listeningSeconds,
            kind: RankingEntryKind.track,
            representativeTrackId: track.id,
            lastPlayedAt: track.lastPlayedAt,
          ),
        )
        .toList(growable: false);

    return LibraryOverview(
      tracks: List.unmodifiable(tracks),
      topTracks: List.unmodifiable(trackEntries),
      topArtists: List.unmodifiable(
        _groupTracksFromIndex(tracksByArtist, RankingEntryKind.artist),
      ),
      topAlbums: List.unmodifiable(
        _groupTracksFromIndex(tracksByAlbum, RankingEntryKind.album),
      ),
      recentTracks: List.unmodifiable(recentEntries),
      recentTrackDetails: List.unmodifiable(recentTrackDetails),
      totalPlayCount: totalPlayCount,
      totalSkipCount: totalSkipCount,
      totalListeningSeconds: totalListeningSeconds,
      totalArtists: tracksByArtist.length,
      totalAlbums: tracksByAlbum.length,
      generatedAt: DateTime.now(),
      isDemo: isDemo,
      tracksById: Map<String, LibraryTrack>.unmodifiable(tracksById),
      tracksByArtist: _sortedTrackIndex(tracksByArtist),
      tracksByAlbumArtist: _sortedTrackIndex(tracksByAlbumArtist),
      tracksByAlbum: _sortedTrackIndex(tracksByAlbum),
      tracksByGenre: _sortedTrackIndex(tracksByGenre),
      tracksByPlaylist: _sortedTrackIndex(tracksByPlaylist),
      searchTexts: List<String>.unmodifiable(searchTexts),
      tracksByRecent: List.unmodifiable(tracksByRecent),
      tracksByPlayCount: List.unmodifiable(tracksByPlayCount),
      tracksBySkipCount: List.unmodifiable(tracksBySkipCount),
      tracksByTitle: List.unmodifiable(tracksByTitle),
    );
  }

  static int _rankByPlays(RankingEntry a, RankingEntry b) {
    final byPlays = b.playCount.compareTo(a.playCount);
    if (byPlays != 0) {
      return byPlays;
    }
    return b.listeningSeconds.compareTo(a.listeningSeconds);
  }

  static String _albumKey(LibraryTrack track) {
    return '${track.albumArtist ?? track.artist} - ${track.albumTitle}';
  }

  static List<RankingEntry> _groupTracksFromIndex(
    Map<String, List<LibraryTrack>> groupsByKey,
    RankingEntryKind kind,
  ) {
    final groups = <_TrackGroup>[];
    for (final entry in groupsByKey.entries) {
      final group = _TrackGroup(entry.key);
      for (final track in entry.value) {
        group.add(track);
      }
      groups.add(group);
    }

    final entries = groups.map((group) => group.toRankingEntry(kind)).toList()
      ..sort(_rankByPlays);
    return entries;
  }

  static Map<String, List<LibraryTrack>> _sortedTrackIndex(
    Map<String, List<LibraryTrack>> groups,
  ) {
    return Map<String, List<LibraryTrack>>.unmodifiable({
      for (final entry in groups.entries)
        entry.key: List<LibraryTrack>.unmodifiable(
          entry.value.toList(growable: false)..sort(_rankTracksByPlays),
        ),
    });
  }
}

String _trackSearchText(LibraryTrack track) {
  return [
    track.title,
    track.artist,
    track.albumTitle,
    track.albumArtist,
    track.genre,
    ...track.playlistNames,
  ].whereType<String>().map(_normalizeSearchText).join('\u{1f}');
}

String _normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}

int _rankTracksByPlays(LibraryTrack a, LibraryTrack b) {
  final byPlays = b.playCount.compareTo(a.playCount);
  if (byPlays != 0) {
    return byPlays;
  }
  final bySeconds = b.listeningSeconds.compareTo(a.listeningSeconds);
  if (bySeconds != 0) {
    return bySeconds;
  }
  return _compareTrackTitle(a, b);
}

int _rankTracksBySkips(LibraryTrack a, LibraryTrack b) {
  final bySkips = b.skipCount.compareTo(a.skipCount);
  if (bySkips != 0) {
    return bySkips;
  }
  return _rankTracksByPlays(a, b);
}

int _compareTrackRecentDesc(LibraryTrack a, LibraryTrack b) {
  final aDate = a.lastPlayedAt;
  final bDate = b.lastPlayedAt;
  if (aDate == null && bDate == null) {
    return _compareTrackTitle(a, b);
  }
  if (aDate == null) {
    return 1;
  }
  if (bDate == null) {
    return -1;
  }
  final byDate = bDate.compareTo(aDate);
  if (byDate != 0) {
    return byDate;
  }
  return _compareTrackTitle(a, b);
}

int _compareTrackTitle(LibraryTrack a, LibraryTrack b) {
  final byTitle = _normalizeSearchText(
    a.title,
  ).compareTo(_normalizeSearchText(b.title));
  if (byTitle != 0) {
    return byTitle;
  }
  return a.id.compareTo(b.id);
}

class _TrackGroup {
  _TrackGroup(this.title);

  final String title;
  int trackCount = 0;
  int playCount = 0;
  int skipCount = 0;
  int listeningSeconds = 0;
  LibraryTrack? representativeTrack;
  DateTime? lastPlayedAt;

  void add(LibraryTrack track) {
    final currentRepresentative = representativeTrack;
    if (currentRepresentative == null ||
        track.playCount > currentRepresentative.playCount ||
        (track.playCount == currentRepresentative.playCount &&
            track.listeningSeconds > currentRepresentative.listeningSeconds)) {
      representativeTrack = track;
    }

    trackCount += 1;
    playCount += track.playCount;
    skipCount += track.skipCount;
    listeningSeconds += track.listeningSeconds;
    final playedAt = track.lastPlayedAt;
    if (playedAt != null &&
        (lastPlayedAt == null || playedAt.isAfter(lastPlayedAt!))) {
      lastPlayedAt = playedAt;
    }
  }

  RankingEntry toRankingEntry(RankingEntryKind kind) {
    return RankingEntry(
      title: title,
      subtitle: '$trackCount tracks',
      playCount: playCount,
      skipCount: skipCount,
      listeningSeconds: listeningSeconds,
      kind: kind,
      representativeTrackId: representativeTrack?.id,
      lastPlayedAt: lastPlayedAt,
    );
  }
}
