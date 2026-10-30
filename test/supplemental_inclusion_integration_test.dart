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
import 'package:songbrief/src/features/home/counted_listening_provider.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/recent_listening_provider.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/supplemental_history_preferences.dart';

LibraryTrack song(String id, {int plays = 0, DateTime? at}) => LibraryTrack(
  id: id,
  title: id,
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(minutes: 4),
  playCount: plays,
  skipCount: 0,
  isCloudItem: true,
  lastPlayedAt: at,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('one inclusion preference updates all supported projections without deleting history', () async {
    final container = await fixture();
    addTearDown(container.dispose);
    container
        .read(outsideLibraryPlaysProvider.notifier)
        .record(song('STAY AWAY'), at: DateTime.now());
    container.read(supplementalHistoryProvider.notifier).ingest([
      song('Unknown time'),
    ]);
    final encoded = container.read(supplementalHistoryProvider).encode();
    void expectIncluded(bool included) {
      expect(
        container.read(countedListeningOverviewProvider).totalPlayCount,
        included ? 12 : 10,
      );
      expect(
        container.read(libraryBrowsingOverviewProvider).totalTracks,
        included ? 3 : 1,
      );
      expect(
        container
            .read(recentListeningTracksProvider)
            .any((row) => row.title == 'STAY AWAY'),
        included,
      );
      expect(
        container
            .read(visibleOutsideLibraryPlaysProvider)
            .any((row) => row.title == 'STAY AWAY'),
        included,
      );
      expect(
        container.read(countedSupplementalEventsProvider),
        hasLength(included ? 1 : 0),
      );
      expect(
        container.read(calendarUnplacedSupplementalTrackCountProvider),
        included ? 1 : 0,
      );
    }

    expectIncluded(true);
    final preference = container.read(
      supplementalHistoryIncludedProvider.notifier,
    );
    expect(await preference.setEnabled(false), isTrue);
    expectIncluded(false);
    expect(container.read(supplementalHistoryProvider).encode(), encoded);
    expect(
      container.read(outsideLibraryPlaysProvider).single.title,
      'STAY AWAY',
    );
    expect(await preference.setEnabled(true), isTrue);
    expectIncluded(true);
    expect(container.read(supplementalHistoryProvider).encode(), encoded);
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
          .snapshotHistory
          .snapshots,
      isEmpty,
    );
  });

  testWidgets(
    'recent ranking follows the recommended scope and observation dates',
    (tester) async {
      final container = await fixture();
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      container
          .read(supplementalHistoryProvider.notifier)
          .observe(song('STAY AWAY'), at: DateTime.now());
      container
          .read(homeSectionProvider.notifier)
          .setSection(HomeSection.rankings);
      container
          .read(rankingScopeProvider.notifier)
          .setScope(RankingScope.recent);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('STAY AWAY'), findsOneWidget);
      expect(find.textContaining('Observed'), findsOneWidget);
      await container
          .read(supplementalHistoryIncludedProvider.notifier)
          .setEnabled(false);
      await tester.pumpAndSettle();
      expect(find.text('STAY AWAY'), findsNothing);
      await container
          .read(supplementalHistoryIncludedProvider.notifier)
          .setEnabled(true);
      await tester.pumpAndSettle();
      expect(find.text('STAY AWAY'), findsOneWidget);
    },
  );
}

Future<ProviderContainer> fixture() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      musicDataSharedPreferencesProvider.overrideWithValue(prefs),
      musicStatsControllerProvider.overrideWith(_Stats.new),
      appLanguageProvider.overrideWith(_English.new),
      trackArtworkProvider.overrideWith((ref, id) async => null),
      trackLyricsProvider.overrideWith((ref, id) async => null),
    ],
  );
  await container.read(musicStatsControllerProvider.future);
  return container;
}

class _Stats extends MusicStatsController {
  @override
  Future<MusicStatsState> build() async => MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: LibraryOverview.fromTracks([
      song(
        'Native',
        plays: 10,
        at: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ], isDemo: false),
    snapshotHistory: SnapshotHistory.empty,
    snapshotRecordingEnabled: false,
  );
}

class _English extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
