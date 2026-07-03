import 'package:flutter/services.dart';

import '../domain/library_track.dart';
import '../domain/music_library_authorization.dart';

abstract class MusicLibraryClient {
  Future<MusicLibraryAuthorizationStatus> authorizationStatus();

  Future<MusicLibraryAuthorizationStatus> requestAuthorization();

  Future<List<LibraryTrack>> fetchTracks();

  Future<MusicPlaybackSnapshot?> currentPlayback();

  Stream<MusicPlaybackSnapshot> playbackEvents();

  Future<Uint8List?> fetchArtwork(String trackId, {required int size});

  Future<void> playTrack(String trackId);

  Future<void> play();

  Future<void> pause();

  Future<void> skipToNext();

  Future<void> skipToPrevious();

  Future<void> scheduleSnapshotRefresh();
}

class PlatformMusicLibraryClient implements MusicLibraryClient {
  const PlatformMusicLibraryClient();

  static const MethodChannel _channel = MethodChannel(
    'app.songbrief/music_library',
  );
  static const EventChannel _playbackEvents = EventChannel(
    'app.songbrief/music_playback',
  );

  @override
  Future<MusicLibraryAuthorizationStatus> authorizationStatus() async {
    final status = await _channel.invokeMethod<Object?>('authorizationStatus');
    return MusicLibraryAuthorizationStatus.fromPlatformValue(status);
  }

  @override
  Future<MusicLibraryAuthorizationStatus> requestAuthorization() async {
    final status = await _channel.invokeMethod<Object?>('requestAuthorization');
    return MusicLibraryAuthorizationStatus.fromPlatformValue(status);
  }

  @override
  Future<List<LibraryTrack>> fetchTracks() async {
    final rawTracks = await _channel.invokeMethod<List<Object?>>('fetchTracks');
    return (rawTracks ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(LibraryTrack.fromPlatformMap)
        .toList(growable: false);
  }

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() async {
    final rawPlayback = await _channel.invokeMethod<Object?>('currentPlayback');
    return MusicPlaybackSnapshot.fromPlatformValue(rawPlayback);
  }

  @override
  Stream<MusicPlaybackSnapshot> playbackEvents() {
    return _playbackEvents
        .receiveBroadcastStream()
        .map(MusicPlaybackSnapshot.fromPlatformValue)
        .where((snapshot) => snapshot != null)
        .cast<MusicPlaybackSnapshot>();
  }

  @override
  Future<Uint8List?> fetchArtwork(String trackId, {required int size}) async {
    return _channel.invokeMethod<Uint8List>('fetchArtwork', {
      'id': trackId,
      'size': size,
    });
  }

  @override
  Future<void> playTrack(String trackId) {
    return _channel.invokeMethod<void>('playTrack', {'id': trackId});
  }

  @override
  Future<void> play() {
    return _channel.invokeMethod<void>('play');
  }

  @override
  Future<void> pause() {
    return _channel.invokeMethod<void>('pause');
  }

  @override
  Future<void> skipToNext() {
    return _channel.invokeMethod<void>('skipToNext');
  }

  @override
  Future<void> skipToPrevious() {
    return _channel.invokeMethod<void>('skipToPrevious');
  }

  @override
  Future<void> scheduleSnapshotRefresh() {
    return _channel.invokeMethod<void>('scheduleSnapshotRefresh');
  }
}

class MusicPlaybackSnapshot {
  const MusicPlaybackSnapshot({this.trackId, required this.isPlaying});

  final String? trackId;
  final bool isPlaying;

  static MusicPlaybackSnapshot? fromPlatformValue(Object? value) {
    if (value is! Map) {
      return null;
    }

    final rawTrackId = value['trackId'];
    final trackId = rawTrackId is String && rawTrackId.trim().isNotEmpty
        ? rawTrackId.trim()
        : null;
    return MusicPlaybackSnapshot(
      trackId: trackId,
      isPlaying: value['isPlaying'] == true,
    );
  }
}
