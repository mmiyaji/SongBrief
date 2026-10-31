import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/listening_activity.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';

void main() {
  final play = DateTime(2026, 10, 30, 11);
  final captured = DateTime(2026, 10, 30, 12);

  DailyLibrarySnapshot snapshot(
    DateTime at,
    int count, {
    String id = 'native',
  }) {
    final counter = TrackCounterSnapshot(
      id: id,
      title: 'Song',
      artist: 'Artist',
      albumTitle: 'Album',
      playCount: count,
      skipCount: 0,
      listeningSeconds: count * 180,
    );
    return DailyLibrarySnapshot(
      dateKey: snapshotDateKey(at),
      capturedAt: at,
      source: 'test',
      trackCount: 1,
      totalPlayCount: count,
      totalSkipCount: 0,
      totalListeningSeconds: count * 180,
      tracks: [counter],
    );
  }

  LibraryTrack track({String id = 'native', String album = 'Album'}) =>
      LibraryTrack(
        id: id,
        title: 'Song',
        artist: 'Artist',
        albumTitle: album,
        duration: const Duration(minutes: 3),
        playCount: 0,
        skipCount: 0,
        isCloudItem: false,
      );

  test('exact evidence wins over an observation of the same event', () {
    final observation = SupplementalListeningEvent(
      track: track(),
      playedAt: play,
      isObservation: true,
    );
    final exact = SupplementalListeningEvent(track: track(), playedAt: play);
    final events = uncoveredListeningEvents(
      history: SnapshotHistory.empty,
      events: [observation, exact],
      dailyOnly: true,
    );
    expect(events, hasLength(1));
    expect(events.single.isObservation, isFalse);
  });

  test('positive native delta covers one event by metadata alias', () {
    final history = SnapshotHistory(
      snapshots: [
        snapshot(DateTime(2026, 10, 29, 12), 1),
        snapshot(captured, 2),
      ],
    );
    final event = SupplementalListeningEvent(
      track: track(id: 'service'),
      playedAt: play,
    );
    expect(
      uncoveredListeningEvents(
        history: history,
        events: [event],
        dailyOnly: true,
      ),
      isEmpty,
    );
  });

  test(
    'zero delta, pre-baseline, and post-capture actual plays remain additive',
    () {
      final history = SnapshotHistory(
        snapshots: [
          snapshot(DateTime(2026, 10, 29, 12), 1),
          snapshot(captured, 1),
        ],
      );
      final events = [
        SupplementalListeningEvent(
          track: track(),
          playedAt: DateTime(2026, 10, 29, 11),
        ),
        SupplementalListeningEvent(
          track: track(),
          playedAt: DateTime(2026, 10, 30, 13),
        ),
      ];
      expect(
        uncoveredListeningEvents(
          history: history,
          events: events,
          dailyOnly: true,
        ),
        events,
      );
    },
  );

  test('daily mode skips gap intervals while trend mode can cover them', () {
    final history = SnapshotHistory(
      snapshots: [
        snapshot(DateTime(2026, 10, 27, 12), 1),
        snapshot(captured, 2),
      ],
    );
    final event = SupplementalListeningEvent(track: track(), playedAt: play);
    expect(
      uncoveredListeningEvents(
        history: history,
        events: [event],
        dailyOnly: true,
      ),
      [event],
    );
    expect(
      uncoveredListeningEvents(
        history: history,
        events: [event],
        dailyOnly: false,
      ),
      isEmpty,
    );
  });

  test(
    'observation timestamp can be covered on capture day, actual time cannot',
    () {
      final history = SnapshotHistory(
        snapshots: [
          snapshot(DateTime(2026, 10, 29, 12), 1),
          snapshot(captured, 2),
        ],
      );
      final observation = SupplementalListeningEvent(
        track: track(),
        playedAt: DateTime(2026, 10, 30, 17),
        isObservation: true,
      );
      final actual = SupplementalListeningEvent(
        track: track(),
        playedAt: observation.playedAt,
      );
      expect(
        uncoveredListeningEvents(
          history: history,
          events: [observation],
          dailyOnly: true,
        ),
        isEmpty,
      );
      expect(
        uncoveredListeningEvents(
          history: history,
          events: [actual],
          dailyOnly: true,
        ),
        [actual],
      );
    },
  );

  test('same canonical id and timestamp is deduplicated without changing observation', () {
    final history = SnapshotHistory.empty;
    final observation = SupplementalListeningEvent(
      track: track(),
      playedAt: play,
      isObservation: true,
    );
    final result = uncoveredListeningEvents(
      history: history,
      events: [observation, observation],
      dailyOnly: true,
    );
    expect(result, hasLength(1));
    expect(result.single.isObservation, isTrue);
  });

  test(
    'uncovered late observation is returned once when native delta is zero',
    () {
      final history = SnapshotHistory(
        snapshots: [
          snapshot(DateTime(2026, 10, 29, 12), 1),
          snapshot(captured, 1),
        ],
      );
      final observation = SupplementalListeningEvent(
        track: track(),
        playedAt: DateTime(2026, 10, 30, 17),
        isObservation: true,
      );
      expect(
        uncoveredListeningEvents(
          history: history,
          events: [observation],
          dailyOnly: true,
        ),
        [observation],
      );
    },
  );

  test('metadata alias and exact id consume the same native play budget', () {
    final history = SnapshotHistory(
      snapshots: [
        snapshot(DateTime(2026, 10, 29, 12), 1),
        snapshot(captured, 2),
      ],
    );
    final alias = SupplementalListeningEvent(
      track: track(id: 'service'),
      playedAt: play,
    );
    final exactId = SupplementalListeningEvent(
      track: track(),
      playedAt: DateTime(2026, 10, 30, 11, 30),
    );
    expect(
      uncoveredListeningEvents(
        history: history,
        events: [alias, exactId],
        dailyOnly: true,
      ),
      [exactId],
    );
  });

  test('track gain cannot cover events when total native delta is zero', () {
    DailyLibrarySnapshot paired(DateTime at, int songCount, int otherCount) {
      final song = TrackCounterSnapshot(
        id: 'native',
        title: 'Song',
        artist: 'Artist',
        albumTitle: 'Album',
        playCount: songCount,
        skipCount: 0,
        listeningSeconds: 0,
      );
      final other = TrackCounterSnapshot(
        id: 'other',
        title: 'Other',
        artist: 'Artist',
        albumTitle: 'Album',
        playCount: otherCount,
        skipCount: 0,
        listeningSeconds: 0,
      );
      return DailyLibrarySnapshot(
        dateKey: snapshotDateKey(at),
        capturedAt: at,
        source: 'test',
        trackCount: 2,
        totalPlayCount: songCount + otherCount,
        totalSkipCount: 0,
        totalListeningSeconds: 0,
        tracks: [song, other],
      );
    }

    final history = SnapshotHistory(
      snapshots: [
        paired(DateTime(2026, 10, 29, 12), 1, 1),
        paired(captured, 2, 0),
      ],
    );
    final event = SupplementalListeningEvent(track: track(), playedAt: play);
    expect(
      uncoveredListeningEvents(
        history: history,
        events: [event],
        dailyOnly: true,
      ),
      [event],
    );
  });

  test('cross-midnight covered exact play is reported as a relocation', () {
    final previousAt = DateTime(2026, 10, 29, 12);
    final currentAt = DateTime(2026, 10, 30, 12);
    final history = SnapshotHistory(
      snapshots: [snapshot(previousAt, 1), snapshot(currentAt, 2)],
    );
    final event = SupplementalListeningEvent(
      track: track(id: 'service'),
      playedAt: DateTime(2026, 10, 29, 17),
    );
    final projection = projectListeningEvents(
      history: history,
      events: [event],
      dailyOnly: true,
    );
    expect(projection.uncoveredEvents, isEmpty);
    expect(projection.relocations, hasLength(1));
    expect(projection.relocations.single.event, same(event));
    expect(projection.relocations.single.nativeCapturedAt, currentAt);
    expect(projection.relocations.single.nativeTrackId, 'native');
  });

  test('delta cache reuses object-pair results and isolates new snapshots', () {
    final previous = snapshot(DateTime(2026, 10, 29, 12), 1);
    final current = snapshot(captured, 2);
    final cached = listeningActivityDelta(previous: previous, current: current);
    expect(
      listeningActivityDelta(previous: previous, current: current),
      same(cached),
    );

    final replacementCurrent = snapshot(captured, 2);
    final recomputed = listeningActivityDelta(
      previous: previous,
      current: replacementCurrent,
    );
    expect(recomputed, isNot(same(cached)));
    expect(recomputed!.totalPlayDelta, cached!.totalPlayDelta);
  });
}
