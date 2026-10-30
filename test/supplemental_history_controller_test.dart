import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

LibraryTrack _track({String id = 'one', DateTime? at}) => LibraryTrack(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(seconds: 200),
  playCount: 0,
  skipCount: 0,
  isCloudItem: true,
  lastPlayedAt: at,
);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ledger survives container recreation and repeated ingestion', () async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    final date = DateTime.utc(2026, 10, 1);
    container.read(supplementalHistoryProvider.notifier).ingest([
      _track(at: date),
    ]);
    await _settle();
    container.dispose();

    final restored = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(restored.dispose);
    restored.read(supplementalHistoryProvider.notifier).ingest([
      _track(at: date),
    ]);
    expect(restored.read(supplementalHistoryProvider).totalPlayCount, 1);
    expect(
      restored.read(supplementalHistoryProvider).datedEvents.single.playedAt,
      date,
    );
  });

  test('legacy caches migrate once and observed times stay undated', () async {
    final date = DateTime.utc(2026, 10, 1);
    SharedPreferences.setMockInitialValues({
      'songbrief_apple_music_recent_v1': jsonEncode([
        {
          'id': 'one',
          'title': 'Song one',
          'artist': 'Artist',
          'albumTitle': 'Album',
          'durationSeconds': 200,
          'lastPlayedAtMillis': date.millisecondsSinceEpoch,
        },
        {
          'id': 'two',
          'title': 'Song two',
          'artist': 'Artist',
          'albumTitle': 'Album',
        },
      ]),
      'songbrief_outside_library_plays_v1': jsonEncode([
        {
          'id': 'observed',
          'title': 'Observed',
          'playedAtMillis': date.millisecondsSinceEpoch,
          'lastPlayedAtMillis': date.millisecondsSinceEpoch,
        },
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    var container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    expect(container.read(supplementalHistoryProvider).totalPlayCount, 3);
    expect(container.read(supplementalHistoryProvider).undatedTrackCount, 2);
    expect(container.read(supplementalHistoryProvider).datedEvents.length, 1);
    await _settle();
    expect(
      preferences.getString(supplementalListeningHistoryPreferenceKey),
      isNotNull,
    );
    container.dispose();

    container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(supplementalHistoryProvider).totalPlayCount, 3);
  });

  test(
    'observations during async restoration merge with stored ledger',
    () async {
      final stored = const SupplementalListeningHistory.empty().ingest([
        _track(),
      ]);
      SharedPreferences.setMockInitialValues({
        supplementalListeningHistoryPreferenceKey: stored.encode(),
      });
      final preferences = await SharedPreferences.getInstance();
      final pending = Completer<SharedPreferences?>();
      final container = ProviderContainer(
        overrides: [
          musicDataPreferencesFallbackProvider.overrideWithValue(
            pending.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(supplementalHistoryProvider.notifier).ingest([
        _track(id: 'two'),
      ]);
      expect(container.read(supplementalHistoryProvider).totalPlayCount, 1);
      pending.complete(preferences);
      await _settle();
      expect(container.read(supplementalHistoryProvider).totalPlayCount, 2);
      expect(
        SupplementalListeningHistory.decode(
          preferences.getString(supplementalListeningHistoryPreferenceKey),
        ).totalPlayCount,
        2,
      );
    },
  );

  test('unavailable storage preserves incoming observations', () async {
    final container = ProviderContainer(
      overrides: [
        musicDataPreferencesLoaderProvider.overrideWithValue(
          () async => throw StateError('offline'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(supplementalHistoryProvider.notifier).ingest([_track()]);
    await _settle();
    expect(container.read(supplementalHistoryProvider).totalPlayCount, 1);
    expect(
      container.read(supplementalHistoryProvider).tracks.single.lastPlayedAt,
      isNull,
    );
  });
}
