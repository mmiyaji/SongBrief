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
    await tester.ensureVisible(tracksCard);
    await tester.tap(tracksCard);
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

    expect(find.text('Listening maps'), findsOneWidget);
    expect(find.text('Tap a year point'), findsOneWidget);

    final expandButton = find.byTooltip('Expand listening maps');
    await tester.ensureVisible(expandButton);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('Genre stack by release year'), findsOneWidget);
    expect(find.text('Era mix'), findsOneWidget);
    expect(find.text('Activity heatmap'), findsWidgets);
    expect(find.text('Selected day'), findsWidgets);
    expect(find.text('Su'), findsWidgets);
    expect(find.text('Sa'), findsWidgets);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('Highlights'), findsWidgets);

    await tester.tap(find.text('Weekdays'));
    await tester.pumpAndSettle();

    expect(find.text('Mon'), findsOneWidget);

    await tester.tap(find.text('Highlights').last);
    await tester.pumpAndSettle();

    expect(find.text('Peak day'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Quiet days'), findsOneWidget);
  });

  testWidgets('switches release year map to song count in expanded view', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final expandButton = find.byTooltip('Expand listening maps');
    await tester.ensureVisible(expandButton);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('Release year x songs'), findsNothing);

    await tester.tap(find.text('Tracks').last);
    await tester.pumpAndSettle();

    expect(find.text('Release year x songs'), findsOneWidget);
  });

  testWidgets('shows recap and collection insight panels', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    expect(find.text('Recap highlights'), findsOneWidget);
    expect(find.text('SongBrief Recap'), findsOneWidget);
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

    final expandButton = find.byTooltip('Expand listening maps');
    await tester.ensureVisible(expandButton);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    final decadeRow = find.text('2010s');
    await tester.ensureVisible(decadeRow);
    await tester.tap(decadeRow);
    await tester.pumpAndSettle();

    expect(find.textContaining('Release decade songs'), findsOneWidget);
  });
}

Future<void> _pumpOverview(WidgetTester tester, {List<LibraryTrack>? tracks}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(AppLanguage.english),
        ),
        homeSectionProvider.overrideWith(
          () => _FixedHomeSectionController(HomeSection.overview),
        ),
        if (tracks != null)
          musicStatsControllerProvider.overrideWith(
            () => _FixedMusicStatsController(tracks),
          ),
      ],
      child: const SongBriefApp(),
    ),
  );
}

class _FixedMusicStatsController extends MusicStatsController {
  _FixedMusicStatsController(this.tracks);

  final List<LibraryTrack> tracks;

  @override
  Future<MusicStatsState> build() async {
    return MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
      overview: LibraryOverview.fromTracks(tracks, isDemo: true),
      snapshotHistory: SnapshotHistory.empty,
      snapshotRecordingEnabled: false,
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
