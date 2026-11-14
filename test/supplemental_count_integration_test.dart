import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/counted_listening_provider.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

LibraryTrack song(String id, String store, {int count = 0, DateTime? at}) =>
    LibraryTrack(
      id: id,
      title: id,
      artist: 'Artist',
      albumTitle: 'Album',
      appleMusicStoreId: store,
      duration: const Duration(minutes: 3),
      playCount: count,
      skipCount: 0,
      isCloudItem: true,
      lastPlayedAt: at,
    );

class _Stats extends MusicStatsController {
  static MusicStatsState fixture(List<LibraryTrack> tracks) => MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: LibraryOverview.fromTracks(tracks, isDemo: false),
    snapshotHistory: SnapshotHistory.empty,
  );
  @override
  Future<MusicStatsState> build() async =>
      fixture([song('native', '42', count: 8)]);
  void replace(List<LibraryTrack> tracks) => state = AsyncData(fixture(tracks));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('supplemental counts merge once and native membership remains authoritative', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
        musicStatsControllerProvider.overrideWith(_Stats.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(musicStatsControllerProvider.future);
    final ledger = container.read(supplementalHistoryProvider.notifier);
    final first = song('musickit:outside', '99', at: DateTime(2026, 10, 29));
    ledger.ingest([
      first,
      first,
      song('musickit:outside', '99', at: DateTime(2026, 10, 30)),
      song('Undated', '100'),
      song('Different catalog spelling', '42', at: DateTime(2026, 10, 30)),
    ]);
    expect(container.read(countedListeningOverviewProvider).totalPlayCount, 11);
    expect(container.read(countedOutsideTracksProvider), hasLength(2));
    // Daily evidence is retained even for matched native songs; snapshot
    // coverage is reconciled by the calendar/trend projection instead.
    expect(container.read(countedSupplementalEventsProvider), hasLength(3));
    expect(container.read(supplementalUndatedTrackCountProvider), 1);
    final native = container.read(musicStatsControllerProvider).requireValue;
    expect(native.overview.totalPlayCount, 8);
    expect(native.snapshotHistory.snapshotCount, 0);
    container.read(outsideLibraryPlaysProvider.notifier).record(first);
    ledger.ingest([first]);
    expect(container.read(countedListeningOverviewProvider).totalPlayCount, 11);

    (container.read(musicStatsControllerProvider.notifier) as _Stats).replace([
      song('native', '42', count: 8),
      song('Now in library', '99', count: 7),
    ]);
    expect(
      container.read(countedOutsideTracksProvider).single.title,
      'Undated',
    );
    expect(container.read(countedListeningOverviewProvider).totalPlayCount, 16);
    expect(container.read(countedSupplementalEventsProvider), hasLength(3));
    expect(
      container
          .read(countedSupplementalEventsProvider)
          .where((event) => event.track.id == 'Now in library'),
      hasLength(2),
    );
    container
        .read(libraryFilterPreferencesProvider.notifier)
        .addExcludedKeyword('Undated');
    expect(container.read(countedOutsideTracksProvider), isEmpty);
    expect(container.read(countedListeningOverviewProvider).totalPlayCount, 15);
  });
}
