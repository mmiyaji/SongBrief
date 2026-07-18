import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/theme/app_theme.dart';

void main() {
  test('uses system appearance by default', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(themeBrightnessProvider),
      SongBriefThemeBrightness.system,
    );
    expect(container.read(appLanguageProvider), AppLanguage.system);
  });

  test('restores saved theme and language preferences', () async {
    SharedPreferences.setMockInitialValues({
      'songbrief_theme_style_v1': 'ember',
      'songbrief_theme_brightness_v1': 'light',
      'songbrief_app_language_v1': 'japanese',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeStyleProvider);
    container.read(themeBrightnessProvider);
    container.read(appLanguageProvider);
    await _drainPreferenceRestore();

    expect(container.read(themeStyleProvider), SongBriefThemeStyle.ember);
    expect(
      container.read(themeBrightnessProvider),
      SongBriefThemeBrightness.light,
    );
    expect(container.read(appLanguageProvider), AppLanguage.japanese);
  });

  test('saves theme and language preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(themeStyleProvider.notifier)
        .setStyle(SongBriefThemeStyle.mono);
    container
        .read(themeBrightnessProvider.notifier)
        .setBrightness(SongBriefThemeBrightness.system);
    container
        .read(appLanguageProvider.notifier)
        .setLanguage(AppLanguage.english);

    await _drainPreferenceRestore();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('songbrief_theme_style_v1'), 'mono');
    expect(preferences.getString('songbrief_theme_brightness_v1'), 'system');
    expect(preferences.getString('songbrief_app_language_v1'), 'english');
  });

  test('restores and saves daily listening record preference', () async {
    SharedPreferences.setMockInitialValues({
      snapshotRecordingEnabledPreferenceKey: false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(snapshotRecordingProvider), isTrue);
    await _drainPreferenceRestore();
    expect(container.read(snapshotRecordingProvider), isFalse);

    await container.read(snapshotRecordingProvider.notifier).setEnabled(true);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(snapshotRecordingEnabledPreferenceKey), isTrue);
    expect(container.read(snapshotRecordingProvider), isTrue);
  });

  test('restores and saves detailed background log preference', () async {
    SharedPreferences.setMockInitialValues({
      snapshotDetailedLoggingEnabledPreferenceKey: true,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(snapshotDetailedLoggingProvider), isFalse);
    await _drainPreferenceRestore();
    expect(container.read(snapshotDetailedLoggingProvider), isTrue);

    await container
        .read(snapshotDetailedLoggingProvider.notifier)
        .setEnabled(false);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(snapshotDetailedLoggingEnabledPreferenceKey),
      isFalse,
    );
    expect(container.read(snapshotDetailedLoggingProvider), isFalse);
  });

  test('malformed detailed background log preference stays disabled', () async {
    SharedPreferences.setMockInitialValues({
      snapshotDetailedLoggingEnabledPreferenceKey: 'invalid',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(snapshotDetailedLoggingProvider);
    await _drainPreferenceRestore();

    expect(container.read(snapshotDetailedLoggingProvider), isFalse);
  });
}

Future<void> _drainPreferenceRestore() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
