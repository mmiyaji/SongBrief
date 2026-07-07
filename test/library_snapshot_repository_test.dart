import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/data/library_snapshot_store_io.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory snapshotDirectory;
  late LibrarySnapshotRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    snapshotDirectory = await Directory.systemTemp.createTemp(
      'songbrief_snapshots_',
    );
    repository = LibrarySnapshotRepository(
      store: FileSnapshotStore(
        directoryProvider: () async => snapshotDirectory,
      ),
    );
  });

  tearDown(() async {
    if (await snapshotDirectory.exists()) {
      await snapshotDirectory.delete(recursive: true);
    }
  });

  test(
    'stores large histories as per-day files without a preferences cap',
    () async {
      final store = FileSnapshotStore(
        directoryProvider: () async => snapshotDirectory,
      );
      final snapshots = List.generate(24, (index) => _largeSnapshot(index));
      for (final snapshot in snapshots) {
        await store.writeSnapshot(snapshot);
      }

      final loaded = await repository.loadHistory();
      final preferences = await SharedPreferences.getInstance();
      final files = await snapshotDirectory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      final totalBytes = await _directoryBytes(snapshotDirectory);

      expect(loaded.snapshotCount, 24);
      expect(loaded.latest?.dateKey, '2026-01-24');
      expect(files, hasLength(24));
      expect(totalBytes, greaterThan(1500000));
      expect(
        preferences.getString(librarySnapshotFallbackPreferencesKey),
        isNull,
      );
    },
  );

  test('cleans malformed legacy snapshot keys during migration', () async {
    SharedPreferences.setMockInitialValues({
      legacyLibrarySnapshotPreferencesKeys.first: 'legacy-history',
    });

    await repository.loadHistory();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(legacyLibrarySnapshotPreferencesKeys.first),
      isNull,
    );

    await preferences.setString(
      legacyLibrarySnapshotPreferencesKeys.first,
      'newly-written-legacy-value',
    );
    await repository.loadHistory();

    expect(
      preferences.getString(legacyLibrarySnapshotPreferencesKeys.first),
      isNull,
    );
  });

  test('migrates legacy preferences snapshots into per-day files', () async {
    final legacyHistory = SnapshotHistory.empty
        .withSnapshot(_snapshotOn(DateTime(2026, 1, 3)))
        .withSnapshot(_snapshotOn(DateTime(2026, 1, 4)));
    SharedPreferences.setMockInitialValues({
      legacyLibrarySnapshotPreferencesKeys.last: jsonEncode(
        legacyHistory.toJson(),
      ),
    });

    final loaded = await repository.loadHistory();
    final preferences = await SharedPreferences.getInstance();

    expect(loaded.snapshotCount, 2);
    expect(loaded.snapshots.first.dateKey, '2026-01-03');
    expect(loaded.latest?.dateKey, '2026-01-04');
    expect(await _snapshotFileCount(snapshotDirectory), 2);
    expect(
      preferences.getString(legacyLibrarySnapshotPreferencesKeys.last),
      isNull,
    );
  });

  test(
    'migrates remaining legacy snapshots even when migration was flagged',
    () async {
      final legacyHistory = SnapshotHistory.empty.withSnapshot(
        _snapshotOn(DateTime(2026, 1, 5)),
      );
      SharedPreferences.setMockInitialValues({
        'songbrief_daily_snapshots_file_store_migrated_v1': true,
        legacyLibrarySnapshotPreferencesKeys.last: jsonEncode(
          legacyHistory.toJson(),
        ),
      });

      final loaded = await repository.loadHistory();

      expect(loaded.snapshotCount, 1);
      expect(loaded.latest?.dateKey, '2026-01-05');
      expect(await _snapshotFileCount(snapshotDirectory), 1);
    },
  );

  test('ignores malformed stored snapshot files', () async {
    await File(
      '${snapshotDirectory.path}${Platform.pathSeparator}2026-01-01.json',
    ).writeAsString('{not-json');

    final history = await repository.loadHistory();

    expect(history.snapshotCount, 0);
  });

  test('records an overview snapshot and replaces the same day', () async {
    final first = await repository.recordSnapshot(
      _overview(playCount: 4),
      capturedAt: DateTime(2026, 7, 7, 8),
    );
    final second = await repository.recordSnapshot(
      _overview(playCount: 9),
      capturedAt: DateTime(2026, 7, 7, 20),
      source: 'manual',
    );
    final reloaded = await repository.loadHistory();

    expect(first.snapshotCount, 1);
    expect(second.snapshotCount, 1);
    expect(second.latest?.source, 'manual');
    expect(second.latest?.totalPlayCount, 9);
    expect(reloaded.latest?.totalPlayCount, 9);
    expect(await _snapshotFileCount(snapshotDirectory), 1);
  });

  test('does not record empty overviews', () async {
    await _writeSnapshotFile(
      snapshotDirectory,
      _snapshotOn(DateTime(2026, 1, 1)),
    );

    final result = await repository.recordSnapshot(
      LibraryOverview.empty(isDemo: false),
    );

    expect(result.snapshotCount, 1);
    expect(result.latest?.dateKey, '2026-01-01');
    expect(await _snapshotFileCount(snapshotDirectory), 1);
  });

  test(
    'deletes snapshots older than a cutoff and persists the result',
    () async {
      await _writeSnapshotFile(
        snapshotDirectory,
        _snapshotOn(DateTime(2026, 1, 1)),
      );
      await _writeSnapshotFile(
        snapshotDirectory,
        _snapshotOn(DateTime(2026, 1, 20)),
      );
      await _writeSnapshotFile(
        snapshotDirectory,
        _snapshotOn(DateTime(2026, 2, 1)),
      );

      final trimmed = await repository.deleteSnapshotsOlderThan(
        DateTime(2026, 1, 15),
      );
      final reloaded = await repository.loadHistory();

      expect(trimmed.snapshotCount, 2);
      expect(trimmed.snapshots.first.dateKey, '2026-01-20');
      expect(reloaded.snapshotCount, 2);
      expect(reloaded.snapshots.first.dateKey, '2026-01-20');
      expect(await _snapshotFileCount(snapshotDirectory), 2);
    },
  );

  test('clears stored snapshot history', () async {
    await _writeSnapshotFile(
      snapshotDirectory,
      _snapshotOn(DateTime(2026, 1, 1)),
    );

    final cleared = await repository.clearHistory();

    expect(cleared.snapshotCount, 0);
    expect(await _snapshotFileCount(snapshotDirectory), 0);
    expect((await repository.loadHistory()).snapshotCount, 0);
  });
}

