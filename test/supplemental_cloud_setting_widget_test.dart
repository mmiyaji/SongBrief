import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';

void main() {
  testWidgets('iCloud history control stays usable without daily snapshots', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      snapshotRecordingEnabledPreferenceKey: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(prefs),
        appLanguageProvider.overrideWith(_English.new),
        trackArtworkProvider.overrideWith((ref, id) async => null),
        trackLyricsProvider.overrideWith((ref, id) async => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SongBriefApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final title = find.text('Sync records with iCloud');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    final tile = find.ancestor(
      of: title,
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(tile).onChanged, isNotNull);
    expect(
      find.textContaining('including confirmed plays outside your library'),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(container.read(snapshotCloudSyncProvider), isFalse);
    expect(prefs.getBool(snapshotCloudSyncEnabledPreferenceKey), isFalse);
    expect(container.read(snapshotRecordingProvider), isFalse);
  });
}

class _English extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
