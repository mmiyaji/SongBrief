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
  });

  test('home widget summary is absent without a listening record', () {
    expect(HomeWidgetSummary.fromHistory(SnapshotHistory.empty), isNull);
  });
}

DailyLibrarySnapshot _snapshot({
  required int day,
  required int plays,
  required int skips,
  required int seconds,
  required int trackPlays,
}) {
  return DailyLibrarySnapshot(
    dateKey: '2026-07-${day.toString().padLeft(2, '0')}',
    capturedAt: DateTime(2026, 7, day, 12),
    source: 'foreground',
    trackCount: 1,
    totalPlayCount: plays,
    totalSkipCount: skips,
    totalListeningSeconds: seconds,
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
