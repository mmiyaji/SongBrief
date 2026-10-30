import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/music_stats_repository.dart';
import '../../domain/library_overview.dart';
import '../../domain/library_snapshot.dart';
import '../../domain/library_track.dart';
import '../../domain/supplemental_listening_history.dart';
import '../../settings/library_filter_preferences.dart';
import 'home_controller.dart';
import 'counted_listening_provider.dart';
import 'supplemental_history_controller.dart';

/// One cached projection shared by the library and Playing views. It never
/// writes evidence dates back to native counters or persisted snapshots.
final _recentListeningEvidenceProvider = Provider<RecentListeningEvidence>((
  ref,
) {
  final stats = ref.watch(musicStatsControllerProvider).asData?.value;
  final native = stats?.overview ?? LibraryOverview.empty(isDemo: false);
  if (stats == null || stats.isDemo) {
    return RecentListeningEvidence(native, native.recentTrackDetails);
  }
  return buildRecentListeningEvidence(
    nativeOverview: native,
    snapshotHistory: stats.snapshotHistory,
    recentTracks: ref.watch(recentAppleMusicPlaysProvider),
    observedTracks: ref.watch(outsideLibraryPlaysProvider),
    supplementalEvents: ref.watch(supplementalHistoryProvider).datedEvents,
    visibleOutsideTracks: ref.watch(visibleOutsideLibraryPlaysProvider),
    libraryTrackMatching: ref
        .watch(musicStatsRepositoryProvider)
        .libraryTrackMatching,
    filters: ref.watch(libraryFilterPreferencesProvider),
  );
});

/// Native membership and counters, with display-only recency evidence overlaid.
final libraryRecentOverviewProvider = Provider<LibraryOverview>(
  (ref) => ref.watch(_recentListeningEvidenceProvider).libraryOverview,
);

/// All dated native songs plus the already filtered outside-library rows.
final recentListeningTracksProvider = Provider<List<LibraryTrack>>(
  (ref) => ref.watch(_recentListeningEvidenceProvider).tracks,
);

/// Library browsing may include confirmed outside-library history, but it does
/// not change membership, native counters or persisted daily snapshots.
final librarySupplementalTracksProvider = Provider<List<LibraryTrack>>((ref) {
  final counted = ref.watch(countedOutsideTracksProvider);
  if (counted.isEmpty) return const [];
  final catalog = LibraryTrackCatalog()..replace(counted);
  final byId = {for (final track in counted) track.id: track};
  for (final recent in ref.watch(recentListeningTracksProvider)) {
    final match = catalog.match(recent);
    if (match == null || recent.lastPlayedAt == null) continue;
    final current = byId[match.id]!;
    final date = current.lastPlayedAt;
    if (date == null || !recent.lastPlayedAt!.isBefore(date)) {
      byId[match.id] = current.copyWith(
        lastPlayedAt: recent.lastPlayedAt,
        lastPlayedAtIsObservation: recent.lastPlayedAtIsObservation,
      );
    }
  }
  return List.unmodifiable(byId.values);
});

final libraryBrowsingOverviewProvider = Provider<LibraryOverview>((ref) {
  return ref
      .watch(libraryRecentOverviewProvider)
      .withSupplementalTracks(ref.watch(librarySupplementalTracksProvider));
});

class RecentListeningEvidence {
  RecentListeningEvidence(this._nativeOverview, this.tracks)
    : _libraryTracks = null;

  RecentListeningEvidence._(
    this._nativeOverview,
    this.tracks,
    this._libraryTracks,
  );

  final LibraryOverview _nativeOverview;
  final List<LibraryTrack>? _libraryTracks;
  // Playing consumes only tracks. Build the library's search/sort indexes only
  // when the library tab actually requests them, once per evidence projection.
  late final LibraryOverview libraryOverview = _libraryTracks == null
      ? _nativeOverview
      : LibraryOverview.fromTracks(
          _libraryTracks,
          isDemo: _nativeOverview.isDemo,
        );
  final List<LibraryTrack> tracks;
}

