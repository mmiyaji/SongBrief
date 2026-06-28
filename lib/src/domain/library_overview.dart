import 'library_track.dart';

enum RankingScope {
  tracks,
  artists,
  albums,
  recent;

  String get label {
    return switch (this) {
      RankingScope.tracks => 'Songs',
      RankingScope.artists => 'Artists',
      RankingScope.albums => 'Albums',
      RankingScope.recent => 'Recent',
    };
  }
}

class RankingEntry {
  const RankingEntry({
    required this.title,
    required this.subtitle,
    required this.playCount,
    required this.skipCount,
    required this.listeningSeconds,
    this.lastPlayedAt,
  });

  final String title;
  final String subtitle;
  final int playCount;
  final int skipCount;
  final int listeningSeconds;
  final DateTime? lastPlayedAt;
}

class LibraryOverview {
  const LibraryOverview({
    required this.tracks,
    required this.topTracks,
    required this.topArtists,
    required this.topAlbums,
    required this.recentTracks,
    required this.totalPlayCount,
    required this.totalSkipCount,
    required this.totalListeningSeconds,
    required this.generatedAt,
    required this.isDemo,
  });

  final List<LibraryTrack> tracks;
  final List<RankingEntry> topTracks;
  final List<RankingEntry> topArtists;
  final List<RankingEntry> topAlbums;
  final List<RankingEntry> recentTracks;
  final int totalPlayCount;
  final int totalSkipCount;
  final int totalListeningSeconds;
  final DateTime generatedAt;
  final bool isDemo;

  int get totalTracks => tracks.length;

  int get totalArtists => tracks.map((track) => track.artist).toSet().length;

  int get totalAlbums => tracks
      .map(
        (track) => '${track.albumArtist ?? track.artist} - ${track.albumTitle}',
      )
      .toSet()
      .length;

  bool get hasTracks => tracks.isNotEmpty;

  List<LibraryTrack> get recentTrackDetails {
    final recent = tracks.where((track) => track.lastPlayedAt != null).toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return List.unmodifiable(recent);
  }

  LibraryTrack? get latestTrack {
    final recent = recentTrackDetails;
    if (recent.isNotEmpty) {
      return recent.first;
    }
    if (tracks.isEmpty) {
      return null;
    }

    final ranked = tracks.toList()
      ..sort((a, b) {
        final byPlays = b.playCount.compareTo(a.playCount);
        if (byPlays != 0) {
          return byPlays;
        }
        return b.listeningSeconds.compareTo(a.listeningSeconds);
      });
    return ranked.first;
  }

  List<RankingEntry> entriesFor(RankingScope scope) {
    return switch (scope) {
      RankingScope.tracks => topTracks,
      RankingScope.artists => topArtists,
      RankingScope.albums => topAlbums,
      RankingScope.recent => recentTracks,
    };
  }

  factory LibraryOverview.empty({required bool isDemo}) {
    return LibraryOverview(
      tracks: const [],
      topTracks: const [],
      topArtists: const [],
      topAlbums: const [],
      recentTracks: const [],
      totalPlayCount: 0,
      totalSkipCount: 0,
      totalListeningSeconds: 0,
      generatedAt: DateTime.now(),
      isDemo: isDemo,
    );
  }

  factory LibraryOverview.fromTracks(
    List<LibraryTrack> tracks, {
    required bool isDemo,
  }) {
    final trackEntries =
        tracks
            .map(
              (track) => RankingEntry(
                title: track.title,
                subtitle: '${track.artist} - ${track.albumTitle}',
                playCount: track.playCount,
                skipCount: track.skipCount,
                listeningSeconds: track.listeningSeconds,
                lastPlayedAt: track.lastPlayedAt,
              ),
            )
            .toList()
          ..sort(_rankByPlays);

    final recentEntries =
        tracks
            .where((track) => track.lastPlayedAt != null)
            .map(
              (track) => RankingEntry(
                title: track.title,
                subtitle: track.artist,
                playCount: track.playCount,
                skipCount: track.skipCount,
                listeningSeconds: track.listeningSeconds,
                lastPlayedAt: track.lastPlayedAt,
              ),
            )
            .toList()
          ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));

    final totalPlayCount = tracks.fold<int>(
      0,
      (total, track) => total + track.playCount,
    );
    final totalSkipCount = tracks.fold<int>(
      0,
      (total, track) => total + track.skipCount,
    );
    final totalListeningSeconds = tracks.fold<int>(
      0,
      (total, track) => total + track.listeningSeconds,
    );

    return LibraryOverview(
      tracks: List.unmodifiable(tracks),
      topTracks: List.unmodifiable(trackEntries.take(100)),
      topArtists: List.unmodifiable(_groupTracks(tracks, _artistKey).take(100)),
      topAlbums: List.unmodifiable(_groupTracks(tracks, _albumKey).take(100)),
      recentTracks: List.unmodifiable(recentEntries.take(100)),
      totalPlayCount: totalPlayCount,
      totalSkipCount: totalSkipCount,
      totalListeningSeconds: totalListeningSeconds,
      generatedAt: DateTime.now(),
      isDemo: isDemo,
    );
  }

  static int _rankByPlays(RankingEntry a, RankingEntry b) {
    final byPlays = b.playCount.compareTo(a.playCount);
    if (byPlays != 0) {
      return byPlays;
    }
    return b.listeningSeconds.compareTo(a.listeningSeconds);
  }

  static String _artistKey(LibraryTrack track) => track.artist;

  static String _albumKey(LibraryTrack track) {
    return '${track.albumArtist ?? track.artist} - ${track.albumTitle}';
  }

  static List<RankingEntry> _groupTracks(
    List<LibraryTrack> tracks,
    String Function(LibraryTrack track) keyFor,
  ) {
    final groups = <String, _TrackGroup>{};
    for (final track in tracks) {
      final key = keyFor(track);
      final group = groups.putIfAbsent(key, () => _TrackGroup(key));
      group.add(track);
    }

    final entries =
        groups.values.map((group) => group.toRankingEntry()).toList()
          ..sort(_rankByPlays);
    return entries;
  }
}

class _TrackGroup {
  _TrackGroup(this.title);

  final String title;
  int trackCount = 0;
  int playCount = 0;
  int skipCount = 0;
  int listeningSeconds = 0;
  DateTime? lastPlayedAt;

  void add(LibraryTrack track) {
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

  RankingEntry toRankingEntry() {
    return RankingEntry(
      title: title,
      subtitle: '$trackCount tracks',
      playCount: playCount,
      skipCount: skipCount,
      listeningSeconds: listeningSeconds,
      lastPlayedAt: lastPlayedAt,
    );
  }
}
