import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/widgets/home_widget_bridge.dart';

void main() {
  test('home widget summary uses the latest observed delta', () {
    final history = SnapshotHistory(
      snapshots: [
        _snapshot(day: 1, plays: 10, skips: 2, seconds: 1800, trackPlays: 4),
        _snapshot(day: 3, plays: 18, skips: 5, seconds: 3600, trackPlays: 9),
      ],
    );

    final summary = HomeWidgetSummary.fromHistory(history)!;
    expect(summary.snapshotCount, 2);
    expect(summary.observedDays, 2);
    expect(summary.playDelta, 8);
    expect(summary.skipDelta, 3);
    expect(summary.listeningSecondsDelta, 1800);
    expect(summary.topTrackTitle, 'Signal');
    expect(summary.topTrackPlayDelta, 5);
    expect(summary.dailyPlayDeltas, hasLength(7));
    expect(summary.dailyPlayDeltas.where((delta) => delta.hasData), isEmpty);
    expect(summary.recent7PlayDelta, 0);
    expect(summary.previous7PlayDelta, 0);
  });

  test('home widget summary is absent without a listening record', () {
    expect(HomeWidgetSummary.fromHistory(SnapshotHistory.empty), isNull);
  });

  test('home widget summary exposes seven consecutive daily deltas', () {
    final history = SnapshotHistory(
      snapshots: [
        _snapshot(day: 1, plays: 10, skips: 0, seconds: 100, trackPlays: 1),
        _snapshot(day: 2, plays: 14, skips: 0, seconds: 200, trackPlays: 2),
        _snapshot(day: 3, plays: 14, skips: 0, seconds: 200, trackPlays: 2),
        _snapshot(day: 5, plays: 20, skips: 0, seconds: 300, trackPlays: 3),
      ],
    );

    final deltas = HomeWidgetSummary.fromHistory(history)!.dailyPlayDeltas;

    expect(deltas.map((delta) => delta.dateKey), [
      '2026-06-29',
      '2026-06-30',
      '2026-07-01',
      '2026-07-02',
      '2026-07-03',
      '2026-07-04',
      '2026-07-05',
    ]);
    expect(deltas.map((delta) => delta.playDelta), [0, 0, 0, 4, 0, 0, 0]);
    expect(deltas.map((delta) => delta.hasData), [
      false,
      false,
      false,
      true,
      true,
      false,
      false,
    ]);
  });

  test('home widget daily trend does not compare different filters', () {
    final history = SnapshotHistory(
      snapshots: [
        _snapshot(
          day: 1,
          plays: 10,
          skips: 0,
          seconds: 100,
          trackPlays: 1,
          filterSignature: 'before',
        ),
        _snapshot(
          day: 2,
          plays: 14,
          skips: 0,
          seconds: 200,
          trackPlays: 2,
          filterSignature: 'after',
        ),
      ],
    );

    final latest = HomeWidgetSummary.fromHistory(history)!.dailyPlayDeltas.last;

    expect(latest.hasData, isFalse);
    expect(latest.playDelta, 0);
  });

  test('home widget summary compares recent and previous seven days', () {
    var plays = 0;
    final snapshots = <DailyLibrarySnapshot>[];
    for (var day = 1; day <= 15; day += 1) {
      plays += day <= 8 ? 2 : 3;
      snapshots.add(
        _snapshot(
          day: day,
          plays: plays,
          skips: 0,
          seconds: plays * 60,
          trackPlays: plays,
        ),
      );
    }

    final summary = HomeWidgetSummary.fromHistory(
      SnapshotHistory(snapshots: snapshots),
    )!;

    expect(summary.recent7PlayDelta, 21);
    expect(summary.previous7PlayDelta, 14);
    expect(summary.recent7ListeningSecondsDelta, 21 * 60);
    expect(summary.recent7ObservedDays, 7);
    expect(summary.previous7ObservedDays, 7);
    expect(summary.dailyPlayDeltas.map((value) => value.playDelta), [
      3,
      3,
      3,
      3,
      3,
      3,
      3,
    ]);
    expect(summary.toMap()['recent7PlayDelta'], summary.recent7PlayDelta);
  });
}

DailyLibrarySnapshot _snapshot({
  required int day,
  required int plays,
  required int skips,
  required int seconds,
  required int trackPlays,
  String? filterSignature,
}) {
  return DailyLibrarySnapshot(
    dateKey: '2026-07-${day.toString().padLeft(2, '0')}',
    capturedAt: DateTime(2026, 7, day, 12),
    source: 'foreground',
    trackCount: 1,
    totalPlayCount: plays,
    totalSkipCount: skips,
    totalListeningSeconds: seconds,
    filterSignature: filterSignature,
    tracks: [
      TrackCounterSnapshot(
        id: 'track-1',
        title: 'Signal',
        artist: 'Northbound',
        albumTitle: 'Transit',
        playCount: trackPlays,
        skipCount: skips,
        listeningSeconds: seconds,
      ),
    ],
  );
}
