import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';

void main() {
  test('syncs playback state from the native current item', () async {
    final repository = _FakeMusicStatsRepository(
      currentPlaybackOverride: const MusicPlaybackSnapshot(
        trackId: 'track-2',
        isPlaying: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(playbackControllerProvider.notifier).syncWithPlayer();

    final state = container.read(playbackControllerProvider);
    expect(state.activeTrackId, 'track-2');
    expect(state.isPlaying, isTrue);
  });

  test('updates playback state from native playback events', () async {
    final events = StreamController<MusicPlaybackSnapshot>();
    final repository = _FakeMusicStatsRepository(playbackEvents: events.stream);
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    addTearDown(events.close);

    container.read(playbackControllerProvider);
    events.add(
      const MusicPlaybackSnapshot(trackId: 'track-3', isPlaying: true),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(playbackControllerProvider);
    expect(state.activeTrackId, 'track-3');
    expect(state.isPlaying, isTrue);
  });

  test('skip syncs playback without reloading the library', () async {
    final repository = _FakeMusicStatsRepository(
      currentPlaybackOverride: const MusicPlaybackSnapshot(
        trackId: 'track-9',
        isPlaying: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(playbackControllerProvider.notifier).skipToNext();

    final state = container.read(playbackControllerProvider);
    expect(repository.skipToNextCalls, 1);
    expect(repository.loadCalls, 0);
    expect(state.activeTrackId, 'track-9');
    expect(state.isPlaying, isTrue);
  });

  test(
    'toggle resumes the active paused track without restarting it',
    () async {
      final repository = _FakeMusicStatsRepository();
      final container = ProviderContainer(
        overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(playbackControllerProvider.notifier);
      await controller.playTrack('track-1');
      await controller.pause();
      await controller.toggleTrack('track-1');

      final state = container.read(playbackControllerProvider);
      expect(repository.playTrackCalls, 1);
      expect(repository.pauseCalls, 1);
      expect(repository.playCalls, 1);
      expect(state.activeTrackId, 'track-1');
      expect(state.isPlaying, isTrue);
    },
  );

  test('restart plays the active paused track from the beginning', () async {
    final repository = _FakeMusicStatsRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(playbackControllerProvider.notifier);
    await controller.playTrack('track-1');
    await controller.pause();
    await controller.restartTrack('track-1');

    final state = container.read(playbackControllerProvider);
    expect(repository.playTrackCalls, 2);
    expect(repository.playCalls, 0);
    expect(repository.pauseCalls, 1);
    expect(state.activeTrackId, 'track-1');
    expect(state.isPlaying, isTrue);
  });
}

class _FakeMusicStatsRepository extends MusicStatsRepository {
  _FakeMusicStatsRepository({
    this.currentPlaybackOverride,
    Stream<MusicPlaybackSnapshot>? playbackEvents,
  }) : playbackEventsOverride =
           playbackEvents ?? const Stream<MusicPlaybackSnapshot>.empty(),
       super(_NoopMusicLibraryClient(), const LibrarySnapshotRepository());

  final MusicPlaybackSnapshot? currentPlaybackOverride;
  final Stream<MusicPlaybackSnapshot> playbackEventsOverride;
  var loadCalls = 0;
  var skipToNextCalls = 0;
  var playTrackCalls = 0;
  var playCalls = 0;
  var pauseCalls = 0;

  @override
  Future<MusicStatsState> load({bool requestAccess = false}) async {
    loadCalls += 1;
    return MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
      overview: LibraryOverview.empty(isDemo: true),
      snapshotHistory: SnapshotHistory.empty,
    );
  }

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() async {
    return currentPlaybackOverride;
  }

  @override
  Stream<MusicPlaybackSnapshot> playbackEvents() => playbackEventsOverride;

  @override
  Future<void> skipToNext() async {
    skipToNextCalls += 1;
  }

  @override
  Future<void> playTrack(String trackId) async {
    playTrackCalls += 1;
  }

  @override
  Future<void> play() async {
    playCalls += 1;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }
}

class _NoopMusicLibraryClient implements MusicLibraryClient {
  @override
  Future<MusicLibraryAuthorizationStatus> authorizationStatus() async {
    return MusicLibraryAuthorizationStatus.unsupported;
  }

  @override
  Future<MusicLibraryAuthorizationStatus> requestAuthorization() async {
    return MusicLibraryAuthorizationStatus.unsupported;
  }

  @override
  Future<List<LibraryTrack>> fetchTracks() async => const [];

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() async => null;

  @override
  Stream<MusicPlaybackSnapshot> playbackEvents() {
    return const Stream<MusicPlaybackSnapshot>.empty();
  }

  @override
  Future<Uint8List?> fetchArtwork(String trackId, {required int size}) async {
    return null;
  }

  @override
  Future<void> playTrack(String trackId) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> scheduleSnapshotRefresh() async {}

  @override
  Future<SnapshotSyncResult> syncSnapshotHistory() async {
    return const SnapshotSyncResult(status: SnapshotSyncStatus.unchanged);
  }

  @override
  Future<SnapshotSyncResult> deleteCloudSnapshots({
    String? olderThanDateKey,
  }) async {
    return const SnapshotSyncResult(status: SnapshotSyncStatus.unchanged);
  }
}
