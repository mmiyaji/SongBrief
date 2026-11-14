import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/supplemental_history_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to included when the setting is absent', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [musicDataSharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
    await container.read(supplementalHistoryIncludedProvider.notifier).restored;
    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
  });

  test(
    'restores both persisted choices and persists across containers',
    () async {
      SharedPreferences.setMockInitialValues({
        supplementalHistoryIncludedPreferenceKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      var container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      expect(container.read(supplementalHistoryIncludedProvider), isFalse);
      expect(
        await container
            .read(supplementalHistoryIncludedProvider.notifier)
            .setEnabled(true),
        isTrue,
      );
      container.dispose();

      container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(supplementalHistoryIncludedProvider), isTrue);
      expect(
        await container
            .read(supplementalHistoryIncludedProvider.notifier)
            .setEnabled(false),
        isTrue,
      );
      expect(prefs.getBool(supplementalHistoryIncludedPreferenceKey), isFalse);
    },
  );

  test('late fallback restore does not override a user choice', () async {
    SharedPreferences.setMockInitialValues({
      supplementalHistoryIncludedPreferenceKey: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final pending = Completer<SharedPreferences?>();
    final container = ProviderContainer(
      overrides: [
        musicDataPreferencesFallbackProvider.overrideWithValue(pending.future),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      supplementalHistoryIncludedProvider.notifier,
    );
    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
    final changed = controller.setEnabled(true);
    pending.complete(prefs);
    expect(await changed, isTrue);
    await controller.restored;
    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
  });

  test('failed save returns false and rolls back the current change', () async {
    final container = ProviderContainer(
      overrides: [
        musicDataPreferencesLoaderProvider.overrideWithValue(
          () async => throw StateError('storage unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      supplementalHistoryIncludedProvider.notifier,
    );
    expect(await controller.setEnabled(false), isFalse);
    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
  });

  test('rapid writes persist in order and retain the latest value', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [musicDataSharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      supplementalHistoryIncludedProvider.notifier,
    );

    final first = controller.setEnabled(false);
    final second = controller.setEnabled(true);
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
    expect(prefs.getBool(supplementalHistoryIncludedPreferenceKey), isTrue);
  });

  test('rapid failed writes roll back to the last persisted value', () async {
    final container = ProviderContainer(
      overrides: [
        musicDataPreferencesLoaderProvider.overrideWithValue(
          () async => throw StateError('storage unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      supplementalHistoryIncludedProvider.notifier,
    );

    final first = controller.setEnabled(false);
    final second = controller.setEnabled(true);
    expect(await first, isFalse);
    expect(await second, isFalse);
    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
  });
}
