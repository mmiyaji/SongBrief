import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_data_preferences_storage.dart';

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
  late Future<SharedPreferences?> _preferencesFuture;
  SharedPreferences? _preferences;

  Future<void> get restored =>
      _restoreStarted ? _restored.future : Future<void>.value();

  @override
  bool build() {
    _restoreStarted = true;
    final preferences = ref.watch(musicDataSharedPreferencesProvider);
    _preferences = preferences;
    if (preferences != null) {
      _completeRestore();
      return _readBoolPreference(
        preferences,
        snapshotRecordingEnabledPreferenceKey,
        fallback: true,
      );
    }
    _preferencesFuture = ref.watch(musicDataPreferencesFallbackProvider);
    _restore();
    return true;
  }

  void setEnabled(bool enabled) {
    _changedByUser = true;
    state = enabled;
    unawaited(_save(enabled));
  }

  void _restore() {
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      try {
        final preferences = await _preferencesFuture;
        if (preferences == null) {
          return;
        }
        _preferences ??= preferences;
        final enabled = _readBoolPreference(
          preferences,
          snapshotRecordingEnabledPreferenceKey,
          fallback: true,
        );
        if (!disposed && !_changedByUser) {
          state = enabled;
        }
      } on Object {
        // Keep the safe default when preference restoration is unavailable.
      } finally {
        _completeRestore();
      }
    }());
  }

  Future<void> _save(bool enabled) async {
    try {
      final preferences = _preferences ?? await _preferencesFuture;
      if (preferences == null) {
        return;
      }
      _preferences ??= preferences;
      await preferences.setBool(snapshotRecordingEnabledPreferenceKey, enabled);
    } on Object {
      // The in-memory choice remains valid when persistence is unavailable.
    }
  }

  void _completeRestore() {
    if (!_restored.isCompleted) {
      _restored.complete();
    }
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
  late Future<SharedPreferences?> _preferencesFuture;
  SharedPreferences? _preferences;

  Future<void> get restored =>
      _restoreStarted ? _restored.future : Future<void>.value();

  @override
  bool build() {
    _restoreStarted = true;
    final preferences = ref.watch(musicDataSharedPreferencesProvider);
    _preferences = preferences;
    if (preferences != null) {
      _completeRestore();
      return _readBoolPreference(
        preferences,
        snapshotCloudSyncEnabledPreferenceKey,
        fallback: true,
      );
    }
    _preferencesFuture = ref.watch(musicDataPreferencesFallbackProvider);
    _restore();
    return true;
  }

  void setEnabled(bool enabled) {
    _changedByUser = true;
    state = enabled;
    unawaited(_save(enabled));
  }

  void _restore() {
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      try {
        final preferences = await _preferencesFuture;
        if (preferences == null) {
          return;
        }
        _preferences ??= preferences;
        final enabled = _readBoolPreference(
          preferences,
          snapshotCloudSyncEnabledPreferenceKey,
          fallback: true,
        );
        if (!disposed && !_changedByUser) {
          state = enabled;
        }
      } on Object {
        // Keep the safe default when preference restoration is unavailable.
      } finally {
        _completeRestore();
      }
    }());
  }

  Future<void> _save(bool enabled) async {
    try {
      final preferences = _preferences ?? await _preferencesFuture;
      if (preferences == null) {
        return;
      }
      _preferences ??= preferences;
      await preferences.setBool(snapshotCloudSyncEnabledPreferenceKey, enabled);
    } on Object {
      // The in-memory choice remains valid when persistence is unavailable.
    }
  }

  void _completeRestore() {
    if (!_restored.isCompleted) {
      _restored.complete();
    }
  }
}

bool _readBoolPreference(
  SharedPreferences preferences,
  String key, {
  required bool fallback,
}) {
  try {
    return preferences.getBool(key) ?? fallback;
  } on Object {
    return fallback;
  }
}
