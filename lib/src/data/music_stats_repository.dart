import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/library_overview.dart';
import '../domain/library_track.dart';
import '../domain/music_library_authorization.dart';
import '../domain/music_stats_state.dart';
import 'music_library_channel.dart';

final musicLibraryClientProvider = Provider<MusicLibraryClient>(
  (ref) => const PlatformMusicLibraryClient(),
);

final musicStatsRepositoryProvider = Provider<MusicStatsRepository>((ref) {
  return MusicStatsRepository(ref.watch(musicLibraryClientProvider));
});

class MusicStatsRepository {
  const MusicStatsRepository(this._client);

  final MusicLibraryClient _client;

  Future<MusicStatsState> load({bool requestAccess = false}) async {
    if (!_isIosMusicRuntime) {
      return MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
        overview: LibraryOverview.fromTracks(_sampleTracks(), isDemo: true),
      );
    }

    final status = requestAccess
        ? await _client.requestAuthorization()
        : await _client.authorizationStatus();

    if (!status.canReadLibrary) {
      return MusicStatsState(
        authorizationStatus: status,
        overview: LibraryOverview.empty(isDemo: false),
      );
    }

    final tracks = await _client.fetchTracks();
    return MusicStatsState(
      authorizationStatus: status,
      overview: LibraryOverview.fromTracks(tracks, isDemo: false),
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

  List<LibraryTrack> _sampleTracks() {
    final now = DateTime.now();
    return [
      LibraryTrack(
        id: 'demo-1',
        title: 'Skyline Echo',
        artist: 'Nami Arata',
        albumTitle: 'Night Transit',
        duration: const Duration(minutes: 4, seconds: 12),
        playCount: 184,
        skipCount: 3,
        lastPlayedAt: now.subtract(const Duration(hours: 3)),
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-2',
        title: 'Glass Harbor',
        artist: 'Nami Arata',
        albumTitle: 'Night Transit',
        duration: const Duration(minutes: 3, seconds: 45),
        playCount: 162,
        skipCount: 8,
        lastPlayedAt: now.subtract(const Duration(days: 1, hours: 2)),
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-3',
        title: 'Tableau',
        artist: 'The Pale Keys',
        albumTitle: 'Still Frames',
        duration: const Duration(minutes: 5, seconds: 6),
        playCount: 147,
        skipCount: 11,
        lastPlayedAt: now.subtract(const Duration(days: 2)),
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
        isCloudItem: false,
      ),
    ];
  }
}

bool get _isIosMusicRuntime {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}
