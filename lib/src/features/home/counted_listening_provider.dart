import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/music_stats_repository.dart';
import '../../domain/library_overview.dart';
import '../../domain/library_track.dart';
import '../../domain/supplemental_listening_history.dart';
import '../../settings/library_filter_preferences.dart';
import 'home_controller.dart';
import 'supplemental_history_controller.dart';

/// Only songs absent from the unfiltered library contribute supplemental plays.
/// Native snapshots and the library's own counts remain authoritative.
final countedOutsideTracksProvider = Provider<List<LibraryTrack>>((ref) {
  final history = ref.watch(supplementalHistoryProvider);
  final stats = ref.watch(musicStatsControllerProvider).asData?.value;
  final repository = ref.watch(musicStatsRepositoryProvider);
  final filters = ref.watch(libraryFilterPreferencesProvider);
  if (stats == null || stats.isDemo) return const [];
  final native = LibraryTrackCatalog()..replace(stats.overview.tracks);
  return List.unmodifiable(
    history.tracks.where(
      (track) =>
          repository.libraryTrackMatching(track) == null &&
          native.match(track) == null &&
          !filters.excludes(track),
    ),
  );
});

final countedListeningOverviewProvider = Provider<LibraryOverview>((ref) {
  final native = ref.watch(musicStatsControllerProvider).asData?.value.overview;
  final supplemental = ref.watch(countedOutsideTracksProvider);
  if (native == null) return LibraryOverview.empty(isDemo: false);
  if (supplemental.isEmpty) return native;
  return LibraryOverview.fromTracks([
    ...native.tracks,
    ...supplemental,
  ], isDemo: false);
});

final supplementalUndatedTrackCountProvider = Provider<int>(
  (ref) => ref
      .watch(countedOutsideTracksProvider)
      .where((track) => track.lastPlayedAt == null)
      .length,
);

/// Undated evidence contributes to lifetime minimums, never to a calendar day.
final countedSupplementalEventsProvider =
    Provider<List<SupplementalListeningEvent>>((ref) {
      final visible = LibraryTrackCatalog()
        ..replace(ref.watch(countedOutsideTracksProvider));
      return List.unmodifiable(
        ref
            .watch(supplementalHistoryProvider)
            .datedEvents
            .where((event) => visible.match(event.track) != null),
      );
    });
