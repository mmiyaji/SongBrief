import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/music_stats_repository.dart';
import '../../domain/library_overview.dart';
import '../../domain/library_track.dart';
import '../../domain/supplemental_listening_history.dart';
import '../../settings/library_filter_preferences.dart';
import '../../settings/supplemental_history_preferences.dart';
import 'home_controller.dart';
import 'supplemental_history_controller.dart';

// A supplemental event must not rebuild the native matching index.
final _nativeTrackCatalogProvider = Provider<LibraryTrackCatalog>((ref) {
  final overview = ref.watch(
    musicStatsControllerProvider.select(
      (value) => value.asData?.value.overview,
    ),
  );
  return LibraryTrackCatalog()..replace(overview?.tracks ?? const []);
});

/// Only songs absent from the unfiltered library contribute supplemental plays.
/// Native snapshots and the library's own counts remain authoritative.
final countedOutsideTracksProvider = Provider<List<LibraryTrack>>((ref) {
  if (!ref.watch(supplementalHistoryIncludedProvider)) return const [];
  final history = ref.watch(supplementalHistoryProvider);
  final stats = ref.watch(musicStatsControllerProvider).asData?.value;
  final repository = ref.watch(musicStatsRepositoryProvider);
  final filters = ref.watch(libraryFilterPreferencesProvider);
  if (stats == null || stats.isDemo) return const [];
  final native = ref.watch(_nativeTrackCatalogProvider);
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
  final native = ref.watch(
    musicStatsControllerProvider.select(
      (value) => value.asData?.value.overview,
    ),
  );
  final supplemental = ref.watch(countedOutsideTracksProvider);
  if (native == null) return LibraryOverview.empty(isDemo: false);
  if (supplemental.isEmpty) return native;
  return native.withSupplementalTracks(supplemental);
});

final supplementalUndatedTrackCountProvider = Provider<int>(
  (ref) => ref
      .watch(countedOutsideTracksProvider)
      .where((track) => track.lastPlayedAt == null)
      .length,
);

/// Dated evidence remains available after a song is matched in the library.
/// Daily/interval projections remove only plays already covered by snapshots;
/// lifetime totals still use [countedOutsideTracksProvider].
final countedSupplementalEventsProvider =
    Provider<List<SupplementalListeningEvent>>((ref) {
      if (!ref.watch(supplementalHistoryIncludedProvider)) return const [];
      final stats = ref.watch(musicStatsControllerProvider).asData?.value;
      if (stats == null || stats.isDemo) return const [];
      final native = ref.watch(_nativeTrackCatalogProvider);
      final repository = ref.watch(musicStatsRepositoryProvider);
      final filters = ref.watch(libraryFilterPreferencesProvider);
      final events = ref.watch(supplementalHistoryProvider).calendarEvents;
      final visible = <(String, int), SupplementalListeningEvent>{};
      for (final event in events) {
        final matched =
            repository.libraryTrackMatching(event.track) ??
            native.match(event.track);
        final track = matched ?? event.track;
        if (filters.excludes(track)) continue;
        final key = (track.id, event.playedAt.microsecondsSinceEpoch);
        final previous = visible[key];
        if (previous == null ||
            previous.isObservation && !event.isObservation) {
          visible[key] = SupplementalListeningEvent(
            track: matched == null
                ? track
                : matched.copyWith(
                    playCount: 1,
                    skipCount: 0,
                    lastPlayedAt: event.playedAt,
                    lastPlayedAtIsObservation: event.isObservation,
                  ),
            playedAt: event.playedAt,
            isObservation: event.isObservation,
          );
        }
      }
      return List.unmodifiable(visible.values);
    });

/// Minimums with neither a playback date nor a retained observation day.
final calendarUnplacedSupplementalTrackCountProvider = Provider<int>((ref) {
  final outside = ref.watch(countedOutsideTracksProvider);
  final calendarCatalog = LibraryTrackCatalog()
    ..replace(
      ref
          .watch(countedSupplementalEventsProvider)
          .map((event) => event.track)
          .toList(),
    );
  return outside.where((track) => calendarCatalog.match(track) == null).length;
});
