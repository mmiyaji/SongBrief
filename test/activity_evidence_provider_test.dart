import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';
import 'package:songbrief/src/features/home/counted_listening_provider.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/supplemental_history_preferences.dart';

const native = LibraryTrack(
  id: 'native',
  title: 'snow drop',
  artist: "L'Arc-en-Ciel",
  albumTitle: 'snow drop - Single',
  appleMusicStoreId: '1536479228',
  duration: Duration(seconds: 275),
  playCount: 15,
  skipCount: 2,
  isCloudItem: true,
  genre: 'Rock',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('synced evidence stays dated after library reclassification without changing native totals', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        musicDataSharedPreferencesProvider.overrideWithValue(prefs),
        musicStatsControllerProvider.overrideWith(_Stats.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(musicStatsControllerProvider.future);
    final at = DateTime(2026, 10, 30, 17);
    final remote = const SupplementalListeningHistory.empty().observe(
      native,
      at: at,
    );
    await container
        .read(supplementalHistoryProvider.notifier)
        .mergeRemote(remote);
    expect(container.read(countedListeningOverviewProvider).totalPlayCount, 1);
    expect(
      container
          .read(countedSupplementalEventsProvider)
          .single
          .playedAt
          .toLocal(),
      at,
    );

    (container.read(musicStatsControllerProvider.notifier) as _Stats)
        .register();
    expect(container.read(countedOutsideTracksProvider), isEmpty);
    expect(container.read(countedListeningOverviewProvider).totalPlayCount, 15);
    final event = container.read(countedSupplementalEventsProvider).single;
    expect(event.track.id, 'native');
    expect(event.playedAt.toLocal(), at);
    expect(event.isObservation, isTrue);
    expect(
      container
          .read(musicStatsControllerProvider)
          .requireValue
          .snapshotHistory
          .snapshotCount,
      0,
    );

    final encoded = container.read(supplementalHistoryProvider).encode();
    await container
        .read(supplementalHistoryIncludedProvider.notifier)
        .setEnabled(false);
    expect(container.read(countedSupplementalEventsProvider), isEmpty);
    expect(container.read(supplementalHistoryProvider).encode(), encoded);
    await container
        .read(supplementalHistoryIncludedProvider.notifier)
        .setEnabled(true);
    expect(container.read(countedSupplementalEventsProvider), hasLength(1));

    // Exclusion uses the matched library's metadata, including fields absent
    // from MusicKit history, so a history row cannot bypass a native filter.
    container
        .read(libraryFilterPreferencesProvider.notifier)
        .addExcludedGenre('Rock');
    expect(container.read(countedSupplementalEventsProvider), isEmpty);
  });
}

class _Stats extends MusicStatsController {
  @override
  Future<MusicStatsState> build() async => _state(const []);
  void register() => state = AsyncData(_state(const [native]));
  MusicStatsState _state(List<LibraryTrack> tracks) => MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: LibraryOverview.fromTracks(tracks, isDemo: false),
    snapshotHistory: SnapshotHistory.empty,
  );
}
