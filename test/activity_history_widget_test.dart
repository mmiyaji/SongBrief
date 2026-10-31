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
import 'package:songbrief/src/features/home/counted_listening_provider.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/supplemental_history_preferences.dart';

void main() {
  testWidgets(
    'native-match supplemental event stays additive until caught up',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final native = _track('native-42', 42, plays: 8);
      final overview = LibraryOverview.fromTracks([native], isDemo: false);
      final history = _history(native, 8, today, now);
      final controller = _FixedStats(_stats(overview, SnapshotHistory.empty));
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(preferences),
          trackArtworkProvider.overrideWith((ref, id) async => null),
          homeSectionProvider.overrideWith(() => _OverviewHomeSection()),
          appLanguageProvider.overrideWith(() => _EnglishLanguage()),
          musicStatsControllerProvider.overrideWith(() => controller),
        ],
      );
      addTearDown(container.dispose);
      final eventAt = now.subtract(const Duration(minutes: 5));
      container.read(supplementalHistoryProvider.notifier).ingest([
        _track('history-row', 42, plays: 1, playedAt: eventAt),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _expectActivityShown(tester, today);

      // Persisted dated history works before the first native snapshot exists.
      controller.publish(_stats(overview, history));
      await tester.pumpAndSettle();
      await _expectActivityShown(tester, today);

      await container
          .read(supplementalHistoryIncludedProvider.notifier)
          .setEnabled(false);
      expect(container.read(supplementalHistoryIncludedProvider), isFalse);
      expect(container.read(countedSupplementalEventsProvider), isEmpty);
      await tester.pumpAndSettle();
      final disabledDay = find
          .byKey(ValueKey('activity-calendar-day-${_dateKey(today)}'))
          .last;
      expect(
        tester.widget<Semantics>(disabledDay).properties.label,
        isNot(contains('1 play')),
      );
      await container
          .read(supplementalHistoryIncludedProvider.notifier)
          .setEnabled(true);
      await tester.pumpAndSettle();
      await _expectActivityShown(tester, today);

      // A later native snapshot catches up by one, consuming the same event.
      final caughtUpOverview = LibraryOverview.fromTracks([
        native.copyWith(playCount: 9),
      ], isDemo: false);
      controller.publish(
        _stats(
          caughtUpOverview,
          SnapshotHistory(
            snapshots: [
              ...history.snapshots.take(1),
              DailyLibrarySnapshot.fromOverview(
                caughtUpOverview,
                capturedAt: now.add(const Duration(hours: 1)),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectActivityShown(tester, today);

      // Stable rebuilds do not count the ledger event twice.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _expectActivityShown(tester, today);
    },
  );
}

Future<void> _expectActivityShown(WidgetTester tester, DateTime day) async {
  final dayCell = find
      .byKey(ValueKey('activity-calendar-day-${_dateKey(day)}'))
      .last;
  expect(
    tester.widget<Semantics>(dayCell).properties.label,
    contains('1 play'),
  );
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey &&
          (widget.key! as ValueKey).value.toString().startsWith(
            'snapshot-trend-',
          ),
    ),
    findsOneWidget,
  );
}

MusicStatsState _stats(LibraryOverview overview, SnapshotHistory history) =>
    MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
      overview: overview,
      snapshotHistory: history,
      snapshotRecordingEnabled: true,
    );

SnapshotHistory _history(
  LibraryTrack track,
  int plays,
  DateTime today,
  DateTime now,
) => SnapshotHistory(
  snapshots: [
    DailyLibrarySnapshot.fromOverview(
      LibraryOverview.fromTracks([
        track.copyWith(playCount: plays),
      ], isDemo: false),
      capturedAt: today
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 12)),
    ),
    DailyLibrarySnapshot.fromOverview(
      LibraryOverview.fromTracks([
        track.copyWith(playCount: plays),
      ], isDemo: false),
      capturedAt: now.subtract(const Duration(minutes: 10)),
    ),
  ],
);

LibraryTrack _track(
  String id,
  int catalogId, {
  required int plays,
  DateTime? playedAt,
}) => LibraryTrack(
  id: id,
  title: 'Native song',
  artist: 'Activity artist',
  albumTitle: 'Activity album',
  appleMusicStoreId: catalogId.toString(),
  playCount: plays,
  skipCount: 0,
  duration: const Duration(minutes: 3),
  isCloudItem: false,
  lastPlayedAt: playedAt,
);

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _FixedStats extends MusicStatsController {
  _FixedStats(this._value);
  final MusicStatsState _value;
  @override
  Future<MusicStatsState> build() async => _value;
  void publish(MusicStatsState value) => state = AsyncData(value);
}

class _OverviewHomeSection extends HomeSectionController {
  @override
  HomeSection build() => HomeSection.overview;
}

class _EnglishLanguage extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
