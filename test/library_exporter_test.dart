import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/export/library_exporter.dart';

void main() {
  test('builds escaped CSV rows for library tracks', () {
    final csv = buildLibraryCsv(_stats());

    expect(csv, contains('"Song ""Brief"""'));
    expect(csv, contains('"Focus|Favorites"'));
    expect(csv, contains('"987654321"'));
    expect(csv, contains('"2020-01-02T00:00:00.000"'));
    expect(csv, contains('"true"'));
  });

  test('escapes spreadsheet formulas in CSV cells', () {
    final csv = buildLibraryCsv(_stats(title: '=HYPERLINK("https://x")'));

    expect(csv, contains('"\'=HYPERLINK(""https://x"")"'));
  });

  test('builds JSON with totals and snapshot summaries', () {
    final json =
        jsonDecode(
              buildLibraryJson(_stats(), exportedAt: DateTime(2026, 7, 3, 12)),
            )
            as Map<String, Object?>;

    expect(json['version'], 1);
    expect((json['totals'] as Map<String, Object?>)['tracks'], 1);
    expect(
      ((json['tracks'] as List<Object?>).single
          as Map<String, Object?>)['appleMusicStoreId'],
      '987654321',
    );
    expect(
      ((json['tracks'] as List<Object?>).single
          as Map<String, Object?>)['releaseDate'],
      '2020-01-02T00:00:00.000',
    );
    expect((json['snapshots'] as List<Object?>).single, isA<Map>());
  });
}

MusicStatsState _stats({String title = 'Song "Brief"'}) {
  final overview = LibraryOverview.fromTracks([
    LibraryTrack(
      id: 'track-1',
      title: title,
      artist: 'Artist',
      albumTitle: 'Album',
      albumArtist: 'Album Artist',
      genre: 'Pop',
      appleMusicStoreId: '987654321',
      releaseDate: DateTime(2020, 1, 2),
      duration: const Duration(minutes: 3, seconds: 30),
      playCount: 10,
      skipCount: 2,
      lastPlayedAt: DateTime(2026, 7, 2, 20),
      isCloudItem: true,
      lyrics: 'line one',
      playlistNames: const ['Focus', 'Favorites'],
    ),
  ], isDemo: false);
  final snapshot = DailyLibrarySnapshot.fromOverview(
    overview,
    capturedAt: DateTime(2026, 7, 3, 8),
  );

  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: overview,
    snapshotHistory: SnapshotHistory.empty.withSnapshot(snapshot),
  );
}
