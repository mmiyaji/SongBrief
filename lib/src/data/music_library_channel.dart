import 'package:flutter/services.dart';

import '../domain/library_track.dart';
import '../domain/music_library_authorization.dart';

abstract class MusicLibraryClient {
  Future<MusicLibraryAuthorizationStatus> authorizationStatus();

  Future<MusicLibraryAuthorizationStatus> requestAuthorization();

  Future<bool> openAppSettings();

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

  Future<void> rescheduleSnapshotRefresh() => scheduleSnapshotRefresh();

  Future<SnapshotRefreshDiagnostics> snapshotRefreshDiagnostics() async {
    return const SnapshotRefreshDiagnostics.unsupported();
  }

  Future<String?> exportSnapshotRefreshLogs() async => null;

  Future<SnapshotSyncResult> syncSnapshotHistory();

  Future<SnapshotSyncResult> deleteCloudSnapshots({String? olderThanDateKey});
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
  Future<bool> openAppSettings() async {
    return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
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

  @override
  Future<void> rescheduleSnapshotRefresh() {
    return _channel.invokeMethod<void>('scheduleSnapshotRefresh', {
      'replaceExisting': true,
    });
  }

  @override
  Future<SnapshotRefreshDiagnostics> snapshotRefreshDiagnostics() async {
    final payload = await _channel.invokeMethod<Object?>(
      'snapshotRefreshDiagnostics',
    );
    return SnapshotRefreshDiagnostics.fromPlatformValue(payload);
  }

  @override
  Future<String?> exportSnapshotRefreshLogs() {
    return _channel.invokeMethod<String>('exportSnapshotRefreshLogs');
  }

  @override
  Future<SnapshotSyncResult> syncSnapshotHistory() async {
    final payload = await _channel.invokeMethod<Object?>('syncSnapshotHistory');
    return SnapshotSyncResult.fromPlatformValue(payload);
  }

  @override
  Future<SnapshotSyncResult> deleteCloudSnapshots({
    String? olderThanDateKey,
  }) async {
    final payload = await _channel.invokeMethod<Object?>(
      'deleteCloudSnapshots',
      {'olderThanDateKey': ?olderThanDateKey},
    );
    return SnapshotSyncResult.fromPlatformValue(payload);
  }
}

enum SnapshotBackgroundRefreshAvailability {
  available,
  denied,
  restricted,
  unsupported;

  static SnapshotBackgroundRefreshAvailability fromPlatformValue(
    Object? value,
  ) {
    return switch (value) {
      'available' => SnapshotBackgroundRefreshAvailability.available,
      'denied' => SnapshotBackgroundRefreshAvailability.denied,
      'restricted' => SnapshotBackgroundRefreshAvailability.restricted,
      _ => SnapshotBackgroundRefreshAvailability.unsupported,
    };
  }
}

class SnapshotRefreshDiagnostics {
  const SnapshotRefreshDiagnostics({
    required this.availability,
    required this.intervalHours,
    required this.detailedLoggingEnabled,
    required this.retentionDays,
    required this.logFileCount,
    required this.logBytes,
    this.nextEarliestBeginAt,
    this.lastEvent,
    this.lastEventAt,
    this.lastTaskStartedAt,
    this.lastSuccessfulCaptureAt,
  });

  const SnapshotRefreshDiagnostics.unsupported()
    : availability = SnapshotBackgroundRefreshAvailability.unsupported,
      intervalHours = 6,
      detailedLoggingEnabled = false,
      retentionDays = 14,
      logFileCount = 0,
      logBytes = 0,
      nextEarliestBeginAt = null,
      lastEvent = null,
      lastEventAt = null,
      lastTaskStartedAt = null,
      lastSuccessfulCaptureAt = null;

  final SnapshotBackgroundRefreshAvailability availability;
  final int intervalHours;
  final bool detailedLoggingEnabled;
  final int retentionDays;
  final int logFileCount;
  final int logBytes;
  final DateTime? nextEarliestBeginAt;
  final String? lastEvent;
  final DateTime? lastEventAt;
  final DateTime? lastTaskStartedAt;
  final DateTime? lastSuccessfulCaptureAt;

  bool get hasLogs => logFileCount > 0 && logBytes > 0;

  static SnapshotRefreshDiagnostics fromPlatformValue(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return const SnapshotRefreshDiagnostics.unsupported();
    }
    DateTime? dateFromMillis(Object? raw) {
      final millis = switch (raw) {
        int value => value,
        num value when value.isFinite => value.toInt(),
        _ => null,
      };
      return millis == null || millis < 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis);
    }

    int nonNegativeIntValue(String key, int fallback) {
      final raw = value[key];
      final parsed = switch (raw) {
        int value => value,
        num value when value.isFinite => value.toInt(),
        _ => fallback,
      };
      return parsed < 0 ? fallback : parsed;
    }

    final retentionDays = nonNegativeIntValue('retentionDays', 14);
    final lastEvent = value['lastEvent'];

    return SnapshotRefreshDiagnostics(
      availability: SnapshotBackgroundRefreshAvailability.fromPlatformValue(
        value['availability'],
      ),
      intervalHours: 6,
      detailedLoggingEnabled: value['detailedLoggingEnabled'] == true,
      retentionDays: retentionDays == 0 ? 14 : retentionDays,
      logFileCount: nonNegativeIntValue('logFileCount', 0),
      logBytes: nonNegativeIntValue('logBytes', 0),
      nextEarliestBeginAt: dateFromMillis(value['nextEarliestBeginAtMillis']),
      lastEvent: lastEvent is String ? lastEvent : null,
      lastEventAt: dateFromMillis(value['lastEventAtMillis']),
      lastTaskStartedAt: dateFromMillis(value['lastTaskStartedAtMillis']),
      lastSuccessfulCaptureAt: dateFromMillis(
        value['lastSuccessfulCaptureAtMillis'],
      ),
    );
  }
}

enum SnapshotSyncStatus {
  synced,
  unchanged,
  partial,
  disabled,
  noAccount,
  unavailable,
  error;

  static SnapshotSyncStatus fromPlatformValue(Object? value) {
    return switch (value) {
      'synced' => SnapshotSyncStatus.synced,
      'unchanged' => SnapshotSyncStatus.unchanged,
      'partial' => SnapshotSyncStatus.partial,
      'disabled' => SnapshotSyncStatus.disabled,
      'noAccount' => SnapshotSyncStatus.noAccount,
      'unavailable' => SnapshotSyncStatus.unavailable,
      _ => SnapshotSyncStatus.error,
    };
  }
}

class SnapshotSyncResult {
  const SnapshotSyncResult({
    required this.status,
    this.downloaded = 0,
    this.uploaded = 0,
    this.deleted = 0,
  });

  final SnapshotSyncStatus status;
  final int downloaded;
  final int uploaded;
  final int deleted;

  bool get changedLocally => downloaded > 0;

  bool get deletionCompleted =>
      status == SnapshotSyncStatus.synced ||
      status == SnapshotSyncStatus.unchanged;

  static SnapshotSyncResult fromPlatformValue(Object? value) {
    if (value is! Map) {
      return const SnapshotSyncResult(status: SnapshotSyncStatus.error);
    }
    return SnapshotSyncResult(
      status: SnapshotSyncStatus.fromPlatformValue(value['status']),
      downloaded: _readCount(value['downloaded']),
      uploaded: _readCount(value['uploaded']),
      deleted: _readCount(value['deleted']),
    );
  }

  static int _readCount(Object? value) {
    if (value is int && value > 0) {
      return value;
    }
    return 0;
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
