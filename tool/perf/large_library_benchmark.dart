// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;

import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_track.dart';

void main(List<String> args) {
  final trackCount = _readIntArg(args, 'tracks', fallback: 20000);
  final tracks = _largeSampleTracks(trackCount);

  stdout.writeln('SongBrief large library benchmark');
  stdout.writeln('tracks: ${tracks.length}');
  stdout.writeln(
    'rss after sample generation: ${_formatBytes(ProcessInfo.currentRss)}',
  );
  stdout.writeln('');

  LibraryOverview? measuredOverview;
  _warmUp(tracks);

  final build = _measure('overview build + indexes', 3, () {
    final overview = LibraryOverview.fromTracks(tracks, isDemo: true);
    measuredOverview = overview;
    return overview.totalPlayCount +
        overview.totalAlbums +
        overview.totalArtists;
  });

  final overview =
      measuredOverview ?? LibraryOverview.fromTracks(tracks, isDemo: true);
  stdout.writeln(
    'rss after overview build: ${_formatBytes(ProcessInfo.currentRss)}',
  );
  stdout.writeln('');

  final scanIterations = _scaledIterations(
    tracks.length,
    targetComparisons: 25000000,
    min: 100,
    max: 5000,
  );
  final sortIterations = _scaledIterations(
    tracks.length,
    targetComparisons: 600000,
    min: 3,
    max: 40,
  );
  final cachedIterations = math.max(25000, scanIterations * 10);
  final searchIterations = _scaledIterations(
    tracks.length,
    targetComparisons: 18000000,
    min: 100,
    max: 1200,
  );

  final results = <_Measurement>[
    build,
    _cachedTrackLookup(overview, tracks.length, cachedIterations),
    _naiveTrackLookup(tracks, scanIterations),
    _cachedTotals(overview, cachedIterations),
    _naiveTotals(tracks, scanIterations),
    _cachedRecentTracks(overview, cachedIterations),
    _naiveRecentTracks(tracks, sortIterations),
    _cachedSortedTracks(overview, cachedIterations),
    _naiveSortedTracks(tracks, sortIterations),
    _cachedArtistDrilldown(overview, cachedIterations),
    _naiveArtistDrilldown(tracks, scanIterations),
    _cachedPlaylistDrilldown(overview, cachedIterations),
    _naivePlaylistDrilldown(tracks, scanIterations),
    _cachedSearch(overview, searchIterations),
    _coldIndexedSearch(overview, tracks.length, searchIterations),
    _naiveSearch(tracks, searchIterations),
  ];

  _printResults(results);
}

void _warmUp(List<LibraryTrack> tracks) {
  final sample = tracks.length > 1000 ? tracks.take(1000).toList() : tracks;
  final overview = LibraryOverview.fromTracks(sample, isDemo: true);
  overview.trackById(sample.first.id);
  overview.filteredTracks('demo artist');
  overview.tracksForPlaylist('Playlist 0001');
}

_Measurement _cachedTrackLookup(
  LibraryOverview overview,
  int trackCount,
  int iterations,
) {
  var index = 0;
  return _measure('cached trackById', iterations, () {
    index = (index + 7919) % trackCount;
    return overview.trackById('large-demo-$index')?.playCount ?? 0;
  });
}

_Measurement _naiveTrackLookup(List<LibraryTrack> tracks, int iterations) {
  var index = 0;
  return _measure('naive track scan by id', iterations, () {
    index = (index + 7919) % tracks.length;
    return _naiveTrackById(tracks, 'large-demo-$index')?.playCount ?? 0;
  });
}

_Measurement _cachedTotals(LibraryOverview overview, int iterations) {
  return _measure('cached artist/album totals', iterations, () {
    return overview.totalArtists + overview.totalAlbums;
  });
}

_Measurement _naiveTotals(List<LibraryTrack> tracks, int iterations) {
  return _measure('naive artist/album totals', iterations, () {
    final artists = <String>{};
    final albums = <String>{};
    for (final track in tracks) {
      artists.add(track.artist);
      albums.add('${track.albumArtist ?? track.artist} - ${track.albumTitle}');
    }
    return artists.length + albums.length;
  });
}

_Measurement _cachedRecentTracks(LibraryOverview overview, int iterations) {
  return _measure('cached recent tracks', iterations, () {
    return overview.recentTrackDetails.first.playCount;
  });
}

_Measurement _naiveRecentTracks(List<LibraryTrack> tracks, int iterations) {
  return _measure('naive recent sort', iterations, () {
    final recent = tracks.where((track) => track.lastPlayedAt != null).toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return recent.first.playCount;
  });
}

_Measurement _cachedSortedTracks(LibraryOverview overview, int iterations) {
  return _measure('cached play-count sort', iterations, () {
    return overview.tracksByPlayCount.first.playCount;
  });
}

_Measurement _naiveSortedTracks(List<LibraryTrack> tracks, int iterations) {
  return _measure('naive play-count sort', iterations, () {
    final sorted = tracks.toList(growable: false)..sort(_rankTracksByPlays);
    return sorted.first.playCount;
  });
}

_Measurement _cachedArtistDrilldown(LibraryOverview overview, int iterations) {
  return _measure('cached artist drilldown', iterations, () {
    return overview.tracksForArtist('Demo Artist 0042').length;
  });
}

_Measurement _naiveArtistDrilldown(List<LibraryTrack> tracks, int iterations) {
  return _measure('naive artist drilldown', iterations, () {
    var count = 0;
    for (final track in tracks) {
      if (track.artist == 'Demo Artist 0042') {
        count += 1;
      }
    }
    return count;
  });
}

