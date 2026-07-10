import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const snapshotRecordingEnabledPreferenceKey =
    'songbrief_snapshot_recording_enabled_v1';
const snapshotCloudSyncEnabledPreferenceKey =
    'songbrief_snapshot_cloud_sync_enabled_v1';

final snapshotRecordingProvider =
    NotifierProvider<SnapshotRecordingController, bool>(
      SnapshotRecordingController.new,
    );

class SnapshotRecordingController extends Notifier<bool> {
  var _changedByUser = false;
  var _restoreStarted = false;
  final _restored = Completer<void>();

  Future<void> get restored =>
      _restoreStarted ? _restored.future : Future<void>.value();

  @override
  bool build() {
    _restore();
    return true;
  }

  void setEnabled(bool enabled) {
    _changedByUser = true;
    state = enabled;
    unawaited(_save(enabled));
  }

  void _restore() {
    _restoreStarted = true;
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final enabled = preferences.getBool(
          snapshotRecordingEnabledPreferenceKey,
        );
        if (!disposed && !_changedByUser && enabled != null) {
          state = enabled;
        }
      } finally {
        if (!_restored.isCompleted) {
          _restored.complete();
        }
      }
    }());
  }

  Future<void> _save(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(snapshotRecordingEnabledPreferenceKey, enabled);
  }
}

final snapshotCloudSyncProvider =
    NotifierProvider<SnapshotCloudSyncController, bool>(
      SnapshotCloudSyncController.new,
    );

class SnapshotCloudSyncController extends Notifier<bool> {
  var _changedByUser = false;
  var _restoreStarted = false;
  final _restored = Completer<void>();

  Future<void> get restored =>
      _restoreStarted ? _restored.future : Future<void>.value();

  @override
  bool build() {
    _restore();
    return true;
  }

  void setEnabled(bool enabled) {
    _changedByUser = true;
    state = enabled;
    unawaited(_save(enabled));
  }

  void _restore() {
    _restoreStarted = true;
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final enabled = preferences.getBool(
          snapshotCloudSyncEnabledPreferenceKey,
        );
        if (!disposed && !_changedByUser && enabled != null) {
          state = enabled;
        }
      } finally {
        if (!_restored.isCompleted) {
          _restored.complete();
        }
      }
    }());
  }

  Future<void> _save(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(snapshotCloudSyncEnabledPreferenceKey, enabled);
  }
}
