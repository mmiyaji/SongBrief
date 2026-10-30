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
import 'package:songbrief/src/settings/library_filter_preferences.dart';

const _librarySong = LibraryTrack(
  id: 'library-1',
  title: 'Library Song',
  artist: 'Library Artist',
  albumTitle: 'Library Album',
  duration: Duration(minutes: 3),
  playCount: 4,
  skipCount: 0,
  isCloudItem: false,
  genre: 'Excluded Genre',
  playlistNames: ['Excluded Playlist'],
);

void main() {
  test(
    'external ID uses library identity and pauses without replacing queue',
    () async {
      final repository = _FakeMusicStatsRepository(
        overview: LibraryOverview.fromTracks([_librarySong], isDemo: false),
        currentPlaybackOverride: MusicPlaybackSnapshot.fromPlatformValue({
          'trackId': 'external-99',
          'isPlaying': true,
          'title': 'Library Song',
          'artist': 'Library Artist',
        }),
      );
      final container = ProviderContainer(
        overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(musicStatsControllerProvider.future);
      final controller = container.read(playbackControllerProvider.notifier);
      await controller.syncWithPlayer();
      final state = container.read(playbackControllerProvider);
      expect(state.activeTrackId, 'library-1');
      expect(state.nowPlaying?.playCount, 4);
      expect(state.isTrackPlaying('library-1'), isTrue);
      await controller.toggleTrack('library-1');
      expect(repository.pauseCalls, 1);
      expect(repository.playTrackCalls, 0);
      expect(container.read(outsideLibraryPlaysProvider), isEmpty);
    },
  );

  for (final excludedId in ['library-1', 'external-99']) {
    test(
      'excluded library song $excludedId is not saved as outside history',
      () async {
        final catalog = LibraryTrackCatalog()..replace([_librarySong]);
        final repository = _FakeMusicStatsRepository(
          libraryCatalog: catalog,
          overview: LibraryOverview.empty(isDemo: false),
          currentPlaybackOverride: MusicPlaybackSnapshot.fromPlatformValue({
            'trackId': excludedId,
            'isPlaying': true,
            'title': 'Library Song',
            'artist': 'Library Artist',
          }),
        );
        final container = ProviderContainer(
          overrides: [
            musicStatsRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        await container.read(musicStatsControllerProvider.future);
        container
            .read(libraryFilterPreferencesProvider.notifier)
            .addExcludedGenre('Excluded Genre');
        await container
            .read(playbackControllerProvider.notifier)
            .syncWithPlayer();
        expect(container.read(outsideLibraryPlaysProvider), isEmpty);
        expect(repository.loadCalls, 1);
      },
    );
  }

  test('existing outside history follows current keyword and cached playlist filters', () async {
    final catalog = LibraryTrackCatalog();
    final repository = _FakeMusicStatsRepository(
      libraryCatalog: catalog,
      overview: LibraryOverview.empty(isDemo: false),
    );
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(musicStatsControllerProvider.future);
    final history = container.read(outsideLibraryPlaysProvider.notifier);
    history.record(_librarySong);
    expect(container.read(visibleOutsideLibraryPlaysProvider), hasLength(1));
    container
        .read(libraryFilterPreferencesProvider.notifier)
        .addExcludedKeyword('Library Song');
    expect(container.read(visibleOutsideLibraryPlaysProvider), isEmpty);
    container.read(libraryFilterPreferencesProvider.notifier).clearAll();
    expect(container.read(visibleOutsideLibraryPlaysProvider), hasLength(1));
    container
        .read(libraryFilterPreferencesProvider.notifier)
        .addExcludedPlaylist('Excluded Playlist');
    expect(container.read(visibleOutsideLibraryPlaysProvider), isEmpty);
    // Previously persisted minimal native metadata still matches the full catalog.
    final minimal = MusicPlaybackSnapshot.fromPlatformValue({
      'trackId': 'external-99',
      'title': 'Library Song',
      'artist': 'Library Artist',
    })!.track!;
    history.record(minimal);
    catalog.replace([_librarySong]);
    container.invalidate(visibleOutsideLibraryPlaysProvider);
    expect(container.read(visibleOutsideLibraryPlaysProvider), isEmpty);
  });

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

  test('reads songs that are playing but not in the library', () {
    final snapshot = MusicPlaybackSnapshot.fromPlatformValue({
      'isPlaying': true,
      'title': 'Streamed Song',
      'artist': 'Guest Artist',
      'albumTitle': 'Playlist Album',
      'durationSeconds': 200,
    });

    expect(snapshot?.trackId, isNull);
    expect(snapshot?.track?.title, 'Streamed Song');
    expect(snapshot?.track?.artist, 'Guest Artist');
    expect(snapshot?.track?.duration, const Duration(seconds: 200));
    expect(snapshot?.track?.id, isNotEmpty);
  });

  test('records only songs played outside the library', () async {
    final events = StreamController<MusicPlaybackSnapshot>();
    final repository = _FakeMusicStatsRepository(
      playbackEvents: events.stream,
      overview: LibraryOverview.fromTracks(const [
        LibraryTrack(
          id: 'library-1',
          title: 'Library Song',
          artist: 'Library Artist',
          albumTitle: 'Library Album',
          duration: Duration(minutes: 3),
          playCount: 4,
          skipCount: 0,
          isCloudItem: false,
        ),
      ], isDemo: false),
    );
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    addTearDown(events.close);

    await container.read(musicStatsControllerProvider.future);
    container.read(playbackControllerProvider);
    events
      ..add(
        MusicPlaybackSnapshot.fromPlatformValue({
          'trackId': 'library-1',
          'isPlaying': true,
          'title': 'Library Song',
          'artist': 'Library Artist',
        })!,
      )
      ..add(
        MusicPlaybackSnapshot.fromPlatformValue({
          'trackId': 'streamed-1',
          'isPlaying': true,
          'title': 'Streamed Song',
          'artist': 'Guest Artist',
        })!,
      )
      ..add(
        MusicPlaybackSnapshot.fromPlatformValue({
          'trackId': 'streamed-1',
          'isPlaying': true,
          'title': 'Streamed Song',
          'artist': 'Guest Artist',
        })!,
      );
    await Future<void>.delayed(Duration.zero);

    final plays = container.read(outsideLibraryPlaysProvider);
    expect(plays.map((track) => track.id), ['streamed-1']);
    expect(plays.single.lastPlayedAt, isNotNull);
    final state = container.read(playbackControllerProvider);
    expect(state.activeTrackId, 'streamed-1');
    expect(state.nowPlaying?.title, 'Streamed Song');
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
    this.overview,
    super.libraryCatalog,
  }) : playbackEventsOverride =
           playbackEvents ?? const Stream<MusicPlaybackSnapshot>.empty(),
       super(_NoopMusicLibraryClient(), LibrarySnapshotRepository());

  final MusicPlaybackSnapshot? currentPlaybackOverride;
  final Stream<MusicPlaybackSnapshot> playbackEventsOverride;
  final LibraryOverview? overview;
  var loadCalls = 0;
  var skipToNextCalls = 0;
  var playTrackCalls = 0;
  var playCalls = 0;
  var pauseCalls = 0;

  @override
  Future<MusicStatsState> load({bool requestAccess = false}) async {
    loadCalls += 1;
    return MusicStatsState(
      authorizationStatus: overview == null
          ? MusicLibraryAuthorizationStatus.unsupported
          : MusicLibraryAuthorizationStatus.authorized,
      overview: overview ?? LibraryOverview.empty(isDemo: true),
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
  Future<bool> openAppSettings() async => false;

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
  Future<String?> fetchLyrics(String trackId) async => null;

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
  Future<void> rescheduleSnapshotRefresh() async {}

  @override
  Future<SnapshotRefreshDiagnostics> snapshotRefreshDiagnostics() async {
    return const SnapshotRefreshDiagnostics.unsupported();
  }

  @override
  Future<String?> exportSnapshotRefreshLogs() async => null;

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
