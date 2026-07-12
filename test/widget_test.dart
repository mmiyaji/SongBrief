import 'dart:async';

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
    expect(find.text('Listening trend'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.textContaining('City lights are waking slow'), findsOneWidget);
    expect(find.text('Show all lyrics'), findsOneWidget);
    expect(find.text('Recently played songs'), findsOneWidget);
    expect(_tooltipStartingWith('Demo mode'), findsOneWidget);
    expect(find.text('#1 by plays'), findsOneWidget);
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
    expect(find.text('再生傾向'), findsOneWidget);
    expect(find.text('最近再生した曲'), findsOneWidget);
    expect(_tooltipStartingWith('デモモード'), findsOneWidget);
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

  testWidgets('offers subtle previous and next controls on the hero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _HeroTransportPlaybackController();

    await _pumpApp(
      tester,
      AppLanguage.english,
      playbackControllerBuilder: () => controller,
    );
    await tester.pumpAndSettle();

    final controls = find.byKey(const ValueKey('hero-transport-controls'));
    final previous = find.descendant(
      of: controls,
      matching: find.byTooltip('Previous'),
    );
    final next = find.descendant(
      of: controls,
      matching: find.byTooltip('Next'),
    );
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);

    await tester.tap(previous);
    await tester.tap(next);
    expect(controller.previousCalls, 1);
    expect(controller.nextCalls, 1);
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

  testWidgets('keeps mobile overview content clear of playback chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    final listeningMaps = find.byKey(const ValueKey('overview-listening-maps'));
    expect(listeningMaps, findsNothing);
    await _scrollOverviewUntilVisible(tester, listeningMaps);
    expect(listeningMaps, findsOneWidget);

    final insightsPanel = find.byKey(const ValueKey('overview-insights'));
    await _scrollOverviewUntilVisible(tester, insightsPanel);
    expect(find.byKey(const ValueKey('overview-insight-5')), findsOneWidget);

    final smartListsPanel = find.byKey(const ValueKey('overview-smart-lists'));
    await _scrollOverviewUntilVisible(tester, smartListsPanel);
    expect(find.byKey(const ValueKey('overview-smart-list-3')), findsOneWidget);

    final adSlot = find.byKey(const ValueKey('overview-ad-slot'));
    await _scrollOverviewUntilVisible(tester, adSlot);
    final playbackChrome = find.byKey(const ValueKey('mobile-playback-chrome'));
    expect(
      tester.getBottomRight(adSlot).dy,
      lessThanOrEqualTo(tester.getTopLeft(playbackChrome).dy - 12),
    );
  });

  testWidgets('bounds pull refresh feedback when data loading is delayed', (
    tester,
  ) async {
    final controller = _NeverCompletingRefreshController(_settingsDemoStats());
    await _pumpApp(
      tester,
      AppLanguage.english,
      musicStatsControllerBuilder: () => controller,
    );
    await tester.pumpAndSettle();

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    var completed = false;
    final refresh = indicator.onRefresh().whenComplete(() => completed = true);

    await tester.pump(const Duration(seconds: 11));
    expect(completed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await refresh;
    expect(completed, isTrue);

    controller.completeRefresh();
  });

  testWidgets('shows last data refresh and clips access button feedback', (
    tester,
  ) async {
    final base = _settingsDemoStats();
    final stats = MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
      overview: LibraryOverview.fromTracks(base.overview.tracks, isDemo: false),
      snapshotHistory: base.snapshotHistory,
      lastDataRefreshAt: DateTime(2026, 7, 12, 10, 51),
    );
    await _pumpApp(tester, AppLanguage.english, statsState: stats);
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('music-access-status-button'));
    final material = tester.widget<Material>(button);
    expect(material.borderRadius, BorderRadius.circular(18));
    expect(material.clipBehavior, Clip.antiAlias);

    await tester.tap(button);
    await tester.pump();
    expect(find.textContaining('Apple Music authorized'), findsOneWidget);
    expect(find.textContaining('Last data update'), findsOneWidget);
  });

  testWidgets('fits overview and navigation on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.japanese);
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.destinations.cast<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      ['再生', '概要', '順位', '曲', '設定'],
    );

    await tester.tap(find.text('概要'));
    await tester.pumpAndSettle();
    final lastInsight = find.byKey(const ValueKey('overview-insight-5'));
    await _scrollOverviewUntilVisible(tester, lastInsight, step: 420);
    expect(tester.getSize(lastInsight).height, 92);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('順位'));
    await tester.pumpAndSettle();
    final scopeSelector = find.byType(SegmentedButton<RankingScope>);
    expect(scopeSelector, findsOneWidget);
    expect(tester.getTopLeft(scopeSelector).dx, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(scopeSelector).dx, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts large overview values and exposes their full text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const track = LibraryTrack(
      id: 'large-values-track',
      title: 'A deliberately long track title for overflow verification',
      artist: 'Large Library Artist',
      albumTitle: 'Large Library Album',
      duration: Duration(hours: 24),
      playCount: 200000,
      skipCount: 123456,
      isCloudItem: false,
    );
    final stats = MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
      overview: LibraryOverview.fromTracks(const [track], isDemo: false),
      snapshotHistory: SnapshotHistory.empty,
    );

    await _pumpApp(tester, AppLanguage.english, statsState: stats);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    final hoursTile = find.byKey(const ValueKey('overview-signal-Hours'));
    expect(hoursTile, findsOneWidget);
    expect(
      find.descendant(of: hoursTile, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: hoursTile,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip &&
              widget.message?.startsWith('Hours: ') == true &&
              !widget.message!.contains('…'),
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates open track details when playback skips to next', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracks = [
      LibraryTrack(
        id: 'first-track',
        title: 'First Track',
        artist: 'Test Artist',
        albumTitle: 'Test Album',
        duration: const Duration(minutes: 3),
        playCount: 2,
        skipCount: 0,
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'next-track',
        title: 'Next Track',
        artist: 'Test Artist',
        albumTitle: 'Test Album',
        duration: const Duration(minutes: 4),
        playCount: 1,
        skipCount: 0,
        isCloudItem: false,
      ),
    ];
    final stats = MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
      overview: LibraryOverview.fromTracks(tracks, isDemo: false),
      snapshotHistory: SnapshotHistory.empty,
      snapshotRecordingEnabled: true,
    );

    await _pumpApp(
      tester,
      AppLanguage.english,
      statsState: stats,
      playbackControllerBuilder: _NextTrackPlaybackController.new,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show current track details'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('First Track')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: sheet, matching: find.byTooltip('Next')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: sheet, matching: find.text('Next Track')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('First Track')),
      findsNothing,
    );
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
    expect(find.text('Listening trend'), findsOneWidget);
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
    expect(find.text('Listening trend'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('selects the first trend range with recent playback', (
    tester,
  ) async {
    final now = DateTime.now();
    final stats = _trendStats(
      lastPlayedAt: now.subtract(const Duration(days: 14)),
    );

    await _pumpApp(tester, AppLanguage.english, statsState: stats);
    await tester.pumpAndSettle();

    final selector = tester.widget<SegmentedButton<TrendRange>>(
      find.byType(SegmentedButton<TrendRange>),
    );
    expect(selector.selected, {TrendRange.month});
  });

  testWidgets('shows a useful empty trend beyond the last year', (
    tester,
  ) async {
    final now = DateTime.now();
    final stats = _trendStats(
      lastPlayedAt: now.subtract(const Duration(days: 400)),
    );

    await _pumpApp(tester, AppLanguage.english, statsState: stats);
    await tester.pumpAndSettle();

    final selector = tester.widget<SegmentedButton<TrendRange>>(
      find.byType(SegmentedButton<TrendRange>),
    );
    expect(selector.selected, {TrendRange.year});
    expect(
      find.text('This song has not been played in the last year.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the actual play-count rank on the hero artwork', (
    tester,
  ) async {
    final now = DateTime.now();
    final stats = MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
      overview: LibraryOverview.fromTracks([
        LibraryTrack(
          id: 'rank-one',
          title: 'Older Favorite',
          artist: 'Test Artist',
          albumTitle: 'Test Album',
          duration: const Duration(minutes: 3),
          playCount: 100,
          skipCount: 0,
          lastPlayedAt: now.subtract(const Duration(days: 3)),
          isCloudItem: false,
        ),
        LibraryTrack(
          id: 'rank-two',
          title: 'Current Song',
          artist: 'Test Artist',
          albumTitle: 'Test Album',
          duration: const Duration(minutes: 3),
          playCount: 5,
          skipCount: 0,
          lastPlayedAt: now,
          isCloudItem: false,
        ),
      ], isDemo: false),
      snapshotHistory: SnapshotHistory.empty,
    );

    await _pumpApp(tester, AppLanguage.english, statsState: stats);
    await tester.pumpAndSettle();

    expect(find.text('#2 by plays'), findsOneWidget);
    expect(find.text('#1 Song'), findsNothing);
  });

  testWidgets('opens playing from the tablet rail track shortcut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    final shortcut = find.byKey(const ValueKey('rail-now-playing-shortcut'));
    expect(shortcut, findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      HomeSection.settings.index,
    );

    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      HomeSection.playing.index,
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

  testWidgets('preference sheets announce the selected option', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await _pumpApp(
      tester,
      AppLanguage.english,
      statsState: _settingsDemoStats(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ember'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    final selectedEmber = find.bySemanticsLabel('Ember');
    expect(selectedEmber, findsOneWidget);
    expect(
      tester.getSemantics(selectedEmber),
      isSemantics(
        label: 'Ember',
        hint: 'Pink and amber music-focused theme.',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('demo history is labeled as sample data and cannot be managed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(
      tester,
      AppLanguage.english,
      statsState: _settingsDemoStats(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final sampleRecords = find.text('Sample records');
    await tester.scrollUntilVisible(
      sampleRecords,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(sampleRecords, findsOneWidget);
    final manageRecords = find.widgetWithText(OutlinedButton, 'Manage records');
    expect(manageRecords, findsOneWidget);
    expect(tester.widget<OutlinedButton>(manageRecords).onPressed, isNull);
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

  testWidgets('keeps scroll positions independent between tabs', (
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();
    final settingsScrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(settingsScrollable.position.pixels, greaterThan(0));

    await tester.tap(find.text('Playing'));
    await tester.pumpAndSettle();

    final playingScrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(playingScrollable.position.pixels, 0);
    expect(find.text('Skyline Echo'), findsWidgets);
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

      expect(find.text('Listening trend'), findsNothing);

      container
          .read(homeSectionProvider.notifier)
          .setSection(HomeSection.overview);
      await tester.pumpAndSettle();

      final listeningMaps = find.text('Listening maps');
      await _scrollOverviewUntilVisible(tester, listeningMaps);

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

Future<void> _scrollOverviewUntilVisible(
  WidgetTester tester,
  Finder target, {
  double step = 520,
}) async {
  final scrollView = find.byType(CustomScrollView);
  for (var attempt = 0; attempt < 30; attempt += 1) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollView, Offset(0, -step));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppLanguage language, {
  bool snapshotRecordingEnabled = true,
  MusicStatsState? statsState,
  MusicStatsController Function()? musicStatsControllerBuilder,
  PlaybackController Function()? playbackControllerBuilder,
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
        if (musicStatsControllerBuilder != null)
          musicStatsControllerProvider.overrideWith(musicStatsControllerBuilder)
        else if (statsState != null)
          musicStatsControllerProvider.overrideWith(
            () => _FixedMusicStatsController(statsState),
          ),
        if (playbackControllerBuilder != null)
          playbackControllerProvider.overrideWith(playbackControllerBuilder),
      ],
      child: const SongBriefApp(),
    ),
  );
}

Finder _tooltipStartingWith(String prefix) {
  return find.byWidgetPredicate(
    (widget) => widget is Tooltip && widget.message?.startsWith(prefix) == true,
  );
}

class _NextTrackPlaybackController extends PlaybackController {
  @override
  PlaybackState build() {
    return const PlaybackState(activeTrackId: 'first-track', isPlaying: true);
  }

  @override
  Future<void> skipToNext() async {
    state = const PlaybackState(activeTrackId: 'next-track', isPlaying: true);
  }
}

class _HeroTransportPlaybackController extends PlaybackController {
  var previousCalls = 0;
  var nextCalls = 0;

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> skipToPrevious() async {
    previousCalls += 1;
  }

  @override
  Future<void> skipToNext() async {
    nextCalls += 1;
  }
}

class _FixedMusicStatsController extends MusicStatsController {
  _FixedMusicStatsController(this.stats);

  final MusicStatsState stats;

  @override
  Future<MusicStatsState> build() async {
    return stats;
  }
}

class _NeverCompletingRefreshController extends MusicStatsController {
  _NeverCompletingRefreshController(this.stats);

  final MusicStatsState stats;
  final Completer<void> _refresh = Completer<void>();

  @override
  Future<MusicStatsState> build() async => stats;

  @override
  Future<void> refreshStatsSilently() => _refresh.future;

  void completeRefresh() {
    if (!_refresh.isCompleted) {
      _refresh.complete();
    }
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

MusicStatsState _settingsDemoStats() {
  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
    overview: LibraryOverview.fromTracks([
      LibraryTrack(
        id: 'settings-demo-track',
        title: 'Settings Demo Track',
        artist: 'Demo Artist',
        albumTitle: 'Demo Album',
        playCount: 8,
        skipCount: 1,
        duration: const Duration(minutes: 3),
        isCloudItem: false,
      ),
    ], isDemo: true),
    snapshotHistory: SnapshotHistory.empty,
    snapshotRecordingEnabled: true,
  );
}

MusicStatsState _trendStats({required DateTime lastPlayedAt}) {
  final now = DateTime.now();
  final track = LibraryTrack(
    id: 'trend-range-track',
    title: 'Trend Range Song',
    artist: 'Test Artist',
    albumTitle: 'Test Album',
    duration: const Duration(minutes: 3),
    playCount: 10,
    skipCount: 0,
    lastPlayedAt: lastPlayedAt,
    isCloudItem: false,
  );
  final previousCapturedAt = now.subtract(const Duration(days: 1));
  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: LibraryOverview.fromTracks([track], isDemo: false),
    snapshotHistory: SnapshotHistory.empty.withSnapshot(
      DailyLibrarySnapshot.fromOverview(
        LibraryOverview.fromTracks([track], isDemo: false),
        capturedAt: previousCapturedAt,
      ),
    ),
  );
}
