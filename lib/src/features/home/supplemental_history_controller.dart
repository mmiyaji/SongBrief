import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/library_track.dart';
import '../../domain/supplemental_listening_history.dart';
import '../../settings/music_data_preferences_storage.dart';

const supplementalListeningHistoryPreferenceKey =
    'songbrief_supplemental_listening_history_v1';

final supplementalHistoryProvider =
    NotifierProvider<
      SupplementalHistoryController,
      SupplementalListeningHistory
    >(SupplementalHistoryController.new);

class SupplementalHistoryController
    extends Notifier<SupplementalListeningHistory> {
  SharedPreferences? _preferences;
  Future<void> _writes = Future<void>.value();
  final _pending = <LibraryTrack>[];
  bool _restoring = false;
  bool _disposed = false;

  @override
  SupplementalListeningHistory build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _preferences = ref.watch(musicDataSharedPreferencesProvider);
    if (_preferences != null) {
      // A deferred write can safely access state after build has returned.
      scheduleMicrotask(() {
        if (!_disposed) _save();
      });
      return _read(_preferences!);
    }
    _restoring = true;
    final fallback = ref.watch(musicDataPreferencesFallbackProvider);
    unawaited(_restore(fallback));
    return const SupplementalListeningHistory.empty();
  }

  /// Ingest only confirmed history rows with their original nullable dates.
  void ingest(List<LibraryTrack> tracks) {
    if (tracks.isEmpty) return;
    if (_restoring) _pending.addAll(tracks);
    final next = state.ingest(tracks);
    if (identical(next, state)) return;
    state = next;
    if (!_restoring) _save();
  }

  Future<void> _restore(Future<SharedPreferences?> fallback) async {
    try {
      final preferences = await fallback;
      if (_disposed) return;
      _preferences = preferences;
      if (preferences != null) state = _read(preferences).ingest(_pending);
    } on Object {
      // Confirmed observations remain usable when storage is unavailable.
    } finally {
      if (!_disposed) {
        _restoring = false;
        _pending.clear();
        _save();
      }
    }
  }

  SupplementalListeningHistory _read(SharedPreferences preferences) {
    try {
      var ledger = SupplementalListeningHistory.decode(
        preferences.getString(supplementalListeningHistoryPreferenceKey),
      );
      for (final key in [
        'songbrief_apple_music_recent_v1',
        'songbrief_outside_library_plays_v1',
      ]) {
        final cached = preferences.getString(key);
        if (cached == null) continue;
        try {
          final rows = jsonDecode(cached) as List<dynamic>;
          ledger = ledger.ingest(
            rows.whereType<Map<String, dynamic>>().map((row) {
              // Observed playback times are not confirmed completion timestamps.
              // Strip all date fields from these rows before the platform parser.
              final map = {...row};
              if (key == 'songbrief_outside_library_plays_v1') {
                map.remove('lastPlayedAtMillis');
              }
              return LibraryTrack.fromPlatformMap(map);
            }),
          );
        } on Object {
          // One malformed legacy cache does not hide the persisted ledger.
        }
      }
      return ledger;
    } on Object {
      return const SupplementalListeningHistory.empty();
    }
  }

  void _save() {
    final preferences = _preferences;
    if (preferences == null) return;
    final encoded = state.encode();
    // Serialize writes so an older observation cannot overwrite a newer one.
    _writes = _writes.then((_) async {
      try {
        await preferences.setString(
          supplementalListeningHistoryPreferenceKey,
          encoded,
        );
      } on Object {
        // Keep the in-memory ledger when persistence fails.
      }
    });
    unawaited(_writes);
  }
}
