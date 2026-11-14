import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/recent_listening_provider.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

LibraryTrack song(
  String id,
  String title,
  String store, {
  int plays = 0,
  DateTime? at,
}) => LibraryTrack(
  id: id,
  title: title,
  artist: "L'Arc-en-Ciel",
  albumTitle: 'Album',
  appleMusicStoreId: store,
  duration: const Duration(minutes: 4),
  playCount: plays,
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
      fixture([song('native', 'Gyakko', '42', plays: 10)]);
  void replace(List<LibraryTrack> tracks) => state = AsyncData(fixture(tracks));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'browsing includes supplemental songs without changing native membership',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final at = DateTime(2026, 10, 30, 10, 36);
      final outside = song('musickit:99', 'STAY AWAY', '99', at: at);
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(prefs),
          musicStatsControllerProvider.overrideWith(_Stats.new),
          recentAppleMusicPlaysProvider.overrideWith(() => _Recent([outside])),
        ],
      );
      addTearDown(container.dispose);
      await container.read(musicStatsControllerProvider.future);
      final ledger = container.read(supplementalHistoryProvider.notifier);
      ledger.ingest([outside, outside]);
      final browse = container.read(libraryBrowsingOverviewProvider);
      expect(browse.tracksByRecent.first.title, 'STAY AWAY');
      expect(browse.filteredTracks('stay away').single.playCount, 1);
      expect(browse.totalPlayCount, 11);
      expect(container.read(libraryRecentOverviewProvider).totalTracks, 1);
      expect(container.read(libraryRecentOverviewProvider).totalPlayCount, 10);
      final stats = container.read(musicStatsControllerProvider).requireValue;
      expect(stats.overview.totalTracks, 1);
      expect(stats.snapshotHistory.snapshots, isEmpty);

      // Once matched in the real library, its native counter replaces the minimum.
      (container.read(musicStatsControllerProvider.notifier) as _Stats).replace(
        [
          song('native', 'Gyakko', '42', plays: 10),
          song('native-stay', 'STAY AWAY', '99', plays: 20, at: at),
        ],
      );
      expect(container.read(librarySupplementalTracksProvider), isEmpty);
      expect(
        container.read(libraryBrowsingOverviewProvider).totalPlayCount,
        30,
      );
      expect(
        container.read(libraryBrowsingOverviewProvider).filteredTracks('stay'),
        hasLength(1),
      );

      container
          .read(libraryFilterPreferencesProvider.notifier)
          .addExcludedKeyword('STAY');
      expect(
        container.read(libraryBrowsingOverviewProvider).filteredTracks('stay'),
        isEmpty,
      );
    },
  );
}

class _Recent extends RecentAppleMusicPlaysController {
  _Recent(this.rows);
  final List<LibraryTrack> rows;
  @override
  List<LibraryTrack> build() => rows;
}
