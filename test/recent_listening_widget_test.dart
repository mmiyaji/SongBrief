import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/recent_listening_provider.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

void main() {
  testWidgets(
    'snapshot recency appears in playing and library without inventing play time',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final observedAt = DateTime(now.year, now.month, now.day, 15, 47);
      final staleAt = observedAt.subtract(const Duration(days: 2));
      final gyakko = _track('gyakko', 'Gyakko', staleAt, 11);
      final others = [
        for (var index = 0; index < 4; index++)
          _track(
            'other-$index',
            'Other $index',
            observedAt.subtract(Duration(hours: index + 1)),
            20,
          ),
      ];
      final overview = LibraryOverview.fromTracks([
        ...others,
        gyakko,
      ], isDemo: false);
      final baseline = LibraryOverview.fromTracks([
        ...others,
        gyakko.copyWith(playCount: 10),
      ], isDemo: false);
      final stats = MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: overview,
        snapshotHistory: SnapshotHistory(
          snapshots: [
            DailyLibrarySnapshot.fromOverview(
              baseline,
              capturedAt: observedAt.subtract(const Duration(days: 1)),
            ),
            DailyLibrarySnapshot.fromOverview(overview, capturedAt: observedAt),
          ],
        ),
        snapshotRecordingEnabled: true,
      );
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(preferences),
          musicStatsControllerProvider.overrideWith(() => _FixedStats(stats)),
          trackArtworkProvider.overrideWith((ref, id) async => null),
          trackLyricsProvider.overrideWith((ref, id) async => null),
          visibleOutsideLibraryPlaysProvider.overrideWithValue(const []),
          appLanguageProvider.overrideWith(_English.new),
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

      final observedLabel = '${now.month}/${now.day} Observed';
      expect(find.text(observedLabel), findsOneWidget);
      final recentRows = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_RecentTrackRow',
      );
      expect(
        find.descendant(of: recentRows.first, matching: find.text('Gyakko')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: recentRows.first,
          matching: find.textContaining('15:47'),
        ),
        findsNothing,
      );
      await tester.ensureVisible(find.text('See all'));
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      final libraryRows = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_LibraryTrackRow',
      );
      expect(
        find.descendant(of: libraryRows.first, matching: find.text('Gyakko')),
        findsOneWidget,
      );
      expect(find.text(observedLabel), findsOneWidget);
      final recentOverview = container.read(libraryRecentOverviewProvider);
      expect(recentOverview.totalTracks, 5);
      expect(recentOverview.totalPlayCount, overview.totalPlayCount);
      expect(recentOverview.totalSkipCount, overview.totalSkipCount);
      expect(
        recentOverview.tracks.firstWhere((t) => t.id == 'gyakko').playCount,
        11,
      );
      expect(stats.overview.tracks.last.lastPlayedAt, staleAt);
    },
  );
}

LibraryTrack _track(String id, String title, DateTime date, int plays) {
  return LibraryTrack(
    id: id,
    title: title,
    artist: 'Artist',
    albumTitle: 'Album',
    duration: const Duration(minutes: 3),
    playCount: plays,
    skipCount: 2,
    isCloudItem: false,
    lastPlayedAt: date,
  );
}

class _FixedStats extends MusicStatsController {
  _FixedStats(this.stats);
  final MusicStatsState stats;
  @override
  Future<MusicStatsState> build() async => stats;
}

class _English extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
