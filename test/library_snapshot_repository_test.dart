import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('trims oversized stored history instead of clearing it', () async {
    final history = SnapshotHistory(
      snapshots: List.unmodifiable(
        List.generate(24, (index) => _largeSnapshot(index)),
      ),
    );
    final raw = jsonEncode(history.toJson());
    expect(raw.length, greaterThan(1500000));

    SharedPreferences.setMockInitialValues({
      librarySnapshotPreferencesKey: raw,
    });

    final loaded = await const LibrarySnapshotRepository().loadHistory();
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(librarySnapshotPreferencesKey);

    expect(loaded.snapshotCount, 24);
    expect(loaded.latest?.dateKey, '2026-01-24');
    expect(saved, isNotNull);
    expect(saved!.length, lessThanOrEqualTo(1500000));
    expect(saved.length, lessThan(raw.length));
  });

  test('removes legacy snapshot keys only once', () async {
    SharedPreferences.setMockInitialValues({
      legacyLibrarySnapshotPreferencesKeys.single: 'legacy-history',
    });
    final repository = const LibrarySnapshotRepository();

    await repository.loadHistory();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(legacyLibrarySnapshotPreferencesKeys.single),
      isNull,
    );

    await preferences.setString(
      legacyLibrarySnapshotPreferencesKeys.single,
      'newly-written-legacy-value',
    );
    await repository.loadHistory();

    expect(
      preferences.getString(legacyLibrarySnapshotPreferencesKeys.single),
      'newly-written-legacy-value',
    );
  });
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
