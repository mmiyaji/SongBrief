import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  testWidgets('opens stat-backed track lists from overview cards', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final tracksCard = find.text('Tracks').first;
    final tracksAction = find
        .ancestor(of: tracksCard, matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(tracksAction);
    await tester.pumpAndSettle();
    await tester.tap(tracksAction);
    await tester.pumpAndSettle();

    expect(find.text('All songs'), findsOneWidget);
    expect(find.textContaining('Library tracks'), findsOneWidget);
  });

  testWidgets('opens a smart list as a track list', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final smartList = find.text('High skip rate');
    await tester.scrollUntilVisible(
      smartList,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(smartList);
    await tester.pumpAndSettle();

    expect(find.text('High skip rate'), findsNWidgets(2));
    expect(find.textContaining('Songs with repeated skips'), findsWidgets);
  });

  testWidgets('opens the expanded listening maps view', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    await _scrollOverviewUntilVisible(tester, find.text('Listening maps'));
    expect(find.text('Listening maps'), findsOneWidget);
    expect(find.text('Tap a year point'), findsOneWidget);

    await _openExpandedListeningMaps(tester);

    expect(find.text('Genre stack by release year'), findsOneWidget);
    expect(find.text('Era mix'), findsOneWidget);
    expect(find.text('Listening calendar'), findsWidgets);
    expect(find.text('Selected day'), findsWidgets);
    expect(find.text('Mo'), findsWidgets);
    expect(find.text('Su'), findsWidgets);
    expect(find.text('Sa'), findsWidgets);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('Highlights'), findsWidgets);
    expect(
      tester.getTopLeft(find.text('Su').first).dx,
      lessThan(tester.getTopLeft(find.text('Mo').first).dx),
    );
    expect(
      tester.getTopLeft(find.text('Mo').first).dx,
      lessThan(tester.getTopLeft(find.text('Sa').first).dx),
    );

    final weekdaysTab = find.text('Weekdays');
    await tester.ensureVisible(weekdaysTab);
    await tester.pumpAndSettle();
    await tester.tap(weekdaysTab);
    await tester.pumpAndSettle();

    expect(find.text('Mon'), findsOneWidget);

    final highlightsTab = find.text('Highlights').last;
    await tester.ensureVisible(highlightsTab);
    await tester.pumpAndSettle();
    await tester.tap(highlightsTab);
    await tester.pumpAndSettle();

    expect(find.text('Peak day'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Quiet days'), findsOneWidget);
  });

  testWidgets('selects today before the peak day in activity heatmap', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      tracks: _heatmapSelectionTracks(),
      snapshotRecordingEnabled: true,
    );
    await tester.pumpAndSettle();

    await _openExpandedListeningMaps(tester);

    expect(find.text('Selected day'), findsWidgets);
    expect(find.text('Today Heatmap Track - Today Artist'), findsWidgets);
    expect(find.text('Yesterday Peak Track - Peak Artist'), findsNothing);
  });

  testWidgets('switches release year map to song count in expanded view', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    await _openExpandedListeningMaps(tester);

    expect(find.text('Release year x songs'), findsNothing);

    final tracksToggle = find.text('Tracks').last;
    await tester.ensureVisible(tracksToggle);
    await tester.tap(tracksToggle);
    await tester.pumpAndSettle();

    expect(find.text('Release year x songs'), findsOneWidget);
  });

  testWidgets('release year chart provides an accessible data selector', (
    tester,
  ) async {
    await _pumpOverview(tester, tracks: _releaseYearAccessibilityTracks());
    await tester.pumpAndSettle();

    final dataSelector = find.byKey(
      const ValueKey('release-year-data-selector'),
    );
    expect(dataSelector, findsOneWidget);
    expect(find.text('Select year data'), findsOneWidget);

    await tester.tap(dataSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2019 -').last);
    await tester.pumpAndSettle();

    expect(find.text('Tap a year point'), findsNothing);
  });

  testWidgets('activity heatmap provides a full-size day selector', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      tracks: _heatmapSelectionTracks(),
      snapshotRecordingEnabled: true,
    );
    await tester.pumpAndSettle();

    final previousDay = find.byTooltip('Previous day');
    await tester.scrollUntilVisible(
      previousDay,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final targetSize = tester.getSize(previousDay);
    expect(targetSize.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(targetSize.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(find.byKey(const ValueKey('activity-day-selector')), findsOneWidget);

    await tester.tap(previousDay);
    await tester.pumpAndSettle();

    expect(find.text('Yesterday Peak Track - Peak Artist'), findsOneWidget);
  });

  testWidgets('calendar month controls navigate and return to today', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      tracks: _heatmapSelectionTracks(),
      snapshotRecordingEnabled: true,
    );
    await tester.pumpAndSettle();
    await _openExpandedListeningMaps(tester);

    final monthLabel = find
        .byKey(const ValueKey('activity-calendar-month-label'))
        .last;
    final initialMonth = tester.widget<Text>(monthLabel).data;
    final previous = find
        .byKey(const ValueKey('activity-calendar-previous-month'))
        .last;
    await tester.ensureVisible(previous);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(monthLabel).data, isNot(initialMonth));

    await tester.tap(
      find.byKey(const ValueKey('activity-calendar-today')).last,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(monthLabel).data, initialMonth);

    final next = find
        .byKey(const ValueKey('activity-calendar-next-month'))
        .last;
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    final now = DateTime.now();
    final futureDay = find
        .byKey(
          ValueKey(
            'activity-calendar-day-${_dateKey(DateTime(now.year, now.month, now.day + 1))}',
          ),
        )
        .last;
    if (now.day < DateTime(now.year, now.month + 1, 0).day) {
      expect(futureDay, findsOneWidget);
      expect(tester.widget<Semantics>(futureDay).properties.enabled, isFalse);
    } else {
      expect(futureDay, findsNothing);
    }
  });

  testWidgets('calendar marks days before the record period', (tester) async {
    await _pumpOverview(
      tester,
      tracks: _heatmapSelectionTracks(),
      snapshotRecordingEnabled: true,
    );
    await tester.pumpAndSettle();
    await _openExpandedListeningMaps(tester);

    final previous = find
        .byKey(const ValueKey('activity-calendar-previous-month'))
        .last;
    while (tester.widget<IconButton>(previous).onPressed != null) {
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await tester.pumpAndSettle();
    }

    // A week that has already ended is not partial, even with missing days.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity-calendar-week-0')).last,
        matching: find.textContaining('(partial)'),
      ),
      findsNothing,
    );

    final now = DateTime.now();
    final rawStart = DateTime(now.year, now.month, now.day - 83);
    final start = DateTime(
      rawStart.year,
      rawStart.month,
      rawStart.day - (rawStart.weekday - DateTime.monday),
    );
    if (start.day == 1) return;
    final firstOfMonth = find
        .byKey(
          ValueKey(
            'activity-calendar-day-${_dateKey(DateTime(start.year, start.month))}',
          ),
        )
        .last;
    final semantics = tester.widget<Semantics>(firstOfMonth).properties;
    expect(semantics.enabled, isFalse);
    expect(semantics.label, contains('Outside the record period'));
  });

  testWidgets('focused calendar preserves the selected artist mode', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      tracks: _heatmapSelectionTracks(),
      snapshotRecordingEnabled: true,
    );
    await tester.pumpAndSettle();
    final artist = find.byKey(const ValueKey('activity-calendar-mode-artist'));
    await _scrollOverviewUntilVisible(tester, artist);
    await tester.tap(artist);
    await tester.pumpAndSettle();
    final expand = find.byKey(const ValueKey('activity-calendar-expand'));
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
    final modal = find.byType(BottomSheet).last;
    expect(
      find.descendant(of: modal, matching: find.text('Top artist')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: modal, matching: find.text('Today Artist')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('real library without adjacent daily records has no estimate', (
    tester,
  ) async {
    final now = DateTime.now();
    final track = _calendarTrack(
      'single-record',
      'Single Record',
      'Artist',
      100,
    );
    final onlySnapshot = DailyLibrarySnapshot.fromOverview(
      LibraryOverview.fromTracks([track], isDemo: false),
      capturedAt: now,
    );
    await _pumpOverview(
      tester,
      statsState: MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: LibraryOverview.fromTracks([track], isDemo: false),
        snapshotHistory: SnapshotHistory(snapshots: [onlySnapshot]),
        snapshotRecordingEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    await _openExpandedListeningMaps(tester);

    expect(find.textContaining('No daily records this month'), findsWidgets);
    expect(find.textContaining('Recent-track estimate'), findsNothing);
  });

  testWidgets(
    'calendar does not create winners across gaps or filter changes',
    (tester) async {
      final now = DateTime.now();
      final track = _calendarTrack(
        'calendar-history',
        'History Song',
        'History Artist',
        20,
      );
      final overview = LibraryOverview.fromTracks([track], isDemo: false);
      for (final gap in [false, true]) {
        final previousTime = now.subtract(Duration(days: gap ? 2 : 1));
        final previous = DailyLibrarySnapshot.fromOverview(
          LibraryOverview.fromTracks([
            track.copyWith(playCount: 10),
          ], isDemo: false),
          capturedAt: previousTime,
          filterSignature: 'profile-a',
        );
        final current = DailyLibrarySnapshot.fromOverview(
          overview,
          capturedAt: now,
          filterSignature: gap ? 'profile-a' : 'profile-b',
        );
        await _pumpOverview(
          tester,
          statsState: MusicStatsState(
            authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
            overview: overview,
            snapshotHistory: SnapshotHistory(snapshots: [previous, current]),
            snapshotRecordingEnabled: true,
          ),
        );
        await tester.pumpAndSettle();
        await _openExpandedListeningMaps(tester);
        expect(
          find.textContaining('No daily records this month'),
          findsWidgets,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('jacket and artist modes compare all tracked songs', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentTracks = <LibraryTrack>[
      _calendarTrack('jacket-winner', 'Jacket Winner', 'Solo Artist', 10),
      for (var index = 0; index < 4; index++)
        _calendarTrack(
          'other-$index',
          'Other $index',
          'Other Artist $index',
          9 - index,
        ),
      for (var index = 0; index < 6; index++)
        _calendarTrack(
          'artist-two-$index',
          'Artist Two $index',
          'Artist Two',
          3,
        ),
    ];
    final previousTracks = [
      for (final track in currentTracks) track.copyWith(playCount: 0),
    ];
    final previous = DailyLibrarySnapshot.fromOverview(
      LibraryOverview.fromTracks(previousTracks, isDemo: false),
      capturedAt: now.subtract(const Duration(days: 1)),
    );
    final current = DailyLibrarySnapshot.fromOverview(
      LibraryOverview.fromTracks(currentTracks, isDemo: false),
      capturedAt: now,
    );
    final overview = LibraryOverview.fromTracks(currentTracks, isDemo: false);
    await _pumpOverview(
      tester,
      statsState: MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: overview,
        snapshotHistory: SnapshotHistory(snapshots: [previous, current]),
        snapshotRecordingEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    await _openExpandedListeningMaps(tester);

    final artistMode = find
        .byKey(const ValueKey('activity-calendar-mode-artist'))
        .last;
    await tester.ensureVisible(artistMode);
    await tester.tap(artistMode);
    await tester.pumpAndSettle();
    expect(find.text('Artist Two'), findsWidgets);
    expect(find.text('Top artist'), findsWidgets);
    expect(find.text('18 plays'), findsWidgets);

    final jacketMode = find
        .byKey(const ValueKey('activity-calendar-mode-song'))
        .last;
    await tester.tap(jacketMode);
    await tester.pumpAndSettle();
    expect(find.text('Jacket Winner'), findsWidgets);
    expect(find.text('Top song'), findsWidgets);
    expect(find.text('10 plays'), findsWidgets);
  });

  testWidgets('album mode groups a compilation by its album artist', (
    tester,
  ) async {
    final now = DateTime.now();
    LibraryTrack mixTrack(int index) => LibraryTrack(
      id: 'mix-$index',
      title: 'Mix Song $index',
      artist: 'Mix Artist $index',
      albumTitle: 'Mix Album',
      albumArtist: 'Various Artists',
      playCount: 4,
      skipCount: 0,
      duration: const Duration(minutes: 3),
      isCloudItem: false,
    );
    final currentTracks = <LibraryTrack>[
      _calendarTrack('single-winner', 'Single Winner', 'Solo Artist', 10),
      for (var index = 0; index < 4; index++) mixTrack(index),
    ];
    final previous = DailyLibrarySnapshot.fromOverview(
      LibraryOverview.fromTracks([
        for (final track in currentTracks) track.copyWith(playCount: 0),
      ], isDemo: false),
      capturedAt: now.subtract(const Duration(days: 1)),
    );
    final overview = LibraryOverview.fromTracks(currentTracks, isDemo: false);
    final current = DailyLibrarySnapshot.fromOverview(
      overview,
      capturedAt: now,
    );
    await _pumpOverview(
      tester,
      statsState: MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: overview,
        snapshotHistory: SnapshotHistory(snapshots: [previous, current]),
        snapshotRecordingEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    await _openExpandedListeningMaps(tester);

    final caption = find
        .byKey(const ValueKey('activity-calendar-mode-caption'))
        .last;
    final songCaptionHeight = tester.getSize(caption).height;
    final albumMode = find
        .byKey(const ValueKey('activity-calendar-mode-album'))
        .last;
    await tester.ensureVisible(albumMode);
    await tester.tap(albumMode);
    await tester.pumpAndSettle();
    expect(find.text('Top album'), findsWidgets);
    expect(find.text('Mix Album'), findsWidgets);
    expect(find.text('Various Artists'), findsWidgets);
    expect(find.text('16 plays'), findsWidgets);
    // The caption keeps its height, so switching modes does not move the grid.
    expect(tester.getSize(caption).height, songCaptionHeight);

    await tester.tap(
      find.byKey(const ValueKey('activity-calendar-mode-artist')).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Solo Artist'), findsWidgets);
    expect(find.text('10 plays'), findsWidgets);
    expect(tester.getSize(caption).height, songCaptionHeight);
  });

  testWidgets('total-only snapshot days do not show a zero winner', (
    tester,
  ) async {
    final now = DateTime.now();
    final overview = LibraryOverview.fromTracks([
      _calendarTrack('total-only', 'Unavailable Detail', 'Unknown Artist', 5),
    ], isDemo: false);
    final previousOverview = LibraryOverview.fromTracks([
      _calendarTrack('total-only', 'Unavailable Detail', 'Unknown Artist', 0),
    ], isDemo: false);
    final previousBase = DailyLibrarySnapshot.fromOverview(
      previousOverview,
      capturedAt: now.subtract(const Duration(days: 1)),
    );
    final currentBase = DailyLibrarySnapshot.fromOverview(
      overview,
      capturedAt: now,
    );
    final history = SnapshotHistory(
      snapshots: [
        DailyLibrarySnapshot(
          dateKey: previousBase.dateKey,
          capturedAt: previousBase.capturedAt,
          source: previousBase.source,
          trackCount: previousBase.trackCount,
          totalPlayCount: 0,
          totalSkipCount: previousBase.totalSkipCount,
          totalListeningSeconds: previousBase.totalListeningSeconds,
          tracks: const [],
        ),
        DailyLibrarySnapshot(
          dateKey: currentBase.dateKey,
          capturedAt: currentBase.capturedAt,
          source: currentBase.source,
          trackCount: currentBase.trackCount,
          totalPlayCount: 5,
          totalSkipCount: currentBase.totalSkipCount,
          totalListeningSeconds: currentBase.totalListeningSeconds,
          tracks: const [],
        ),
      ],
    );
    await _pumpOverview(
      tester,
      statsState: MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: overview,
        snapshotHistory: history,
        snapshotRecordingEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    await _openExpandedListeningMaps(tester);
    expect(find.text('Song detail is unavailable for this day.'), findsWidgets);
    // Other overview cards also have a "Top song" label; check the calendar.
    final calendarCard = find
        .byKey(const ValueKey('activity-card-content'))
        .last;
    expect(
      find.descendant(of: calendarCard, matching: find.text('Top song')),
      findsNothing,
    );
    expect(
      find.descendant(of: calendarCard, matching: find.text('Top artist')),
      findsNothing,
    );
    final todayCell = find
        .byKey(ValueKey('activity-calendar-day-${_dateKey(now)}'))
        .last;
    expect(
      tester.widget<Semantics>(todayCell).properties.label,
      isNot(contains('Unavailable Detail')),
    );
    expect(
      find.descendant(of: todayCell, matching: find.text('0')),
      findsNothing,
    );
  });

  testWidgets('calendar remains usable at narrow widths and enlarged text', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      tracks: _heatmapSelectionTracks(),
      snapshotRecordingEnabled: true,
    );
    await tester.pumpAndSettle();
    await _openExpandedListeningMaps(tester);
    final calendarCards = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_ActivityHeatmapCard',
    );
    final expandedCalendar = tester.widget<Widget>(calendarCards.last);

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('isolated-calendar-$width'),
          overrides: [
            appLanguageProvider.overrideWith(
              () => _FixedLanguageController(AppLanguage.english),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: expandedCalendar),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('activity-calendar')), findsOneWidget);
    }
  });

  testWidgets('shows recap and collection insight panels', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    await _scrollOverviewUntilVisible(tester, find.text('Recap highlights'));
    expect(find.text('Recap highlights'), findsOneWidget);
    expect(find.text('SongBrief Recap'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);

    final summaryScope = find.text('Summary');
    await tester.scrollUntilVisible(
      summaryScope,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(summaryScope);
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Next milestone'), findsOneWidget);
    expect(find.text('Listening curve'), findsOneWidget);

    final rediscovery = find.text('Rediscovery');
    await tester.scrollUntilVisible(
      rediscovery,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Diversity score'), findsOneWidget);
    expect(find.text('Album completion'), findsOneWidget);
    expect(find.text('Late Bloom'), findsWidgets);
  });

  testWidgets('stale denied-access history is not shown as this period', (
    tester,
  ) async {
    final now = DateTime.now();
    final previousTrack = LibraryTrack(
      id: 'stale-recap',
      title: 'Stale recap track',
      artist: 'Unavailable Artist',
      albumTitle: 'Old Counts',
      playCount: 100,
      skipCount: 0,
      duration: const Duration(minutes: 3),
      lastPlayedAt: now.subtract(const Duration(days: 30)),
      isCloudItem: false,
    );
    final currentTrack = previousTrack.copyWith(playCount: 1100);
    final history = SnapshotHistory(
      snapshots: [
        DailyLibrarySnapshot.fromOverview(
          LibraryOverview.fromTracks([previousTrack], isDemo: false),
          capturedAt: now.subtract(const Duration(days: 30)),
        ),
        DailyLibrarySnapshot.fromOverview(
          LibraryOverview.fromTracks([currentTrack], isDemo: false),
          capturedAt: now.subtract(const Duration(days: 20)),
        ),
      ],
    );
    await _pumpOverview(
      tester,
      statsState: MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.denied,
        overview: LibraryOverview.fromTracks([currentTrack], isDemo: false),
        snapshotHistory: history,
        snapshotRecordingEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    await _scrollOverviewUntilVisible(tester, find.text('Recap highlights'));
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('1,000'), findsNothing);
  });

  testWidgets('opens an album completion list', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final album = find.text('Small Signals');
    await tester.scrollUntilVisible(
      album,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(album);
    await tester.pumpAndSettle();

    expect(find.textContaining('Album songs'), findsOneWidget);
  });

  testWidgets('loads more album completion rows', (tester) async {
    await _pumpOverview(tester, tracks: _albumCompletionTracks());
    await tester.pumpAndSettle();

    final albumCompletion = find.text('Album completion');
    await tester.scrollUntilVisible(
      albumCompletion,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Album 05'), findsNothing);

    final loadMoreButton = find.text('Show 3 more');
    await tester.ensureVisible(loadMoreButton);
    await tester.tap(loadMoreButton);
    await tester.pumpAndSettle();

    expect(find.text('Album 05'), findsOneWidget);
    expect(find.text('Album 07'), findsOneWidget);
    expect(loadMoreButton, findsNothing);
  });

  testWidgets('opens a release decade list from expanded listening maps', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    await _openExpandedListeningMaps(tester);

    final decadeRow = find.text('2010s');
    await tester.ensureVisible(decadeRow);
    await tester.tap(decadeRow);
    await tester.pumpAndSettle();

    expect(find.textContaining('Release decade songs'), findsOneWidget);
  });
}

Future<void> _openExpandedListeningMaps(WidgetTester tester) async {
  final expandButton = find.byTooltip('Expand listening maps');
  await _scrollOverviewUntilVisible(tester, expandButton);
  await tester.tap(expandButton);
  await tester.pumpAndSettle();
}

Future<void> _scrollOverviewUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  for (var attempt = 0; attempt < 30; attempt += 1) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pumpAndSettle();
  }
  expect(target, findsWidgets);
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  List<LibraryTrack>? tracks,
  bool snapshotRecordingEnabled = false,
  MusicStatsState? statsState,
  double width = 900,
  double textScaleFactor = 1,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1200);
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(AppLanguage.english),
        ),
        homeSectionProvider.overrideWith(
          () => _FixedHomeSectionController(HomeSection.overview),
        ),
        if (statsState != null)
          musicStatsControllerProvider.overrideWith(
            () => _StaticMusicStatsController(statsState),
          )
        else if (tracks != null)
          musicStatsControllerProvider.overrideWith(
            () => _FixedMusicStatsController(
              tracks,
              snapshotRecordingEnabled: snapshotRecordingEnabled,
            ),
          ),
      ],
      child: const SongBriefApp(),
    ),
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

LibraryTrack _calendarTrack(
  String id,
  String title,
  String artist,
  int playCount,
) {
  return LibraryTrack(
    id: id,
    title: title,
    artist: artist,
    albumTitle: 'Calendar Test',
    playCount: playCount,
    skipCount: 0,
    duration: const Duration(minutes: 3),
    isCloudItem: false,
  );
}

class _StaticMusicStatsController extends MusicStatsController {
  _StaticMusicStatsController(this.statsState);

  final MusicStatsState statsState;

  @override
  Future<MusicStatsState> build() async => statsState;
}

class _FixedMusicStatsController extends MusicStatsController {
  _FixedMusicStatsController(
    this.tracks, {
    required this.snapshotRecordingEnabled,
  });

  final List<LibraryTrack> tracks;
  final bool snapshotRecordingEnabled;

  @override
  Future<MusicStatsState> build() async {
    return MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
      overview: LibraryOverview.fromTracks(tracks, isDemo: true),
      snapshotHistory: SnapshotHistory.empty,
      snapshotRecordingEnabled: snapshotRecordingEnabled,
    );
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

class _FixedHomeSectionController extends HomeSectionController {
  _FixedHomeSectionController(this.section);

  final HomeSection section;

  @override
  HomeSection build() {
    return section;
  }
}

List<LibraryTrack> _albumCompletionTracks() {
  return List.generate(7, (index) {
    final number = index + 1;
    return LibraryTrack(
      id: 'album-completion-$number',
      title: 'Track $number',
      artist: 'Test Artist',
      albumTitle: 'Album ${number.toString().padLeft(2, '0')}',
      albumArtist: 'Test Artist',
      playCount: 10 - index,
      skipCount: index,
      duration: const Duration(minutes: 3),
      releaseDate: DateTime(2020, 1, number),
      isCloudItem: false,
    );
  }, growable: false);
}

List<LibraryTrack> _heatmapSelectionTracks() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  final yesterday = today.subtract(const Duration(days: 1));
  return [
    LibraryTrack(
      id: 'heatmap-today',
      title: 'Today Heatmap Track',
      artist: 'Today Artist',
      albumTitle: 'Daily Signals',
      playCount: 16,
      skipCount: 0,
      duration: const Duration(minutes: 3),
      lastPlayedAt: today,
      isCloudItem: false,
    ),
    LibraryTrack(
      id: 'heatmap-yesterday-peak',
      title: 'Yesterday Peak Track',
      artist: 'Peak Artist',
      albumTitle: 'Daily Signals',
      playCount: 160,
      skipCount: 0,
      duration: const Duration(minutes: 3),
      lastPlayedAt: yesterday,
      isCloudItem: false,
    ),
  ];
}

List<LibraryTrack> _releaseYearAccessibilityTracks() {
  return [
    for (var index = 0; index < 3; index++)
      LibraryTrack(
        id: 'release-year-accessibility-$index',
        title: 'Release Year Track $index',
        artist: 'Accessibility Artist',
        albumTitle: 'Release Years',
        playCount: 10 + index,
        skipCount: 0,
        duration: const Duration(minutes: 3),
        releaseDate: DateTime(2019 + index, 1, 1),
        isCloudItem: false,
      ),
  ];
}
