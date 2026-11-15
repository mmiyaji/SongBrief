import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';

void main() {
  test('optimized demo history preserves every original daily counter', () async {
    final state = await MusicStatsRepository(
      const PlatformMusicLibraryClient(),
      LibrarySnapshotRepository(),
    ).load();
    final snapshots = state.snapshotHistory.snapshots;
    expect(snapshots, hasLength(90));
    final counters = [
      for (final s in snapshots)
        [
          s.totalPlayCount,
          s.totalSkipCount,
          s.totalListeningSeconds,
          for (final t in s.tracks)
            [t.id, t.playCount, t.skipCount, t.listeningSeconds],
        ],
    ];
    // Captured from the original generator, before optimizing its history loop.
    expect(
      counters,
      jsonDecode(
        File('test/fixtures/demo-counter-baseline.json').readAsStringSync(),
      ),
    );
    expect(snapshots.last.totalPlayCount, state.overview.totalPlayCount);
    expect(snapshots.last.totalSkipCount, state.overview.totalSkipCount);
    for (var i = 0; i < snapshots.length; i++) {
      final s = snapshots[i];
      expect(s.source, 'demo');
      expect(s.capturedAt.hour, 6);
      expect(s.trackCount, state.overview.totalTracks);
      if (i > 0) {
        expect(s.dateKey.compareTo(snapshots[i - 1].dateKey), greaterThan(0));
      }
      for (final t in s.tracks) {
        final native = state.overview.trackById(t.id)!;
        expect(t.title, native.title);
        expect(t.artist, native.artist);
        expect(t.albumTitle, native.albumTitle);
        expect(t.albumArtist, native.albumArtist);
        expect(t.genre, native.genre);
        expect(t.lastPlayedAt, native.lastPlayedAt);
      }
    }
  });
}
