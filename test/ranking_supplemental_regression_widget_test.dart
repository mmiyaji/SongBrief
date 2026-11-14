import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/counted_listening_provider.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  testWidgets(
    'supplemental lifetime plays do not hide snapshot rankings or alter their deltas',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final nativeBefore = _track('native', 'Library song', 10);
      final nativeAfter = _track('native', 'Library song', 12);
      final outside = _track('outside', 'Supplemental song', 100);
      final before = LibraryOverview.fromTracks([nativeBefore], isDemo: false);
      final after = LibraryOverview.fromTracks([nativeAfter], isDemo: false);
      final history = SnapshotHistory.empty
          .withSnapshot(
            DailyLibrarySnapshot.fromOverview(
              before,
              capturedAt: DateTime(2026, 10, 28, 12),
            ),
          )
          .withSnapshot(
            DailyLibrarySnapshot.fromOverview(
              after,
              capturedAt: DateTime(2026, 10, 30, 12),
            ),
          );
      final state = MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: after,
        snapshotHistory: history,
      );
      _FixedStats.fixture = state;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith(
              () => _FixedLanguageController(AppLanguage.english),
            ),
            homeSectionProvider.overrideWith(
              () => _FixedHomeSectionController(HomeSection.rankings),
            ),
            musicStatsControllerProvider.overrideWith(_FixedStats.new),
            countedOutsideTracksProvider.overrideWith((ref) => [outside]),
            countedListeningOverviewProvider.overrideWith(
              (ref) => LibraryOverview.fromTracks([
                nativeAfter,
                outside,
              ], isDemo: false),
            ),
            supplementalUndatedTrackCountProvider.overrideWith((ref) => 0),
          ],
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Period movers'), findsOneWidget);
      expect(find.text('Rising now'), findsOneWidget);
      expect(find.text('Rank changes'), findsOneWidget);
      expect(
        find.textContaining('Lifetime totals include supplemental'),
        findsOneWidget,
      );
      expect(find.text('Library song'), findsWidgets);
      expect(find.text('+2'), findsWidgets);
    },
  );

  for (final section in [
    HomeSection.playing,
    HomeSection.library,
    HomeSection.settings,
  ]) {
    testWidgets('$section does not subscribe to counted overview', (
      tester,
    ) async {
      _FixedStats.fixture = _nativeStats;
      var reads = 0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith(
              () => _FixedLanguageController(AppLanguage.english),
            ),
            homeSectionProvider.overrideWith(
              () => _FixedHomeSectionController(section),
            ),
            musicStatsControllerProvider.overrideWith(_FixedStats.new),
            countedListeningOverviewProvider.overrideWith((ref) {
              reads++;
              return LibraryOverview.empty(isDemo: false);
            }),
          ],
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(reads, 0);
    });
  }

  testWidgets(
    'leaving rankings stops counted overview updates after supplemental changes',
    (tester) async {
      _FixedStats.fixture = _nativeStats;
      final reads = _ReadCounter();
      final container = ProviderContainer(
        overrides: [
          appLanguageProvider.overrideWith(
            () => _FixedLanguageController(AppLanguage.english),
          ),
          trackLyricsProvider.overrideWith((ref, trackId) async => null),
          trackArtworkProvider.overrideWith((ref, trackId) async => null),
          musicStatsControllerProvider.overrideWith(_FixedStats.new),
          homeSectionProvider.overrideWith(
            () => _FixedHomeSectionController(HomeSection.playing),
          ),
          _supplementalRevisionProvider.overrideWith(
            _SupplementalRevisionController.new,
          ),
          countedListeningOverviewProvider.overrideWith((ref) {
            ref.watch(_supplementalRevisionProvider);
            reads.value++;
            return _nativeOverview;
          }),
        ],
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SongBriefApp(),
        ),
      );
      await container.read(musicStatsControllerProvider.future);
      await tester.pumpAndSettle();

      container
          .read(homeSectionProvider.notifier)
          .setSection(HomeSection.rankings);
      await tester.pumpAndSettle();
      expect(reads.value, greaterThan(0));

      container
          .read(homeSectionProvider.notifier)
          .setSection(HomeSection.playing);
      await tester.pumpAndSettle();
      final readsAfterLeavingRankings = reads.value;
      container.read(_supplementalRevisionProvider.notifier).advance();
      await tester.pumpAndSettle();

      expect(reads.value, readsAfterLeavingRankings);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

LibraryTrack _track(String id, String title, int plays) => LibraryTrack(
  id: id,
  title: title,
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(minutes: 3),
  playCount: plays,
  skipCount: 0,
  isCloudItem: false,
);

class _FixedStats extends MusicStatsController {
  @override
  Future<MusicStatsState> build() async => fixture;

  static MusicStatsState fixture = _nativeStats;
}

final _supplementalRevisionProvider =
    NotifierProvider<_SupplementalRevisionController, int>(
      _SupplementalRevisionController.new,
    );
final _nativeOverview = LibraryOverview.fromTracks([
  _track('native', 'Library song', 12),
], isDemo: false);
final _nativeStats = MusicStatsState(
  authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
  overview: _nativeOverview,
  snapshotHistory: SnapshotHistory.empty,
);

class _ReadCounter {
  int value = 0;
}

class _SupplementalRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state++;
}

class _FixedLanguageController extends AppLanguageController {
  _FixedLanguageController(this.language);
  final AppLanguage language;

  @override
  AppLanguage build() => language;
}

class _FixedHomeSectionController extends HomeSectionController {
  _FixedHomeSectionController(this.section);
  final HomeSection section;

  @override
  HomeSection build() => section;
}
