import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_data_preferences_storage.dart';

const supplementalHistoryIncludedPreferenceKey =
    'songbrief_supplemental_history_included_v1';

final supplementalHistoryIncludedProvider =
    NotifierProvider<SupplementalHistoryInclusionController, bool>(
      SupplementalHistoryInclusionController.new,
    );

/// Controls whether supplemental listening history contributes to totals.
/// The history itself is retained when disabled.
class SupplementalHistoryInclusionController extends Notifier<bool> {
  var _changedByUser = false;
  var _restoreStarted = false;
  var _disposed = false;
  var _revision = 0;
  var _persistedValue = true;
  var _persistedValueKnown = false;
  final _restored = Completer<void>();
  Future<void> _writeTail = Future<void>.value();
  late Future<SharedPreferences?> _preferencesFuture;
  SharedPreferences? _preferences;

  Future<void> get restored =>
      _restoreStarted ? _restored.future : Future<void>.value();

  @override
  bool build() {
    _disposed = false;
    _restoreStarted = true;
    ref.onDispose(() => _disposed = true);
    final preferences = ref.watch(musicDataSharedPreferencesProvider);
    _preferences = preferences;
    if (preferences != null) {
      _persistedValue = _readEnabled(preferences);
      _persistedValueKnown = true;
      _completeRestore();
      return _persistedValue;
    }
    _preferencesFuture = ref.watch(musicDataPreferencesFallbackProvider);
    _restore();
    return true;
  }

  Future<bool> setEnabled(bool enabled) {
    _changedByUser = true;
    final revision = ++_revision;
    state = enabled;
    final completer = Completer<bool>();
    _writeTail = _writeTail.then((_) async {
      final saved = await _save(enabled);
      if (saved) {
        _persistedValue = enabled;
        _persistedValueKnown = true;
      } else if (!_disposed && revision == _revision) {
        state = _persistedValue;
      }
      completer.complete(saved);
    });
    return completer.future;
  }

  bool _readEnabled(SharedPreferences preferences) {
    try {
      return preferences.getBool(supplementalHistoryIncludedPreferenceKey) ??
          true;
    } on Object {
      return true;
    }
  }

  void _restore() {
    unawaited(() async {
      try {
        final preferences = await _preferencesFuture;
        if (preferences != null) {
          _preferences ??= preferences;
          final enabled = _readEnabled(preferences);
          if (!_persistedValueKnown) {
            _persistedValue = enabled;
            _persistedValueKnown = true;
          }
          if (!_disposed && !_changedByUser) state = enabled;
        }
      } on Object {
        // Keep the default when preference restoration is unavailable.
      } finally {
        _completeRestore();
      }
    }());
  }

  Future<bool> _save(bool enabled) async {
    try {
      final preferences = _preferences ?? await _preferencesFuture;
      if (preferences == null || _disposed) return false;
      _preferences ??= preferences;
      if (!_persistedValueKnown) {
        _persistedValue = _readEnabled(preferences);
        _persistedValueKnown = true;
      }
      return await preferences.setBool(
        supplementalHistoryIncludedPreferenceKey,
        enabled,
      );
    } on Object {
      return false;
    }
  }

  void _completeRestore() {
    if (!_restored.isCompleted) _restored.complete();
  }
}
