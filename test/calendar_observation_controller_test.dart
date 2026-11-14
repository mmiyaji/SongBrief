import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

LibraryTrack _track({String id = 'outside', DateTime? at}) => LibraryTrack(
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

  test(
    'record observations keep one play and the first observation date',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      final first = DateTime.utc(2026, 10, 4);
      final second = DateTime.utc(2026, 10, 6);
      final controller = container.read(outsideLibraryPlaysProvider.notifier);

      controller.record(_track(at: DateTime.utc(2020)), at: first);
      controller.record(_track(at: DateTime.utc(2021)), at: second);

      final history = container.read(supplementalHistoryProvider);
      expect(history.totalPlayCount, 1);
      expect(history.observedEvents, hasLength(1));
      expect(history.observedEvents.single.playedAt, first);
      expect(history.datedEvents, isEmpty);
      expect(
        container.read(outsideLibraryPlaysProvider).single.lastPlayedAt,
        second,
      );
    },
  );

  test(
    'later actual MusicKit time replaces observation without adding a play',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final observedAt = DateTime.utc(2026, 10, 4);
      final actualAt = DateTime.utc(2026, 10, 7);
      final history = container.read(supplementalHistoryProvider.notifier);

      history.observe(_track(), at: observedAt);
      history.ingest([_track(at: actualAt)]);

      final result = container.read(supplementalHistoryProvider);
      expect(result.totalPlayCount, 1);
      expect(result.observedEvents, isEmpty);
      expect(result.datedEvents.single.playedAt, actualAt);
      expect(result.calendarEvents.single.playedAt, actualAt);
    },
  );

  test('legacy outside cache seeds oldest dated observation once', () async {
    final older = DateTime.utc(2026, 10, 2);
    final newer = DateTime.utc(2026, 10, 5);
    final existingLedger = const SupplementalListeningHistory.empty().ingest([
      _track(id: 'existing', at: DateTime.utc(2026, 9, 30)),
    ]);
    SharedPreferences.setMockInitialValues({
      supplementalListeningHistoryPreferenceKey: existingLedger.encode(),
      'songbrief_outside_library_plays_v1': jsonEncode([
        {
          'id': 'outside',
          'title': 'Song outside',
          'artist': 'Artist',
          'albumTitle': 'Album',
          'durationSeconds': 200,
          'playedAtMillis': newer.millisecondsSinceEpoch,
        },
        {
          'id': 'outside',
          'title': 'Song outside',
          'artist': 'Artist',
          'albumTitle': 'Album',
          'durationSeconds': 200,
          'playedAtMillis': older.millisecondsSinceEpoch,
        },
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(supplementalHistoryProvider).totalPlayCount, 2);
    expect(
      container
          .read(supplementalHistoryProvider)
          .observedEvents
          .single
          .playedAt,
      older,
    );
    await _settle();
    container.invalidate(supplementalHistoryProvider);
    expect(container.read(supplementalHistoryProvider).totalPlayCount, 2);
    expect(
      container
          .read(supplementalHistoryProvider)
          .observedEvents
          .single
          .playedAt,
      older,
    );
  });

  test('outside cache without timestamp remains undated', () async {
    SharedPreferences.setMockInitialValues({
      'songbrief_outside_library_plays_v1': jsonEncode([
        {'id': 'outside', 'title': 'Song outside', 'artist': 'Artist'},
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    final history = container.read(supplementalHistoryProvider);
    expect(history.totalPlayCount, 1);
    expect(history.undatedTrackCount, 1);
    expect(history.calendarEvents, isEmpty);
  });

  test(
    'queued ingest and observation retain operation order during restore',
    () async {
      final observedAt = DateTime.utc(2026, 10, 2);
      final actualAt = DateTime.utc(2026, 10, 8);
      final pending = Completer<SharedPreferences?>();
      final container = ProviderContainer(
        overrides: [
          musicDataPreferencesFallbackProvider.overrideWithValue(
            pending.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(supplementalHistoryProvider.notifier);
      controller.observe(_track(), at: observedAt);
      controller.ingest([_track(at: actualAt)]);

      SharedPreferences.setMockInitialValues({});
      pending.complete(await SharedPreferences.getInstance());
      await _settle();

      final history = container.read(supplementalHistoryProvider);
      expect(history.totalPlayCount, 1);
      expect(history.observedEvents, isEmpty);
      expect(history.datedEvents.single.playedAt, actualAt);
    },
  );
}
