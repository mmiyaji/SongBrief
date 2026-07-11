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

  test('combines counter deltas for duplicate synced track ids', () {
    final previous = _snapshotWithTracks(
      date: DateTime(2026, 7, 11),
      tracks: [
        _counter(id: 'local-id', playCount: 3),
        _counter(id: 'cloud-id', playCount: 5),
      ],
    );
    final current = _snapshotWithTracks(
      date: DateTime(2026, 7, 12),
      tracks: [
        _counter(id: 'local-id', playCount: 4),
        _counter(id: 'cloud-id', playCount: 6),
      ],
    );

    final delta = SnapshotDelta.compare(previous: previous, current: current);

    expect(delta.trackDeltas, hasLength(1));
    expect(delta.trackDeltas.single.title, 'Synced Song');
    expect(delta.trackDeltas.single.playDelta, 2);
  });

  test('keeps same-title tracks on different albums separate', () {
    final previous = _snapshotWithTracks(
      date: DateTime(2026, 7, 11),
      tracks: [
        _counter(id: 'album-a', playCount: 3, albumTitle: 'Album A'),
        _counter(id: 'album-b', playCount: 5, albumTitle: 'Album B'),
      ],
    );
    final current = _snapshotWithTracks(
      date: DateTime(2026, 7, 12),
      tracks: [
        _counter(id: 'album-a', playCount: 4, albumTitle: 'Album A'),
        _counter(id: 'album-b', playCount: 6, albumTitle: 'Album B'),
      ],
    );

    final delta = SnapshotDelta.compare(previous: previous, current: current);

    expect(delta.trackDeltas, hasLength(2));
  });

  test('limits stored track counters for large libraries', () {
    final overview = LibraryOverview.fromTracks(
      List.generate(
        maxSnapshotTrackCounters + 100,
        (index) => LibraryTrack(
          id: 'track-${index.toString().padLeft(4, '0')}',
          title: 'Snapshot Song $index',
          artist: 'Snapshot Artist',
          albumTitle: 'Snapshot Album',
          duration: const Duration(minutes: 4),
          playCount: index,
          skipCount: index % 5,
          lastPlayedAt: DateTime(2026, 7, 1).add(Duration(minutes: index)),
          isCloudItem: false,
        ),
      ),
      isDemo: false,
    );

    final snapshot = DailyLibrarySnapshot.fromOverview(overview);

    expect(snapshot.trackCount, maxSnapshotTrackCounters + 100);
    expect(snapshot.tracks, hasLength(maxSnapshotTrackCounters));
  });

  test('round-trips the library filter signature', () {
    final snapshot = DailyLibrarySnapshot.fromOverview(
      _overview(playCount: 3),
      capturedAt: DateTime(2026, 7, 1, 8),
      filterSignature: 'deadbeef',
    );

    final decoded = DailyLibrarySnapshot.fromJson(snapshot.toJson());

    expect(decoded.filterSignature, 'deadbeef');
    expect(decoded.toJson(), snapshot.toJson());
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

TrackCounterSnapshot _counter({
  required String id,
  required int playCount,
  String albumTitle = 'Synced Album',
}) {
  return TrackCounterSnapshot(
    id: id,
    title: 'Synced Song',
    artist: 'Synced Artist',
    albumTitle: albumTitle,
    playCount: playCount,
    skipCount: 0,
    listeningSeconds: playCount * 180,
  );
}

DailyLibrarySnapshot _snapshotWithTracks({
  required DateTime date,
  required List<TrackCounterSnapshot> tracks,
}) {
  return DailyLibrarySnapshot(
    dateKey: snapshotDateKey(date),
    capturedAt: date,
    source: 'test',
    trackCount: tracks.length,
    totalPlayCount: tracks.fold(0, (sum, track) => sum + track.playCount),
    totalSkipCount: 0,
    totalListeningSeconds: tracks.fold(
      0,
      (sum, track) => sum + track.listeningSeconds,
    ),
    tracks: tracks,
  );
}
