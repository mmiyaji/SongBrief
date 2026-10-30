import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/supplemental_history_preferences.dart';

void main() {
  testWidgets('recommended supplemental history setting persists both states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
        appLanguageProvider.overrideWith(() => _EnglishLanguageController()),
        trackArtworkProvider.overrideWith((ref, id) async => null),
        trackLyricsProvider.overrideWith((ref, id) async => null),
      ],
    );
    addTearDown(container.dispose);
    container.read(supplementalHistoryProvider.notifier).ingest([
      _historyTrack,
    ]);
    expect(container.read(supplementalHistoryProvider).totalPlayCount, 1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SongBriefApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final settingTitle = find.text(
      'Include plays outside your library (recommended)',
    );
    await tester.ensureVisible(settingTitle);
    await tester.pumpAndSettle();
    expect(settingTitle, findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.ancestor(
              of: settingTitle,
              matching: find.byType(SwitchListTile),
            ),
          )
          .value,
      isTrue,
    );

    final settingSwitch = find.descendant(
      of: find.ancestor(
        of: settingTitle,
        matching: find.byType(SwitchListTile),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(settingSwitch);
    await tester.pumpAndSettle();
    expect(container.read(supplementalHistoryIncludedProvider), isFalse);
    expect(
      preferences.getBool(supplementalHistoryIncludedPreferenceKey),
      isFalse,
    );
    expect(container.read(supplementalHistoryProvider).totalPlayCount, 1);
    final restoredOff = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    expect(restoredOff.read(supplementalHistoryIncludedProvider), isFalse);
    restoredOff.dispose();

    await tester.tap(settingSwitch);
    await tester.pumpAndSettle();
    expect(container.read(supplementalHistoryIncludedProvider), isTrue);
    expect(
      preferences.getBool(supplementalHistoryIncludedPreferenceKey),
      isTrue,
    );
    expect(container.read(supplementalHistoryProvider).totalPlayCount, 1);
    final restoredOn = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    expect(restoredOn.read(supplementalHistoryIncludedProvider), isTrue);
    restoredOn.dispose();
  });
}

final _historyTrack = LibraryTrack(
  id: 'supplemental-setting-test',
  title: 'History Track',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: const Duration(minutes: 3),
  playCount: 4,
  skipCount: 0,
  isCloudItem: false,
);

class _EnglishLanguageController extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
