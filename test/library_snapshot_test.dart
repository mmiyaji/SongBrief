import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';

void main() {
  test('keeps one snapshot per day and replaces the same day', () {
    final first = DailyLibrarySnapshot.fromOverview(
      _overview(playCount: 3),
      capturedAt: DateTime(2026, 7, 1, 8),
    );
    final second = DailyLibrarySnapshot.fromOverview(
      _overview(playCount: 5),
      capturedAt: DateTime(2026, 7, 1, 22),
    );

    final history = SnapshotHistory.empty
        .withSnapshot(first)
        .withSnapshot(second);

    expect(history.snapshots, hasLength(1));
    expect(history.latest?.totalPlayCount, 5);
    expect(history.latest?.capturedAt.hour, 22);
  });

  test('calculates positive deltas between snapshots', () {
    final previous = DailyLibrarySnapshot.fromOverview(
      _overview(playCount: 3, skipCount: 1),
      capturedAt: DateTime(2026, 7, 1, 8),
    );
    final current = DailyLibrarySnapshot.fromOverview(
      _overview(playCount: 8, skipCount: 2),
      capturedAt: DateTime(2026, 7, 4, 9),
    );

    final delta = SnapshotHistory.empty
        .withSnapshot(previous)
        .withSnapshot(current)
        .latestDelta;

    expect(delta?.observedDays, 3);
    expect(delta?.totalPlayDelta, 5);
    expect(delta?.totalSkipDelta, 1);
    expect(delta?.trackDeltas.single.playDelta, 5);
  });
}

LibraryOverview _overview({required int playCount, int skipCount = 0}) {
  return LibraryOverview.fromTracks([
    LibraryTrack(
      id: 'track-1',
      title: 'Snapshot Song',
      artist: 'Snapshot Artist',
      albumTitle: 'Snapshot Album',
      duration: const Duration(minutes: 4),
      playCount: playCount,
      skipCount: skipCount,
      lastPlayedAt: DateTime(2026, 7, 1),
      isCloudItem: false,
    ),
  ], isDemo: false);
}
