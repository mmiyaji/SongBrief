import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/settings/demo_library_preferences.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'injected preferences restore every music setting synchronously',
    () async {
      SharedPreferences.setMockInitialValues({
        snapshotRecordingEnabledPreferenceKey: false,
        snapshotCloudSyncEnabledPreferenceKey: false,
        snapshotDetailedLoggingEnabledPreferenceKey: true,
        temporaryDemoLibraryEnabledPreferenceKey: true,
        excludedPlaylistsPreferenceKey: ['Focus'],
        excludedGenresPreferenceKey: ['Ambient'],
        excludedKeywordsPreferenceKey: ['secret'],
      });
      final preferences = await SharedPreferences.getInstance();
      var fallbackCalls = 0;
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(preferences),
          musicDataPreferencesLoaderProvider.overrideWithValue(() {
            fallbackCalls += 1;
            return Future<SharedPreferences>.error(
              StateError('fallback must not run'),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final ready = container.read(musicDataPreferencesReadyProvider.future);

      expect(container.read(snapshotRecordingProvider), isFalse);
      expect(container.read(snapshotCloudSyncProvider), isFalse);
      expect(container.read(snapshotDetailedLoggingProvider), isTrue);
      expect(container.read(temporaryDemoLibraryProvider), isTrue);
      final filters = container.read(libraryFilterPreferencesProvider);
      expect(filters.excludedPlaylists, ['Focus']);
      expect(filters.excludedGenres, ['Ambient']);
      expect(filters.excludedKeywords, ['secret']);
      expect(fallbackCalls, 0);

      await ready.timeout(const Duration(seconds: 1));
      expect(fallbackCalls, 0);
    },
  );

  test('uninjected preferences use the asynchronous fallback', () async {
    SharedPreferences.setMockInitialValues({
      snapshotRecordingEnabledPreferenceKey: false,
      snapshotCloudSyncEnabledPreferenceKey: false,
      snapshotDetailedLoggingEnabledPreferenceKey: true,
      temporaryDemoLibraryEnabledPreferenceKey: true,
      excludedGenresPreferenceKey: ['Ambient'],
    });
    final preferences = await SharedPreferences.getInstance();
    final loadedPreferences = Completer<SharedPreferences>();
    var fallbackCalls = 0;
    final container = ProviderContainer(
      overrides: [
        musicDataPreferencesLoaderProvider.overrideWithValue(() {
          fallbackCalls += 1;
          return loadedPreferences.future;
        }),
      ],
    );
    addTearDown(container.dispose);

    final ready = container.read(musicDataPreferencesReadyProvider.future);

    expect(container.read(snapshotRecordingProvider), isTrue);
    expect(container.read(snapshotCloudSyncProvider), isTrue);
    expect(container.read(snapshotDetailedLoggingProvider), isFalse);
    expect(container.read(temporaryDemoLibraryProvider), isFalse);
    expect(container.read(libraryFilterPreferencesProvider).isEmpty, isTrue);

    loadedPreferences.complete(preferences);
    await ready.timeout(const Duration(seconds: 1));

    expect(fallbackCalls, 1);
    expect(container.read(snapshotRecordingProvider), isFalse);
    expect(container.read(snapshotCloudSyncProvider), isFalse);
    expect(container.read(snapshotDetailedLoggingProvider), isTrue);
    expect(container.read(temporaryDemoLibraryProvider), isTrue);
    expect(container.read(libraryFilterPreferencesProvider).excludedGenres, [
      'Ambient',
    ]);
  });

  test('fallback failures still complete music preference readiness', () async {
    var fallbackCalls = 0;
    final container = ProviderContainer(
      overrides: [
        musicDataPreferencesLoaderProvider.overrideWithValue(() async {
          fallbackCalls += 1;
          throw StateError('preferences unavailable');
        }),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(musicDataPreferencesReadyProvider.future)
        .timeout(const Duration(seconds: 1));

    expect(fallbackCalls, 1);
    expect(container.read(snapshotRecordingProvider), isTrue);
    expect(container.read(snapshotCloudSyncProvider), isTrue);
    expect(container.read(snapshotDetailedLoggingProvider), isFalse);
    expect(container.read(temporaryDemoLibraryProvider), isFalse);
    expect(container.read(libraryFilterPreferencesProvider).isEmpty, isTrue);
  });

  test(
    'hung fallbacks time out to safe defaults',
    () async {
      final neverCompletes = Completer<SharedPreferences>();
      final container = ProviderContainer(
        overrides: [
          musicDataPreferencesLoaderProvider.overrideWithValue(
            () => neverCompletes.future,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(musicDataPreferencesReadyProvider.future)
          .timeout(const Duration(seconds: 3));

      expect(container.read(snapshotRecordingProvider), isTrue);
      expect(container.read(snapshotCloudSyncProvider), isTrue);
      expect(container.read(snapshotDetailedLoggingProvider), isFalse);
      expect(container.read(temporaryDemoLibraryProvider), isFalse);
      expect(container.read(libraryFilterPreferencesProvider).isEmpty, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('overridden preference controllers do not block readiness', () async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
        snapshotRecordingProvider.overrideWith(
          () => _FixedSnapshotRecordingController(false),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(musicDataPreferencesReadyProvider.future)
        .timeout(const Duration(seconds: 1));

    expect(container.read(snapshotRecordingProvider), isFalse);
  });

  test('malformed injected values fall back independently', () async {
    SharedPreferences.setMockInitialValues({
      snapshotRecordingEnabledPreferenceKey: 'invalid',
      snapshotCloudSyncEnabledPreferenceKey: 1,
      snapshotDetailedLoggingEnabledPreferenceKey: 'invalid',
      temporaryDemoLibraryEnabledPreferenceKey: 'invalid',
      excludedPlaylistsPreferenceKey: 'invalid',
      excludedGenresPreferenceKey: ['Ambient'],
      excludedKeywordsPreferenceKey: 1,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(musicDataPreferencesReadyProvider.future)
        .timeout(const Duration(seconds: 1));

    expect(container.read(snapshotRecordingProvider), isTrue);
    expect(container.read(snapshotCloudSyncProvider), isTrue);
    expect(container.read(snapshotDetailedLoggingProvider), isFalse);
    expect(container.read(temporaryDemoLibraryProvider), isFalse);
    final filters = container.read(libraryFilterPreferencesProvider);
    expect(filters.excludedPlaylists, isEmpty);
    expect(filters.excludedGenres, ['Ambient']);
    expect(filters.excludedKeywords, isEmpty);
  });
}

class _FixedSnapshotRecordingController extends SnapshotRecordingController {
  _FixedSnapshotRecordingController(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}