Future<void> _writeSnapshotFile(
  Directory directory,
  DailyLibrarySnapshot snapshot,
) async {
  await directory.create(recursive: true);
  await File(
    '${directory.path}${Platform.pathSeparator}${snapshot.dateKey}.json',
  ).writeAsString(jsonEncode(snapshot.toJson()));
}

Future<int> _snapshotFileCount(Directory directory) async {
  if (!await directory.exists()) {
    return 0;
  }
  return directory
      .list()
      .where((entity) => entity is File && entity.path.endsWith('.json'))
      .length;
}

Future<int> _directoryBytes(Directory directory) async {
  var bytes = 0;
  await for (final entity in directory.list()) {
    if (entity is File) {
      bytes += await entity.length();
    }
  }
  return bytes;
}

DailyLibrarySnapshot _snapshotOn(DateTime capturedAt) {
  return DailyLibrarySnapshot(
    dateKey: snapshotDateKey(capturedAt),
    capturedAt: capturedAt,
    source: 'foreground',
    trackCount: 10,
    totalPlayCount: capturedAt.day,
    totalSkipCount: 0,
    totalListeningSeconds: capturedAt.day * 180,
    tracks: const [],
  );
}

LibraryOverview _overview({required int playCount}) {
  return LibraryOverview.fromTracks([
    LibraryTrack(
      id: 'track-1',
      title: 'Snapshot Song',
      artist: 'Snapshot Artist',
      albumTitle: 'Snapshot Album',
      duration: const Duration(minutes: 4),
      playCount: playCount,
      skipCount: 1,
      isCloudItem: false,
    ),
  ], isDemo: false);
}

DailyLibrarySnapshot _largeSnapshot(int index) {
  final capturedAt = DateTime(2026, 1, index + 1, 8);
  return DailyLibrarySnapshot(
    dateKey: snapshotDateKey(capturedAt),
    capturedAt: capturedAt,
    source: 'foreground',
    trackCount: maxSnapshotTrackCounters + 200,
    totalPlayCount: 100000 + index,
    totalSkipCount: 5000 + index,
    totalListeningSeconds: 300000 + index,
    tracks: List.unmodifiable(
      List.generate(
        maxSnapshotTrackCounters,
        (trackIndex) => TrackCounterSnapshot(
          id: 'track-${trackIndex.toString().padLeft(4, '0')}',
          title:
              'Large Snapshot Song $index-$trackIndex ${'title-padding-' * 8}',
          artist: 'Snapshot Artist ${trackIndex % 40} ${'artist-padding-' * 5}',
          albumTitle:
              'Snapshot Album ${trackIndex % 60} ${'album-padding-' * 5}',
          albumArtist: 'Album Artist ${trackIndex % 25}',
          genre: 'Genre ${trackIndex % 12}',
          playCount: 1000 + index + trackIndex,
          skipCount: trackIndex % 20,
          listeningSeconds: (180 + trackIndex % 120) * (1000 + index),
          lastPlayedAt: capturedAt.add(Duration(minutes: trackIndex)),
        ),
      ),
    ),
  );
}
