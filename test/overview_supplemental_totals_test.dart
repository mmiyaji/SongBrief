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
import 'package:songbrief/src/domain/supplemental_listening_history.dart';
import 'package:songbrief/src/features/home/counted_listening_provider.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

const _native = LibraryTrack(
  id: 'native-song',
  title: 'Native song',
  artist: 'Native artist',
  albumTitle: 'Native album',
  duration: Duration(hours: 1),
  playCount: 10,
  skipCount: 2,
  isCloudItem: false,
);

const _outside = LibraryTrack(
  id: 'outside-song',
  title: 'Outside song',
  artist: 'Outside artist',
  albumTitle: 'Outside album',
  duration: Duration(hours: 1),
  playCount: 1,
  skipCount: 0,
  isCloudItem: true,
);

const _outsideUnknownDuration = LibraryTrack(
  id: 'outside-unknown-duration',
  title: 'Undated outside song',
  artist: 'Outside artist',
  albumTitle: 'Outside album',
  duration: Duration.zero,
  playCount: 1,
  skipCount: 0,
  isCloudItem: true,
);

void main() {
  testWidgets(
    'overview song drilldown includes marked supplemental history safely',
    (tester) async {
      final history = const SupplementalListeningHistory.empty().ingest([
        _outside.copyWith(lastPlayedAt: DateTime(2026, 10, 28)),
        _outside.copyWith(lastPlayedAt: DateTime(2026, 10, 29)),
      ]);
      final container = await _pumpOverview(tester, history);
      addTearDown(container.dispose);
      final songsCard = find.byKey(const ValueKey('overview-summary-card-2'));
      await tester.ensureVisible(songsCard);
      await tester.tap(songsCard);
      await tester.pumpAndSettle();
      final rows = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_GroupTrackRow',
      );
      expect(rows, findsNWidgets(2));
      final supplementalRow = find.ancestor(
        of: find.text('Outside song').last,
        matching: rows,
      );
      expect(
        find.descendant(
          of: supplementalRow,
          matching: find.text('Confirmed from history: at least 2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: supplementalRow,
          matching: find.byIcon(Icons.open_in_new_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('Skips (library)'), findsOneWidget);
      expect(container.read(playbackControllerProvider).activeTrackId, isNull);
      expect(
        container
            .read(musicStatsControllerProvider)
            .requireValue
            .overview
            .totalTracks,
        1,
      );
    },
  );

  testWidgets('lifetime overview adds dated outside plays uniformly', (
    tester,
  ) async {
    final history = const SupplementalListeningHistory.empty().ingest([
      _native.copyWith(lastPlayedAt: DateTime(2026, 10, 27)),
      _outside.copyWith(lastPlayedAt: DateTime(2026, 10, 28)),
      _outside.copyWith(lastPlayedAt: DateTime(2026, 10, 29)),
    ]);
    final container = await _pumpOverview(tester, history);
    addTearDown(container.dispose);

    final counted = container.read(countedListeningOverviewProvider);
    expect(counted.totalPlayCount, 12);
    expect(counted.totalTracks, 2);
    expect(counted.totalArtists, 2);
    expect(counted.totalAlbums, 2);
    expect(counted.totalListeningSeconds, 12 * 60 * 60);
    expect(counted.totalSkipCount, 2);
    expect(counted.totalSkipCount / 10, closeTo(.2, .0001));
    expect(
      container.read(countedOutsideTracksProvider).map((track) => track.id),
      ['outside-song'],
    );

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('overview-total-play-count')))
          .data,
      '12',
    );
    expect(_summaryValue(0, '2'), findsOneWidget);
    expect(_summaryValue(1, '2'), findsOneWidget);
    expect(_summaryValue(2, '2'), findsOneWidget);
    expect(_summaryValue(3, '12.0'), findsOneWidget);
    expect(find.text('20.0%'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // Native skips stay at two.
    expect(find.textContaining('confirmed from history'), findsWidgets);

    final beforeReingest = container.read(supplementalHistoryProvider);
    container.read(supplementalHistoryProvider.notifier).ingest([
      _outside.copyWith(lastPlayedAt: DateTime(2026, 10, 28)),
      _outside.copyWith(lastPlayedAt: DateTime(2026, 10, 29)),
    ]);
    expect(
      container.read(supplementalHistoryProvider).totalPlayCount,
      beforeReingest.totalPlayCount,
    );
    expect(container.read(countedListeningOverviewProvider).totalPlayCount, 12);
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'undated outside evidence adds minimum plays and counts, not time',
    (tester) async {
      final history = const SupplementalListeningHistory.empty().ingest([
        _outsideUnknownDuration,
      ]);
      final container = await _pumpOverview(tester, history);
      addTearDown(container.dispose);

      final counted = container.read(countedListeningOverviewProvider);
      expect(counted.totalPlayCount, 11);
      expect(counted.totalTracks, 2);
      expect(counted.totalListeningSeconds, 10 * 60 * 60);
      expect(container.read(supplementalUndatedTrackCountProvider), 1);
      expect(find.text('11'), findsWidgets);
      expect(find.textContaining('confirmed from history'), findsWidgets);
      expect(find.textContaining('unknown play times'), findsOneWidget);
    },
  );
}

Finder _summaryValue(int card, String value) => find.descendant(
  of: find.byKey(ValueKey('overview-summary-card-$card')),
  matching: find.text(value),
);

Future<ProviderContainer> _pumpOverview(
  WidgetTester tester,
  SupplementalListeningHistory history,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 1366);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    supplementalListeningHistoryPreferenceKey: history.encode(),
  });
  final preferences = await SharedPreferences.getInstance();
  final nativeOverview = LibraryOverview.fromTracks([_native], isDemo: false);
  final stats = MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: nativeOverview,
    snapshotHistory: SnapshotHistory.empty,
    snapshotRecordingEnabled: false,
  );
  final container = ProviderContainer(
    overrides: [
      musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      musicStatsControllerProvider.overrideWith(() => _FixedStats(stats)),
      appLanguageProvider.overrideWith(() => _English()),
      homeSectionProvider.overrideWith(
        () => _FixedSection(HomeSection.overview),
      ),
      trackArtworkProvider.overrideWith((ref, id) async => null),
      trackLyricsProvider.overrideWith((ref, id) async => null),
    ],
  );
  container.read(musicStatsControllerProvider);
  await container.read(musicStatsControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SongBriefApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
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

class _FixedSection extends HomeSectionController {
  _FixedSection(this.section);
  final HomeSection section;
  @override
  HomeSection build() => section;
}
