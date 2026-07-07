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
  test('silent stats refresh keeps previous data while loading', () async {
    final repository = _ControlledMusicStatsRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);

    final refresh = container
        .read(musicStatsControllerProvider.notifier)
        .refreshStatsSilently();
    await Future<void>.delayed(Duration.zero);

    final duringRefresh = container.read(musicStatsControllerProvider);
    expect(duringRefresh.hasValue, isTrue);
    expect(duringRefresh.requireValue.overview.latestTrack?.title, 'Initial');

    repository.completeRefresh(_state('Updated'));
    await refresh;

    final afterRefresh = container.read(musicStatsControllerProvider);
    expect(afterRefresh.requireValue.overview.latestTrack?.title, 'Updated');
  });
}

MusicStatsState _state(String title) {
  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
    overview: LibraryOverview.fromTracks([
      LibraryTrack(
        id: title.toLowerCase(),
        title: title,
        artist: 'Test Artist',
        albumTitle: 'Test Album',
        duration: const Duration(minutes: 3),
        playCount: 1,
        skipCount: 0,
        lastPlayedAt: DateTime(2026),
        isCloudItem: false,
      ),
    ], isDemo: true),
    snapshotHistory: SnapshotHistory.empty,
  );
}

class _ControlledMusicStatsRepository extends MusicStatsRepository {
  _ControlledMusicStatsRepository()
    : super(const _NoopMusicLibraryClient(), const LibrarySnapshotRepository());

  var _loadCount = 0;
  Completer<MusicStatsState>? _pendingRefresh;

  @override
  Future<MusicStatsState> load({bool requestAccess = false}) {
    _loadCount += 1;
    if (_loadCount == 1) {
      return Future.value(_state('Initial'));
    }
    _pendingRefresh ??= Completer<MusicStatsState>();
    return _pendingRefresh!.future;
  }

  void completeRefresh(MusicStatsState state) {
    _pendingRefresh?.complete(state);
  }

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() {
    return Future.value();
  }
}

class _NoopMusicLibraryClient implements MusicLibraryClient {
  const _NoopMusicLibraryClient();

  @override
  Future<MusicLibraryAuthorizationStatus> authorizationStatus() {
    return Future.value(MusicLibraryAuthorizationStatus.unsupported);
  }

  @override
  Future<MusicLibraryAuthorizationStatus> requestAuthorization() {
    return Future.value(MusicLibraryAuthorizationStatus.unsupported);
  }

  @override
  Future<List<LibraryTrack>> fetchTracks() {
    return Future.value(const []);
  }

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() {
    return Future.value();
  }

  @override
  Stream<MusicPlaybackSnapshot> playbackEvents() {
    return const Stream.empty();
  }

  @override
  Future<Uint8List?> fetchArtwork(String trackId, {required int size}) {
    return Future.value();
  }

  @override
  Future<void> playTrack(String trackId) {
    return Future.value();
  }

  @override
  Future<void> play() {
    return Future.value();
  }

  @override
  Future<void> pause() {
    return Future.value();
  }

  @override
  Future<void> skipToNext() {
    return Future.value();
  }

  @override
  Future<void> skipToPrevious() {
    return Future.value();
  }

  @override
  Future<void> scheduleSnapshotRefresh() {
    return Future.value();
  }

  @override
  Future<SnapshotSyncResult> syncSnapshotHistory() {
    return Future.value(
      const SnapshotSyncResult(status: SnapshotSyncStatus.unchanged),
    );
  }

  @override
  Future<SnapshotSyncResult> deleteCloudSnapshots({String? olderThanDateKey}) {
    return Future.value(
      const SnapshotSyncResult(status: SnapshotSyncStatus.unchanged),
    );
  }
}
