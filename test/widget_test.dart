import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
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
    expect(find.byTooltip('Demo mode'), findsOneWidget);
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
    expect(find.byTooltip('デモモード'), findsOneWidget);
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

  testWidgets('opens track details from the mini player', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rankings'));
    await tester.pumpAndSettle();

    expect(find.text('Top Songs'), findsOneWidget);

    await tester.tap(find.byTooltip('Show current track details'));
    await tester.pumpAndSettle();

    expect(find.text('Top Songs'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.byTooltip('Play from beginning'), findsOneWidget);
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

  testWidgets('uses current library state as a provisional trend record', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 16);
    final yesterday = today.subtract(const Duration(days: 1));
    final currentTrack = LibraryTrack(
      id: 'provisional-track',
      title: 'Provisional Song',
      artist: 'SongBrief Artist',
      albumTitle: 'SongBrief Album',
      duration: const Duration(minutes: 3),
      playCount: 10,
      skipCount: 0,
      lastPlayedAt: today,
      isCloudItem: false,
    );
    final currentOverview = LibraryOverview.fromTracks([
      currentTrack,
    ], isDemo: false);
    final yesterdayOverview = LibraryOverview.fromTracks([
      currentTrack.copyWith(lastPlayedAt: yesterday),
    ], isDemo: false);
    final stats = MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
      overview: currentOverview,
      snapshotHistory: SnapshotHistory.empty.withSnapshot(
        DailyLibrarySnapshot.fromOverview(
          yesterdayOverview,
          capturedAt: yesterday,
        ),
      ),
      snapshotRecordingEnabled: true,
    );

    await _pumpApp(tester, AppLanguage.english, statsState: stats);
    await tester.pumpAndSettle();

    expect(find.text('Provisional Song'), findsWidgets);
    expect(find.text('This week trend'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('uses last played date when provisional trend delta is zero', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 16);
    final yesterday = today.subtract(const Duration(days: 1));
    final previousDay = today.subtract(const Duration(days: 2));
    final currentTrack = LibraryTrack(
      id: 'recent-fallback-track',
      title: 'Recent Fallback Song',
      artist: 'SongBrief Artist',
      albumTitle: 'SongBrief Album',
      duration: const Duration(minutes: 3),
      playCount: 10,
      skipCount: 0,
      lastPlayedAt: yesterday,
      isCloudItem: false,
    );
    final previousTrack = currentTrack.copyWith(lastPlayedAt: previousDay);
    final stats = MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
      overview: LibraryOverview.fromTracks([currentTrack], isDemo: false),
      snapshotHistory: SnapshotHistory.empty.withSnapshot(
        DailyLibrarySnapshot.fromOverview(
          LibraryOverview.fromTracks([previousTrack], isDemo: false),
          capturedAt: previousDay,
        ),
      ),
      snapshotRecordingEnabled: true,
    );

    await _pumpApp(tester, AppLanguage.english, statsState: stats);
    await tester.pumpAndSettle();

    expect(find.text('Recent Fallback Song'), findsWidgets);
    expect(find.text('This week trend'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
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
      ThemeMode.system,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
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

    await tester.ensureVisible(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flux'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, const Color(0xFF007486));
    expect(find.textContaining('Blue and mint'), findsOneWidget);
  });

  testWidgets('shows expanded theme and language choices in settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Grove'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Pulse'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pulse'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Muse'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Muse'), findsOneWidget);

    await tester.tap(find.text('Muse'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('简体中文 (Simplified Chinese)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('한국어 (Korean)'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('한국어 (Korean)'), findsOneWidget);
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
    expect(find.text('Active exclusions'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Hidden playlists'), findsNothing);

    await tester.ensureVisible(find.text('Manage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    expect(find.text('Manage hidden items'), findsOneWidget);
    expect(find.text('Hidden playlists'), findsOneWidget);
    expect(find.text('Playlists (0)'), findsOneWidget);
    expect(find.text('Genres (0)'), findsOneWidget);
    expect(find.text('Keywords (0)'), findsOneWidget);
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
  MusicStatsState? statsState,
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
        if (statsState != null)
          musicStatsControllerProvider.overrideWith(
            () => _FixedMusicStatsController(statsState),
          ),
      ],
      child: const SongBriefApp(),
    ),
  );
}

class _FixedMusicStatsController extends MusicStatsController {
  _FixedMusicStatsController(this.stats);

  final MusicStatsState stats;

  @override
  Future<MusicStatsState> build() async {
    return stats;
  }
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