/// Public pure projection so recency rules can be checked without platform IO.
RecentListeningEvidence buildRecentListeningEvidence({
  required LibraryOverview nativeOverview,
  SnapshotHistory snapshotHistory = SnapshotHistory.empty,
  List<LibraryTrack> recentTracks = const [],
  List<LibraryTrack> observedTracks = const [],
  List<SupplementalListeningEvent> supplementalEvents = const [],
  List<LibraryTrack> visibleOutsideTracks = const [],
  LibraryTrack? Function(LibraryTrack)? libraryTrackMatching,
  LibraryFilterPreferences? filters,
}) {
  final nativeTracks =
      filters?.apply(nativeOverview.tracks) ?? nativeOverview.tracks;
  final byId = {for (final track in nativeTracks) track.id: track};
  // Keep the unfiltered index: an excluded library song must never reappear as
  // an outside-library result through a differently identified history row.
  final nativeCatalog = LibraryTrackCatalog()..replace(nativeOverview.tracks);
  final outsideCatalog = LibraryTrackCatalog()..replace(visibleOutsideTracks);
  final observedCatalog = LibraryTrackCatalog()..replace(observedTracks);
  final outsideById = {
    for (final track in visibleOutsideTracks)
      track.id:
          observedCatalog.match(track)?.lastPlayedAt == track.lastPlayedAt &&
              track.lastPlayedAt != null
          ? track.copyWith(lastPlayedAtIsObservation: true)
          : track,
  };

  LibraryTrack? matchNative(LibraryTrack row) =>
      libraryTrackMatching?.call(row) ?? nativeCatalog.match(row);

  void applyDate(
    Map<String, LibraryTrack> target,
    LibraryTrack track,
    DateTime? at, {
    required bool observation,
  }) {
    if (at == null) return;
    final current = target[track.id];
    if (current == null) return;
    final previous = current.lastPlayedAt;
    if (previous != null &&
        (previous.isAfter(at) ||
            (previous.isAtSameMomentAs(at) &&
                (!current.lastPlayedAtIsObservation || observation)))) {
      return;
    }
    target[track.id] = current.copyWith(
      lastPlayedAt: at,
      lastPlayedAtIsObservation: observation,
    );
  }

  void applyRow(LibraryTrack row, {required bool observation}) {
    final match = matchNative(row);
    if (match != null) {
      applyDate(byId, match, row.lastPlayedAt, observation: observation);
      return;
    }
    final outside = outsideCatalog.match(row);
    if (outside != null) {
      applyDate(
        outsideById,
        outside,
        row.lastPlayedAt,
        observation: observation,
      );
    }
  }

  for (final row in recentTracks) {
    applyRow(row, observation: row.lastPlayedAtIsObservation);
  }
  for (final row in observedTracks) {
    applyRow(row, observation: true);
  }
  for (final event in supplementalEvents) {
    applyRow(
      event.track.copyWith(lastPlayedAt: event.playedAt),
      observation: event.track.lastPlayedAtIsObservation,
    );
  }

  // Detailed history is already chronological. Compare raw ID counters once
  // per adjacent pair, avoiding SnapshotDelta's normalization and rank sorting.
  final snapshots = snapshotHistory.snapshots;
  final unresolved = byId.keys.toSet();
  for (
    var index = snapshots.length - 1;
    index > 0 && unresolved.isNotEmpty;
    index--
  ) {
    final previous = snapshots[index - 1];
    final current = snapshots[index];
    unresolved.removeWhere((id) {
      final date = byId[id]!.lastPlayedAt;
      return date != null && !date.isBefore(current.capturedAt);
    });
    if (unresolved.isEmpty) break;
    if (!previous.hasCompatibleFilterProfileWith(current)) continue;
    final previousCounts = {
      for (final track in previous.tracks)
        if (unresolved.contains(track.id)) track.id: track.playCount,
    };
    final dayGap =
        DateTime.utc(
              current.capturedAt.year,
              current.capturedAt.month,
              current.capturedAt.day,
            )
            .difference(
              DateTime.utc(
                previous.capturedAt.year,
                previous.capturedAt.month,
                previous.capturedAt.day,
              ),
            )
            .inDays;
    for (final counter in current.tracks) {
      if (!unresolved.contains(counter.id)) continue;
      final baseline = previousCounts[counter.id];
      final native = byId[counter.id];
      if (baseline == null || native == null || counter.playCount <= baseline) {
        continue;
      }
      applyDate(byId, native, counter.lastPlayedAt, observation: false);
      final latest = byId[native.id]!;
      final hasExactTimeInInterval =
          !latest.lastPlayedAtIsObservation &&
          latest.lastPlayedAt != null &&
          latest.lastPlayedAt!.isAfter(previous.capturedAt);
      if (dayGap == 1 && !hasExactTimeInInterval) {
        applyDate(byId, native, current.capturedAt, observation: true);
      }
      if (dayGap == 1 || hasExactTimeInInterval) unresolved.remove(counter.id);
    }
  }

  final libraryTracks = [for (final track in nativeTracks) byId[track.id]!];
  final changed =
      libraryTracks.length != nativeOverview.tracks.length ||
      libraryTracks.indexed.any(
        (entry) => !identical(entry.$2, nativeOverview.tracks[entry.$1]),
      );
  final tracks =
      <LibraryTrack>[
        ...libraryTracks.where((track) => track.lastPlayedAt != null),
        for (final track in visibleOutsideTracks)
          if (matchNative(track) == null) outsideById[track.id]!,
      ].indexed.toList()..sort((a, b) {
        final aTime = a.$2.lastPlayedAt;
        final bTime = b.$2.lastPlayedAt;
        if (aTime == null && bTime == null) return a.$1.compareTo(b.$1);
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        final comparison = bTime.compareTo(aTime);
        return comparison == 0 ? a.$1.compareTo(b.$1) : comparison;
      });
  return RecentListeningEvidence._(
    nativeOverview,
    List.unmodifiable(tracks.map((entry) => entry.$2)),
    changed ? libraryTracks : null,
  );
}