_Measurement _cachedPlaylistDrilldown(
  LibraryOverview overview,
  int iterations,
) {
  return _measure('cached playlist drilldown', iterations, () {
    return overview.tracksForPlaylist('Playlist 0042').length;
  });
}

_Measurement _naivePlaylistDrilldown(
  List<LibraryTrack> tracks,
  int iterations,
) {
  return _measure('naive playlist drilldown', iterations, () {
    var count = 0;
    for (final track in tracks) {
      if (track.playlistNames.contains('Playlist 0042')) {
        count += 1;
      }
    }
    return count;
  });
}

_Measurement _cachedSearch(LibraryOverview overview, int iterations) {
  overview.filteredTracks('artist 0042');
  return _measure('cached normalized search', iterations, () {
    return overview.filteredTracks('artist 0042').length;
  });
}

_Measurement _coldIndexedSearch(
  LibraryOverview overview,
  int trackCount,
  int iterations,
) {
  final artistCount = math.max(1, trackCount ~/ 20);
  var index = 0;
  return _measure('indexed cold search', iterations, () {
    index = (index + 37) % artistCount;
    return overview
        .filteredTracks('artist ${index.toString().padLeft(4, '0')}')
        .length;
  });
}

_Measurement _naiveSearch(List<LibraryTrack> tracks, int iterations) {
  const query = 'artist 0042';
  return _measure('naive field search', iterations, () {
    var count = 0;
    for (final track in tracks) {
      final fields = [
        track.title,
        track.artist,
        track.albumTitle,
        track.albumArtist,
        track.genre,
        ...track.playlistNames,
      ];
      if (fields.whereType<String>().any((field) {
        return field.trim().toLowerCase().contains(query);
      })) {
        count += 1;
      }
    }
    return count;
  });
}

_Measurement _measure(String label, int iterations, int Function() body) {
  var checksum = 0;
  final watch = Stopwatch()..start();
  for (var i = 0; i < iterations; i += 1) {
    checksum += body();
  }
  watch.stop();
  return _Measurement(
    label: label,
    iterations: iterations,
    elapsedMicroseconds: watch.elapsedMicroseconds,
    checksum: checksum,
  );
}

void _printResults(List<_Measurement> results) {
  stdout.writeln(
    'operation'.padRight(31) +
        'iterations'.padLeft(12) +
        'total ms'.padLeft(12) +
        'us/op'.padLeft(12) +
        'checksum'.padLeft(14),
  );
  stdout.writeln(''.padRight(81, '-'));
  for (final result in results) {
    stdout.writeln(result.format());
  }
}

int _scaledIterations(
  int trackCount, {
  required int targetComparisons,
  required int min,
  required int max,
}) {
  return (targetComparisons ~/ trackCount).clamp(min, max).toInt();
}

int _readIntArg(List<String> args, String name, {required int fallback}) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (!arg.startsWith(prefix)) {
      continue;
    }
    return int.tryParse(arg.substring(prefix.length)) ?? fallback;
  }
  return fallback;
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}

LibraryTrack? _naiveTrackById(List<LibraryTrack> tracks, String id) {
  for (final track in tracks) {
    if (track.id == id) {
      return track;
    }
  }
  return null;
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
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

List<LibraryTrack> _largeSampleTracks(int count) {
  final safeCount = math.max(1, count);
  final now = DateTime.now();
  final artists = safeCount < 20 ? safeCount : safeCount ~/ 20;
  final albums = safeCount < 10 ? safeCount : safeCount ~/ 10;
  const genres = [
    'Electronic',
    'Indie Rock',
    'Pop',
    'Ambient',
    'Jazz',
    'Classical',
    'Hip-Hop',
    'Soundtrack',
    'Folk',
    'Metal',
  ];

  return List.generate(safeCount, (index) {
    final artistIndex = index % artists;
    final albumIndex = index % albums;
    final genre = genres[index % genres.length];
    final playCount = (safeCount - index) % 400 + (index % 17);
    final skipCount = index % 31;
    final playlistBase = index % 1000;
    return LibraryTrack(
      id: 'large-demo-$index',
      title: 'Demo Track ${index.toString().padLeft(5, '0')}',
      artist: 'Demo Artist ${artistIndex.toString().padLeft(4, '0')}',
      albumTitle: 'Demo Album ${albumIndex.toString().padLeft(4, '0')}',
      albumArtist: 'Demo Artist ${artistIndex.toString().padLeft(4, '0')}',
      genre: genre,
      releaseDate: DateTime(1975 + index % 50, index % 12 + 1, 1),
      duration: Duration(minutes: 2 + index % 5, seconds: index % 60),
      playCount: playCount,
      skipCount: skipCount,
      lastPlayedAt: index % 5 == 0
          ? null
          : now.subtract(Duration(hours: index % 720)),
      playlistNames: [
        'Playlist ${playlistBase.toString().padLeft(4, '0')}',
        'Mood ${(playlistBase % 80).toString().padLeft(2, '0')}',
        if (index % 3 == 0)
          'Rotation ${(playlistBase % 40).toString().padLeft(2, '0')}',
      ],
      isCloudItem: index % 7 == 0,
    );
  }, growable: false);
}

class _Measurement {
  const _Measurement({
    required this.label,
    required this.iterations,
    required this.elapsedMicroseconds,
    required this.checksum,
  });

  final String label;
  final int iterations;
  final int elapsedMicroseconds;
  final int checksum;

  String format() {
    final totalMs = elapsedMicroseconds / 1000;
    final usPerOperation = elapsedMicroseconds / iterations;
    return label.padRight(31) +
        iterations.toString().padLeft(12) +
        totalMs.toStringAsFixed(2).padLeft(12) +
        usPerOperation.toStringAsFixed(2).padLeft(12) +
        checksum.toString().padLeft(14);
  }
}
