import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/library_overview.dart';
import '../domain/library_snapshot.dart';
import '../domain/library_track.dart';
import '../domain/music_library_authorization.dart';
import '../domain/music_stats_state.dart';
import 'library_snapshot_repository.dart';
import 'music_library_channel.dart';

final musicLibraryClientProvider = Provider<MusicLibraryClient>(
  (ref) => const PlatformMusicLibraryClient(),
);

final musicStatsRepositoryProvider = Provider<MusicStatsRepository>((ref) {
  return MusicStatsRepository(
    ref.watch(musicLibraryClientProvider),
    ref.watch(librarySnapshotRepositoryProvider),
  );
});

class MusicStatsRepository {
  const MusicStatsRepository(this._client, this._snapshotRepository);

  final MusicLibraryClient _client;
  final LibrarySnapshotRepository _snapshotRepository;

  Future<MusicStatsState> load({bool requestAccess = false}) async {
    if (!_isIosMusicRuntime) {
      return MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
        overview: LibraryOverview.fromTracks(_sampleTracks(), isDemo: true),
        snapshotHistory: SnapshotHistory.empty,
      );
    }

    final status = requestAccess
        ? await _client.requestAuthorization()
        : await _client.authorizationStatus();

    if (!status.canReadLibrary) {
      return MusicStatsState(
        authorizationStatus: status,
        overview: LibraryOverview.empty(isDemo: false),
        snapshotHistory: await _snapshotRepository.loadHistory(),
      );
    }

    await _client.scheduleSnapshotRefresh();
    final tracks = await _client.fetchTracks();
    final overview = LibraryOverview.fromTracks(tracks, isDemo: false);
    final snapshotHistory = await _snapshotRepository.recordSnapshot(overview);
    return MusicStatsState(
      authorizationStatus: status,
      overview: overview,
      snapshotHistory: snapshotHistory,
    );
  }

  Future<Uint8List?> fetchArtwork(String trackId, {int size = 640}) {
    if (!_isIosMusicRuntime) {
      return Future<Uint8List?>.value();
    }
    return _client.fetchArtwork(trackId, size: size);
  }

  Future<void> playTrack(String trackId) {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.playTrack(trackId);
  }

  Future<void> play() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.play();
  }

  Future<void> pause() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.pause();
  }

  Future<void> skipToNext() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.skipToNext();
  }

  Future<void> skipToPrevious() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.skipToPrevious();
  }

  Future<SnapshotHistory> recordSnapshot(LibraryOverview overview) {
    if (!_isIosMusicRuntime || overview.isDemo) {
      return Future.value(SnapshotHistory.empty);
    }
    return _snapshotRepository.recordSnapshot(overview);
  }

  List<LibraryTrack> _sampleTracks() {
    final now = DateTime.now();
    return [
      LibraryTrack(
        id: 'demo-1',
        title: 'Skyline Echo',
        artist: 'Nami Arata',
        albumTitle: 'Night Transit',
        artworkAsset: 'assets/demo_art/skyline_echo.png',
        duration: const Duration(minutes: 4, seconds: 12),
        playCount: 184,
        skipCount: 3,
        lastPlayedAt: now.subtract(const Duration(hours: 3)),
        lyrics:
            'City lights are waking slow\n'
            'Footsteps keep the meter low\n'
            'Every window hums along\n'
            'To the skyline echo song',
        playlistNames: const ['Late Night Focus', 'Recently Played'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-2',
        title: 'Glass Harbor',
        artist: 'Nami Arata',
        albumTitle: 'Night Transit',
        artworkAsset: 'assets/demo_art/glass_harbor.png',
        duration: const Duration(minutes: 3, seconds: 45),
        playCount: 162,
        skipCount: 8,
        lastPlayedAt: now.subtract(const Duration(days: 1, hours: 2)),
        playlistNames: const ['Late Night Focus', 'Harbor Walk'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-3',
        title: 'Tableau',
        artist: 'The Pale Keys',
        albumTitle: 'Still Frames',
        artworkAsset: 'assets/demo_art/tableau.png',
        duration: const Duration(minutes: 5, seconds: 6),
        playCount: 147,
        skipCount: 11,
        lastPlayedAt: now.subtract(const Duration(days: 2)),
        lyrics:
            'Hold the frame and let it breathe\n'
            'Quiet colors underneath\n'
            'Nothing moves and nothing stays',
        playlistNames: const ['Recently Played', 'Studio Notes'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-4',
        title: 'Subway Light',
        artist: 'The Pale Keys',
        albumTitle: 'Still Frames',
        duration: const Duration(minutes: 3, seconds: 28),
        playCount: 121,
        skipCount: 4,
        lastPlayedAt: now.subtract(const Duration(days: 4)),
        playlistNames: const ['City Pop Tests'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-5',
        title: 'Late Bloom',
        artist: 'Mika Seno',
        albumTitle: 'Small Signals',
        duration: const Duration(minutes: 4, seconds: 2),
        playCount: 116,
        skipCount: 5,
        lastPlayedAt: now.subtract(const Duration(days: 5, hours: 6)),
        lyrics:
            'Small signals find their way\n'
            'Through the ordinary day',
        playlistNames: const ['Morning Rotation'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-6',
        title: 'North Line',
        artist: 'Mika Seno',
        albumTitle: 'Small Signals',
        duration: const Duration(minutes: 2, seconds: 58),
        playCount: 96,
        skipCount: 1,
        lastPlayedAt: now.subtract(const Duration(days: 9)),
        playlistNames: const ['Morning Rotation', 'Train Window'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-7',
        title: 'Signal Blue',
        artist: 'Kite Room',
        albumTitle: 'Afterimage',
        duration: const Duration(minutes: 6, seconds: 18),
        playCount: 78,
        skipCount: 0,
        lastPlayedAt: now.subtract(const Duration(days: 12)),
        playlistNames: const ['Train Window'],
        isCloudItem: false,
      ),
    ];
  }
}

bool get _isIosMusicRuntime {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}
