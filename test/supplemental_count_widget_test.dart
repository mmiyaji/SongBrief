import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';
import 'package:songbrief/src/features/home/counted_listening_provider.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

const native = LibraryTrack(
  id: 'native',
  title: 'Native Song',
  artist: 'Native Artist',
  albumTitle: 'Native Album',
  duration: Duration(minutes: 3),
  playCount: 10,
  skipCount: 2,
  isCloudItem: false,
);
const supplemental = LibraryTrack(
  id: 'musickit:outside',
  title: 'Outside Song',
  artist: 'Outside Artist',
  albumTitle: 'Outside Album',
  duration: Duration(minutes: 4),
  playCount: 3,
  skipCount: 0,
  isCloudItem: true,
);

void main() {
  testWidgets(
    'total includes supplemental minimum while library counts and skips remain native',
    (tester) async {
      final container = await pumpCounts(tester, HomeSection.overview);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('overview-total-play-count')),
            )
            .data,
        '13',
      );
      expect(find.text('1 track ・ 1 artist ・ 1 album'), findsOneWidget);
      expect(
        find.textContaining(
          'Includes 3 confirmed supplemental plays (minimum)',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 supplemental track has unknown play times'),
        findsOneWidget,
      );
      expect(find.text('20.0%'), findsOneWidget);
      expect(
        container
            .read(musicStatsControllerProvider)
            .requireValue
            .overview
            .totalPlayCount,
        10,
      );
      expect(
        container
            .read(musicStatsControllerProvider)
            .requireValue
            .overview
            .totalTracks,
        1,
      );
      container
          .read(homeSectionProvider.notifier)
          .setSection(HomeSection.library);
      await tester.pumpAndSettle();
      expect(find.text('Outside Song'), findsNothing);
      expect(find.text('Native Song'), findsWidgets);
    },
  );

  testWidgets(
    'supplemental ranking appears once and cannot open playback detail',
    (tester) async {
      final container = await pumpCounts(tester, HomeSection.rankings);
      expect(
        find.textContaining(
          'Includes 3 confirmed supplemental plays (minimum)',
        ),
        findsOneWidget,
      );
      expect(find.text('Outside Song'), findsOneWidget);
      expect(find.text('Period movers'), findsNothing);
      await tester.tap(find.text('Outside Song'));
      await tester.pumpAndSettle();
      expect(find.text('Show position in ranking'), findsNothing);
      expect(container.read(playbackControllerProvider).activeTrackId, isNull);
    },
  );

  testWidgets('calendar includes only real dated supplemental events', (
    tester,
  ) async {
    await pumpCounts(tester, HomeSection.overview, dated: true);
    final expand = find.byTooltip('Expand listening maps');
    for (
      var attempt = 0;
      attempt < 30 && expand.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(expand.first);
    await tester.tap(expand.first);
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final cell = find
        .byKey(ValueKey('activity-calendar-day-${snapshotDateKey(today)}'))
        .last;
    final semantics = tester.widget<Semantics>(cell);
    expect(semantics.properties.label, contains('1 play'));
    expect(semantics.properties.label, isNot(contains('3 plays')));
  });

  testWidgets(
    'no unknown timestamp caption when all supplemental dates are known',
    (tester) async {
      await pumpCounts(tester, HomeSection.overview, dated: true);
      expect(
        find.textContaining(
          'Includes 3 confirmed supplemental plays (minimum)',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('unknown play times'), findsNothing);
    },
  );
}

Future<ProviderContainer> pumpCounts(
  WidgetTester tester,
  HomeSection section, {
  bool dated = false,
}) async {
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final stats = MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: LibraryOverview.fromTracks([native], isDemo: false),
    snapshotHistory: SnapshotHistory.empty,
    snapshotRecordingEnabled: true,
  );
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      trackArtworkProvider.overrideWith((ref, id) async => null),
      musicStatsControllerProvider.overrideWith(() => FixedStats(stats)),
      appLanguageProvider.overrideWith(English.new),
      countedSupplementalEventsProvider.overrideWithValue(
        dated
            ? [
                SupplementalListeningEvent(
                  track: supplemental.copyWith(playCount: 1),
                  playedAt: DateTime.now(),
                ),
              ]
            : const [],
      ),
      countedOutsideTracksProvider.overrideWithValue([
        dated
            ? supplemental.copyWith(lastPlayedAt: DateTime(2026, 10, 29))
            : supplemental,
      ]),
    ],
  );
  container.read(homeSectionProvider.notifier).setSection(section);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SongBriefApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class FixedStats extends MusicStatsController {
  FixedStats(this.stats);
  final MusicStatsState stats;
  @override
  Future<MusicStatsState> build() async => stats;
}

class English extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
