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
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

void main() {
  testWidgets('observation minimums appear on observation days and reconcile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final native = _track('native', plays: 4);
    final overview = LibraryOverview.fromTracks([native], isDemo: false);
    final history = SnapshotHistory(
      snapshots: [
        DailyLibrarySnapshot.fromOverview(
          LibraryOverview.fromTracks([
            native.copyWith(playCount: 3),
          ], isDemo: false),
          capturedAt: today
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 12)),
        ),
        DailyLibrarySnapshot.fromOverview(
          overview,
          capturedAt: today.add(const Duration(hours: 12)),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
        trackArtworkProvider.overrideWith((ref, id) async => null),
        homeSectionProvider.overrideWith(() => _OverviewHomeSection()),
        appLanguageProvider.overrideWith(() => _EnglishLanguage()),
        musicStatsControllerProvider.overrideWith(
          () => _FixedStats(
            MusicStatsState(
              authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
              overview: overview,
              snapshotHistory: history,
              snapshotRecordingEnabled: true,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final outside = _track('outside');
    container
        .read(supplementalHistoryProvider.notifier)
        .observe(outside, at: now);
    container.read(supplementalHistoryProvider.notifier).ingest([
      _track('undated'),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SongBriefApp(),
      ),
    );
    await tester.pumpAndSettle();

    final todayCell = find
        .byKey(ValueKey('activity-calendar-day-${_dateKey(today)}'))
        .last;
    expect(
      tester.widget<Semantics>(todayCell).properties.label,
      contains('2 plays'),
    );
    expect(
      find.textContaining(
        'Includes at least 1 play(s) confirmed from history on the observation day.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        '1 outside-library track has no known playback/observation date',
      ),
      findsWidgets,
    );

    final expand = find.byKey(const ValueKey('activity-calendar-expand'));
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Includes at least 1 play(s) confirmed from history on the observation day.',
      ),
      findsWidgets,
    );

    // Re-observing the same track later keeps one minimum event.
    container
        .read(supplementalHistoryProvider.notifier)
        .observe(outside, at: now.add(const Duration(days: 1)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Includes at least 1 play(s) confirmed from history on the observation day.',
      ),
      findsWidgets,
    );

    // A dated event supersedes the observation fallback and shifts its day.
    container.read(supplementalHistoryProvider.notifier).ingest([
      outside.copyWith(lastPlayedAt: today.subtract(const Duration(days: 2))),
    ]);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Includes at least 1 play(s) confirmed from history on the observation day.',
      ),
      findsNothing,
    );
    final datedCell = find
        .byKey(
          ValueKey(
            'activity-calendar-day-${_dateKey(today.subtract(const Duration(days: 2)))}',
          ),
        )
        .last;
    expect(
      tester.widget<Semantics>(datedCell).properties.label,
      contains('1 play'),
    );
    expect(
      find.textContaining(
        '1 outside-library track has no known playback/observation date',
      ),
      findsWidgets,
    );
  });
}

LibraryTrack _track(String id, {int plays = 0, DateTime? playedAt}) =>
    LibraryTrack(
      id: id,
      title: id == 'native' ? 'Native song' : '$id song',
      artist: 'Calendar artist',
      albumTitle: 'Calendar album',
      playCount: plays,
      skipCount: 0,
      duration: const Duration(minutes: 3),
      isCloudItem: id != 'native',
      lastPlayedAt: playedAt,
    );

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _FixedStats extends MusicStatsController {
  _FixedStats(this.stats);
  final MusicStatsState stats;
  @override
  Future<MusicStatsState> build() async => stats;
}

class _OverviewHomeSection extends HomeSectionController {
  @override
  HomeSection build() => HomeSection.overview;
}

class _EnglishLanguage extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
