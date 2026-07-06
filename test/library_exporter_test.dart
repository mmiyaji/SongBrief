import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/export/library_exporter.dart';

void main() {
  test('builds CSV and JSON file payloads with compact timestamps', () {
    final exportedAt = DateTime(2026, 7, 7, 9, 5);

    final csv = buildLibraryExportPayload(
      _stats(),
      LibraryExportFormat.csv,
      exportedAt: exportedAt,
    );
    final json = buildLibraryExportPayload(
      _stats(),
      LibraryExportFormat.json,
      exportedAt: exportedAt,
    );

    expect(csv.fileName, 'songbrief-library-20260707-0905.csv');
    expect(csv.mimeType, 'text/csv');
    expect(csv.content, startsWith('"id","title"'));
    expect(json.fileName, 'songbrief-library-20260707-0905.json');
    expect(json.mimeType, 'application/json');
    expect(json.content, contains('"version": 1'));
  });

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
    final plusCsv = buildLibraryCsv(_stats(title: '+SUM(1,2)'));
    final minusCsv = buildLibraryCsv(_stats(title: '-10'));
    final atCsv = buildLibraryCsv(_stats(title: '@hidden'));

    expect(csv, contains('"\'=HYPERLINK(""https://x"")"'));
    expect(plusCsv, contains('"\'+SUM(1,2)"'));
    expect(minusCsv, contains('"\'-10"'));
    expect(atCsv, contains('"\'@hidden"'));
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
