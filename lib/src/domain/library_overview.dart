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
    required this._tracksById,
    required this._tracksByArtist,
    required this._tracksByAlbumArtist,
    required this._tracksByAlbum,
    required this._tracksByGenre,
    required this._tracksByPlaylist,
    required this._searchTexts,
    required this.tracksByRecent,
    required this.tracksByPlayCount,
    required this.tracksBySkipCount,
    required this.tracksByTitle,
  });

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

  /// Adds outside-library counts while retaining native search text, ranking
  /// entries and unaffected group indexes. Only supplemental songs are indexed
  /// and sorted from scratch; sorted native lists are merged in linear time.
  LibraryOverview withSupplementalTracks(List<LibraryTrack> supplemental) {
    final seen = <String>{};
    final additions = [
      for (final track in supplemental)
        if (!_tracksById.containsKey(track.id) && seen.add(track.id)) track,
    ];
    if (additions.isEmpty) return this;
    final extra = LibraryOverview.fromTracks(additions, isDemo: isDemo);
    final byId = Map<String, LibraryTrack>.unmodifiable({
      ..._tracksById,
      ...extra._tracksById,
    });
    final artists = _mergeTrackIndexes(_tracksByArtist, extra._tracksByArtist);
    final albums = _mergeTrackIndexes(_tracksByAlbum, extra._tracksByAlbum);
    return LibraryOverview(
      tracks: List.unmodifiable([...tracks, ...extra.tracks]),
      topTracks: _mergeSorted(
        topTracks,
        extra.topTracks,
        (a, b) => _rankTracksByPlays(
          byId[a.representativeTrackId]!,
          byId[b.representativeTrackId]!,
        ),
      ),
      topArtists: _mergeGroupRankings(
        topArtists,
        extra.topArtists,
        artists,
        byId,
      ),
      topAlbums: _mergeGroupRankings(topAlbums, extra.topAlbums, albums, byId),
      recentTracks: _mergeSorted(
        recentTracks,
        extra.recentTracks,
        (a, b) => _compareTrackRecentDesc(
          byId[a.representativeTrackId]!,
          byId[b.representativeTrackId]!,
        ),
      ),
      recentTrackDetails: _mergeSorted(
        recentTrackDetails,
        extra.recentTrackDetails,
        _compareTrackRecentDesc,
      ),
      totalPlayCount: totalPlayCount + extra.totalPlayCount,
      totalSkipCount: totalSkipCount + extra.totalSkipCount,
      totalListeningSeconds:
          totalListeningSeconds + extra.totalListeningSeconds,
      totalArtists: artists.length,
      totalAlbums: albums.length,
      generatedAt: DateTime.now(),
      isDemo: isDemo,
      tracksById: byId,
      tracksByArtist: artists,
      tracksByAlbumArtist: _mergeTrackIndexes(
        _tracksByAlbumArtist,
        extra._tracksByAlbumArtist,
      ),
      tracksByAlbum: albums,
      tracksByGenre: _mergeTrackIndexes(_tracksByGenre, extra._tracksByGenre),
      tracksByPlaylist: _mergeTrackIndexes(
        _tracksByPlaylist,
        extra._tracksByPlaylist,
      ),
      searchTexts: List.unmodifiable([..._searchTexts, ...extra._searchTexts]),
      tracksByRecent: _mergeSorted(
        tracksByRecent,
        extra.tracksByRecent,
        _compareTrackRecentDesc,
      ),
      tracksByPlayCount: _mergeSorted(
        tracksByPlayCount,
        extra.tracksByPlayCount,
        _rankTracksByPlays,
      ),
      tracksBySkipCount: _mergeSorted(
        tracksBySkipCount,
        extra.tracksBySkipCount,
        _rankTracksBySkips,
      ),
      tracksByTitle: _mergeSorted(
        tracksByTitle,
        extra.tracksByTitle,
        _compareTrackTitle,
      ),
    );
  }

  static Map<String, List<LibraryTrack>> _mergeTrackIndexes(
    Map<String, List<LibraryTrack>> native,
    Map<String, List<LibraryTrack>> extra,
  ) {
    final result = {...native};
    for (final entry in extra.entries) {
      final original = native[entry.key];
      result[entry.key] = original == null
          ? entry.value
          : _mergeSorted(original, entry.value, _rankTracksByPlays);
    }
    return Map.unmodifiable(result);
  }

  static List<RankingEntry> _mergeGroupRankings(
    List<RankingEntry> native,
    List<RankingEntry> extra,
    Map<String, List<LibraryTrack>> groups,
    Map<String, LibraryTrack> byId,
  ) {
    final pending = {for (final entry in extra) entry.title: entry};
    final unchanged = <RankingEntry>[];
    final changed = <RankingEntry>[];
    for (final original in native) {
      final addition = pending.remove(original.title);
      if (addition == null) {
        unchanged.add(original);
        continue;
      }
      final originalTrack = byId[original.representativeTrackId]!;
      final extraTrack = byId[addition.representativeTrackId]!;
      final useExtra =
          extraTrack.playCount > originalTrack.playCount ||
          (extraTrack.playCount == originalTrack.playCount &&
              extraTrack.listeningSeconds > originalTrack.listeningSeconds);
      final oldDate = original.lastPlayedAt;
      final extraDate = addition.lastPlayedAt;
      changed.add(
        RankingEntry(
          title: original.title,
          subtitle: '${groups[original.title]!.length} tracks',
          playCount: original.playCount + addition.playCount,
          skipCount: original.skipCount + addition.skipCount,
          listeningSeconds:
              original.listeningSeconds + addition.listeningSeconds,
          kind: original.kind,
          representativeTrackId: useExtra ? extraTrack.id : originalTrack.id,
          lastPlayedAt:
              oldDate == null ||
                  (extraDate != null && extraDate.isAfter(oldDate))
              ? extraDate
              : oldDate,
        ),
      );
    }
    changed.addAll(pending.values);
    changed.sort(_rankByPlays);
    return _mergeSorted(unchanged, changed, _rankByPlays);
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

List<T> _mergeSorted<T>(List<T> native, List<T> extra, Comparator<T> compare) {
  if (extra.isEmpty) return List.unmodifiable(native);
  if (native.isEmpty) return List.unmodifiable(extra);
  final result = <T>[];
  var left = 0;
  var right = 0;
  while (left < native.length && right < extra.length) {
    if (compare(native[left], extra[right]) <= 0) {
      result.add(native[left++]);
    } else {
      result.add(extra[right++]);
    }
  }
  result.addAll(native.getRange(left, native.length));
  result.addAll(extra.getRange(right, extra.length));
  return List.unmodifiable(result);
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
