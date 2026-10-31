import 'library_snapshot.dart';
import 'library_track.dart';
import 'supplemental_listening_history.dart';

// Snapshot values are immutable after construction. Weakly keying the current
// snapshot lets repeated calendar and trend projections share comparisons
// without retaining old histories.
final Expando<Map<DailyLibrarySnapshot, SnapshotDelta?>> _deltaCache =
    Expando<Map<DailyLibrarySnapshot, SnapshotDelta?>>(
      'listeningActivityDeltaCache',
    );

/// Compares one snapshot pair and caches the result by object identity.
SnapshotDelta? listeningActivityDelta({
  required DailyLibrarySnapshot previous,
  required DailyLibrarySnapshot current,
}) {
  final byPrevious = _deltaCache[current] ??=
      <DailyLibrarySnapshot, SnapshotDelta?>{};
  if (byPrevious.containsKey(previous)) return byPrevious[previous];
  final delta = SnapshotDelta.compare(previous: previous, current: current);
  byPrevious[previous] = delta;
  return delta;
}

/// Removes supplemental plays already represented by native counter deltas.
///
/// Snapshot counters only provide a minimum count over an interval, so events
/// are consumed in timestamp order up to that count. Unmatched events remain
/// additive; their observation marker is preserved unchanged.
List<SupplementalListeningEvent> uncoveredListeningEvents({
  required SnapshotHistory history,
  required List<SupplementalListeningEvent> events,
  required bool dailyOnly,
}) => projectListeningEvents(
  history: history,
  events: events,
  dailyOnly: dailyOnly,
).uncoveredEvents;

class ListeningEventProjection {
  const ListeningEventProjection({
    required this.uncoveredEvents,
    required this.relocations,
  });

  final List<SupplementalListeningEvent> uncoveredEvents;
  final List<ListeningEventRelocation> relocations;
}

class ListeningEventRelocation {
  const ListeningEventRelocation({
    required this.event,
    required this.nativeCapturedAt,
    required this.nativeTrackId,
  });

  final SupplementalListeningEvent event;
  final DateTime nativeCapturedAt;
  final String nativeTrackId;
}

