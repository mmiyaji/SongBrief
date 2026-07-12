import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_data_preferences_storage.dart';

const temporaryDemoLibraryEnabledPreferenceKey =
    'songbrief_temporary_demo_library_enabled_v1';

final temporaryDemoLibraryProvider =
    NotifierProvider<TemporaryDemoLibraryController, bool>(
      TemporaryDemoLibraryController.new,
    );

class TemporaryDemoLibraryController extends Notifier<bool> {
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
      return _readEnabled(preferences);
    }
    _preferencesFuture = ref.watch(musicDataPreferencesFallbackProvider);
    _restore();
    return false;
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
        if (!disposed && !_changedByUser) {
          state = _readEnabled(preferences);
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
      await preferences.setBool(
        temporaryDemoLibraryEnabledPreferenceKey,
        enabled,
      );
    } on Object {
      // The in-memory choice remains valid when persistence is unavailable.
    }
  }

  bool _readEnabled(SharedPreferences preferences) {
    try {
      return preferences.getBool(temporaryDemoLibraryEnabledPreferenceKey) ??
          false;
    } on Object {
      return false;
    }
  }

  void _completeRestore() {
    if (!_restored.isCompleted) {
      _restored.complete();
    }
  }
}
