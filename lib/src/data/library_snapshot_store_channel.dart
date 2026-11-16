import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/library_snapshot.dart';
import 'background_platform_call.dart';
import 'library_snapshot_store_base.dart';

class MethodChannelSnapshotStore implements SnapshotStore {
  const MethodChannelSnapshotStore({
    this._channel = const MethodChannel(channelName),
  });

  static const channelName = 'app.songbrief/music_library';

  final MethodChannel _channel;

  @override
  Future<SnapshotHistory> loadHistory() {
    // The detailed history can hold hundreds of thousands of track counters;
    // decoding it on the UI isolate stalls startup animations.
    final channel = _channel;
    return runPlatformCallOffUiIsolate(
      offUiIsolate: () async =>
          _decodeSnapshotHistory(await _loadRawHistory(channel)),
      onUiIsolate: () => _loadHistoryOnUiIsolate(channel),
      debugName: 'load snapshot history',
    );
  }

  static Future<List<Object?>> _loadRawHistory(MethodChannel channel) async {
    final rawSnapshots = await channel.invokeListMethod<Object?>(
      'loadLocalSnapshotHistory',
      {'detailedLimit': detailedSnapshotHistoryEntries},
    );
    return rawSnapshots ?? const <Object?>[];
  }

  static Future<SnapshotHistory> _loadHistoryOnUiIsolate(
    MethodChannel channel,
  ) async {
    final values = await _loadRawHistory(channel);
    if (_shouldDecodeSnapshotHistoryInIsolate(values)) {
      return compute(
        _decodeSnapshotHistory,
        values,
        debugLabel: 'decode snapshot history',
      );
    }
    return _decodeSnapshotHistory(values);
  }

  @override
  Future<void> writeSnapshot(DailyLibrarySnapshot snapshot) async {
    await _requireSuccess('writeLocalSnapshot', <String, Object?>{
      'snapshot': snapshot.toJson(),
    });
  }

  @override
  Future<void> deleteSnapshotsOlderThan(DateTime cutoff) async {
    await _requireSuccess('deleteLocalSnapshots', <String, Object?>{
      'olderThanDateKey': snapshotDateKey(cutoff),
    });
  }

  @override
  Future<void> clearHistory() async {
    await _requireSuccess('clearLocalSnapshotHistory');
  }

  Future<void> _requireSuccess(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final succeeded = await _channel.invokeMethod<bool>(method, arguments);
    if (succeeded != true) {
      throw PlatformException(
        code: 'snapshot_store_failed',
        message: 'The native snapshot store could not complete $method.',
      );
    }
  }
}

const _snapshotDecodeIsolateThreshold = 64;
const _snapshotTrackDecodeIsolateThreshold = 700;

bool _shouldDecodeSnapshotHistoryInIsolate(List<Object?> rawSnapshots) {
  if (rawSnapshots.length >= _snapshotDecodeIsolateThreshold) return true;

  var detailedTrackCount = 0;
  for (final rawSnapshot in rawSnapshots) {
    if (rawSnapshot is! Map<Object?, Object?>) continue;
    final tracks = rawSnapshot['tracks'];
    if (tracks is! List) continue;
    detailedTrackCount += tracks.length;
    if (detailedTrackCount >= _snapshotTrackDecodeIsolateThreshold) {
      return true;
    }
  }
  return false;
}

SnapshotHistory _decodeSnapshotHistory(List<Object?> rawSnapshots) {
  final snapshots =
      rawSnapshots
          .whereType<Map<Object?, Object?>>()
          .map(
            (snapshot) =>
                DailyLibrarySnapshot.fromJson(snapshot.cast<String, Object?>()),
          )
          .where((snapshot) => snapshot.dateKey.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  return SnapshotHistory(snapshots: List.unmodifiable(snapshots));
}
