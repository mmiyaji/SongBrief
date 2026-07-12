import 'package:flutter/services.dart';

import '../domain/library_snapshot.dart';
import 'library_snapshot_store_base.dart';

class MethodChannelSnapshotStore implements SnapshotStore {
  const MethodChannelSnapshotStore({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const channelName = 'app.songbrief/music_library';

  final MethodChannel _channel;

  @override
  Future<SnapshotHistory> loadHistory() async {
    final rawSnapshots = await _channel.invokeListMethod<Object?>(
      'loadLocalSnapshotHistory',
      {'detailedLimit': detailedSnapshotHistoryEntries},
    );
    final snapshots =
        (rawSnapshots ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()
            .map(
              (snapshot) => DailyLibrarySnapshot.fromJson(
                snapshot.cast<String, Object?>(),
              ),
            )
            .where((snapshot) => snapshot.dateKey.isNotEmpty)
            .toList(growable: false)
          ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return SnapshotHistory(snapshots: List.unmodifiable(snapshots));
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
