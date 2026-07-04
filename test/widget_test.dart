import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';

void main() {
  testWidgets('shows the SongBrief dashboard shell in English', (tester) async {
    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    expect(find.text('SongBrief'), findsOneWidget);
    expect(find.text('Skyline Echo'), findsWidgets);
    expect(find.text('Plays'), findsWidgets);
    expect(find.text('This week trend'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.textContaining('City lights are waking slow'), findsOneWidget);
    expect(find.text('Show all lyrics'), findsOneWidget);
    expect(find.text('Recently played songs'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('expands and collapses long lyrics', (tester) async {
    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    expect(find.text('Show all lyrics'), findsOneWidget);

    await tester.ensureVisible(find.text('Show all lyrics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all lyrics'));
    await tester.pumpAndSettle();

    expect(find.text('Show less'), findsOneWidget);

    await tester.ensureVisible(find.text('Show less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(find.text('Show all lyrics'), findsOneWidget);
  });

  testWidgets('shows the SongBrief dashboard shell in Japanese', (
    tester,
  ) async {
    await _pumpApp(tester, AppLanguage.japanese);
    await tester.pumpAndSettle();

    expect(find.text('SongBrief'), findsOneWidget);
    expect(find.text('Skyline Echo'), findsWidgets);
    expect(find.text('再生回数'), findsWidgets);
    expect(find.text('今週の傾向'), findsOneWidget);
    expect(find.text('最近再生した曲'), findsOneWidget);
    expect(find.text('デモ'), findsOneWidget);
  });

  testWidgets('shows playback feedback and allows pausing from the player', (
    tester,
  ) async {
    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Play this track').first);
    await tester.pumpAndSettle();

    expect(find.text('Playing now'), findsWidgets);
    expect(find.byTooltip('Pause'), findsWidgets);

    await tester.tap(find.byTooltip('Pause').first);
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsWidgets);
  });

  testWidgets('opens the playing tab from the mini player', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rankings'));
    await tester.pumpAndSettle();

    expect(find.text('Top Songs'), findsOneWidget);

    await tester.tap(find.byTooltip('Open current track'));
    await tester.pumpAndSettle();

    expect(find.text('This week trend'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
  });

  testWidgets('opens trend calculation details from the info button', (
    tester,
  ) async {
    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('About this trend'));
    await tester.pumpAndSettle();

    expect(find.text('How this trend is calculated'), findsOneWidget);
    expect(
      find.textContaining('compares daily listening records'),
      findsOneWidget,
    );
  });

  testWidgets('switches to the light appearance from settings', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });

  testWidgets('switches to the flux theme from settings', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flux'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, const Color(0xFF007486));
    expect(find.textContaining('Blue and mint'), findsOneWidget);
  });

  testWidgets('shows library exclusion controls in settings', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Display & Exclusions'), findsOneWidget);
    expect(find.text('Hidden playlists'), findsOneWidget);
    expect(find.text('Hidden genres'), findsOneWidget);
    expect(find.text('Hidden keywords'), findsOneWidget);
    expect(find.text('Active exclusions'), findsOneWidget);
  });

  testWidgets('hides record-based panels when daily records are off', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(AppLanguage.english),
        ),
        snapshotRecordingProvider.overrideWith(
          () => _FixedSnapshotRecordingController(false),
        ),
      ],
    );

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This week trend'), findsNothing);

      container
          .read(homeSectionProvider.notifier)
          .setSection(HomeSection.overview);
      await tester.pumpAndSettle();

      expect(find.text('Daily listening records'), findsNothing);
      expect(find.text('Recap highlights'), findsNothing);
      expect(find.text('Activity heatmap'), findsNothing);
      expect(find.text('Listening maps'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    }
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppLanguage language, {
  bool snapshotRecordingEnabled = true,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(language),
        ),
        snapshotRecordingProvider.overrideWith(
          () => _FixedSnapshotRecordingController(snapshotRecordingEnabled),
        ),
      ],
      child: const SongBriefApp(),
    ),
  );
}

class _FixedLanguageController extends AppLanguageController {
  _FixedLanguageController(this.language);

  final AppLanguage language;

  @override
  AppLanguage build() {
    return language;
  }
}

class _FixedSnapshotRecordingController extends SnapshotRecordingController {
  _FixedSnapshotRecordingController(this.enabled);

  final bool enabled;

  @override
  bool build() {
    return enabled;
  }
}