ListeningEventProjection projectListeningEvents({
  required SnapshotHistory history,
  required List<SupplementalListeningEvent> events,
  required bool dailyOnly,
}) {
  final unique = <String, SupplementalListeningEvent>{};
  for (final event in events) {
    final key =
        '${event.track.id}\u0000${event.playedAt.microsecondsSinceEpoch}';
    final previous = unique[key];
    if (previous == null || previous.isObservation && !event.isObservation) {
      unique[key] = event;
    }
  }
  final sorted = unique.values.toList()
    ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
  final uncovered = <SupplementalListeningEvent>[];
  final coveredKeys = <String>{};
  final relocations = <ListeningEventRelocation>[];
  var eventIndex = 0;

  for (var i = 1; i < history.snapshots.length; i++) {
    final previous = history.snapshots[i - 1];
    final current = history.snapshots[i];
    final delta = listeningActivityDelta(previous: previous, current: current);
    if (delta == null || (dailyOnly && delta.observedDays != 1)) continue;
    if (!current.capturedAt.isAfter(previous.capturedAt)) continue;

    while (eventIndex < sorted.length &&
        !sorted[eventIndex].playedAt.isAfter(previous.capturedAt)) {
      uncovered.add(sorted[eventIndex++]);
    }
    final intervalEvents = <SupplementalListeningEvent>[];
    while (eventIndex < sorted.length &&
        !sorted[eventIndex].playedAt.isAfter(current.capturedAt)) {
      intervalEvents.add(sorted[eventIndex++]);
    }
    // An observation timestamp confirms a minimum play, but does not establish
    // its actual play time. It can therefore be covered by a same-day native
    // counter even when confirmation arrived after the snapshot was captured.
    final lateObservationStart = _lowerBound(sorted, current.capturedAt);
    for (var j = lateObservationStart; j < sorted.length; j++) {
      final event = sorted[j];
      if (!_sameLocalDay(event.playedAt, current.capturedAt)) break;
      if (event.isObservation && event.playedAt.isAfter(current.capturedAt)) {
        intervalEvents.add(event);
      }
    }
    final byId = <String, List<_TrackBudget>>{};
    final byMetadata = <String, List<_TrackBudget>>{};
    final byTitleArtist = <String, List<_TrackBudget>>{};
    var remainingTotal = delta.totalPlayDelta;
    for (final track in delta.trackDeltas) {
      if (track.playDelta <= 0) continue;
      final budget = _TrackBudget(track, track.playDelta);
      byId.putIfAbsent(track.id, () => []).add(budget);
      final key = _metadataKey(track.title, track.artist, track.albumTitle);
      byMetadata.putIfAbsent(key, () => []).add(budget);
      final titleArtist = _titleArtistKey(track.title, track.artist);
      byTitleArtist.putIfAbsent(titleArtist, () => []).add(budget);
    }
    for (final event in intervalEvents) {
      if (coveredKeys.contains(_eventKey(event))) continue;
      if (remainingTotal <= 0) {
        uncovered.add(event);
        continue;
      }
      final track = event.track;
      final budget = _matchingBudget(track, byId, byMetadata, byTitleArtist);
      if (budget != null) {
        coveredKeys.add(_eventKey(event));
        budget.remaining -= 1;
        remainingTotal -= 1;
        if (dailyOnly &&
            !event.isObservation &&
            !_sameLocalDay(event.playedAt, current.capturedAt)) {
          relocations.add(
            ListeningEventRelocation(
              event: event,
              nativeCapturedAt: current.capturedAt,
              nativeTrackId: budget.track.id,
            ),
          );
        }
      } else {
        uncovered.add(event);
      }
    }
  }
  while (eventIndex < sorted.length) {
    uncovered.add(sorted[eventIndex++]);
  }
  final remainingByKey = <String, SupplementalListeningEvent>{};
  for (final event in uncovered) {
    if (!coveredKeys.contains(_eventKey(event))) {
      remainingByKey.putIfAbsent(_eventKey(event), () => event);
    }
  }
  final result = remainingByKey.values.toList()
    ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
  return ListeningEventProjection(
    uncoveredEvents: List.unmodifiable(result),
    relocations: List.unmodifiable(relocations),
  );
}

String _eventKey(SupplementalListeningEvent event) =>
    '${event.track.id}\u0000${event.playedAt.microsecondsSinceEpoch}';

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _metadataKey(String title, String artist, String album) =>
    '${_normalize(title)}\u0000${_normalize(artist)}\u0000${_normalize(album)}';

String _titleArtistKey(String title, String artist) =>
    '${_normalize(title)}\u0000${_normalize(artist)}\u0000';

bool _unknownAlbum(String album) {
  final value = _normalize(album);
  return value.isEmpty || value == 'unknown album';
}

int _lowerBound(List<SupplementalListeningEvent> events, DateTime time) {
  var low = 0;
  var high = events.length;
  while (low < high) {
    final middle = (low + high) >> 1;
    if (events[middle].playedAt.isBefore(time)) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

bool _sameLocalDay(DateTime a, DateTime b) =>
    a.toLocal().year == b.toLocal().year &&
    a.toLocal().month == b.toLocal().month &&
    a.toLocal().day == b.toLocal().day;

_TrackBudget? _matchingBudget(
  LibraryTrack event,
  Map<String, List<_TrackBudget>> byId,
  Map<String, List<_TrackBudget>> byMetadata,
  Map<String, List<_TrackBudget>> byTitleArtist,
) {
  final exactId = _available(byId[event.id]);
  if (exactId != null) return exactId;
  final exact = _available(
    byMetadata[_metadataKey(event.title, event.artist, event.albumTitle)],
  );
  if (exact != null || !_unknownAlbum(event.albumTitle)) return exact;
  final wildcard = byTitleArtist[_titleArtistKey(event.title, event.artist)];
  return _available(wildcard);
}

_TrackBudget? _available(List<_TrackBudget>? budgets) {
  if (budgets == null) return null;
  for (final budget in budgets) {
    if (budget.remaining > 0) return budget;
  }
  return null;
}

class _TrackBudget {
  _TrackBudget(this.track, this.remaining);

  final TrackCounterDelta track;
  int remaining;
}
