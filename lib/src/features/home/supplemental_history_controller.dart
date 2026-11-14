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
  final _pending = <_PendingHistoryOperation>[];
  bool _restoring = false;
  bool _disposed = false;
  final _restored = Completer<void>();

  Future<void> get restored => _restored.future;

  @override
  SupplementalListeningHistory build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _preferences = ref.watch(musicDataSharedPreferencesProvider);
    if (_preferences != null) {
      _restoring = false;
      if (!_restored.isCompleted) _restored.complete();
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
    if (_restoring) _pending.add(_PendingHistoryOperation.ingest(tracks));
    final next = state.ingest(tracks);
    if (identical(next, state)) return;
    state = next;
    if (!_restoring) _save();
  }

  /// Records an observed play as a minimum count with a display-only date.
  void observe(LibraryTrack track, {required DateTime at}) {
    if (_restoring) _pending.add(_PendingHistoryOperation.observe(track, at));
    final next = state.observe(track, at: at);
    if (identical(next, state)) return;
    state = next;
    if (!_restoring) _save();
  }

  /// Merges remote evidence into the newest in-memory ledger and persists it.
  Future<void> mergeRemote(SupplementalListeningHistory remote) async {
    final merged = state.merge(remote);
    if (merged.encode() != state.encode()) state = merged;
    await _save();
  }

  Future<void> _restore(Future<SharedPreferences?> fallback) async {
    try {
      final preferences = await fallback;
      if (_disposed) return;
      _preferences = preferences;
      if (preferences != null) {
        var restored = _read(preferences);
        for (final operation in _pending) {
          restored = operation.apply(restored);
        }
        state = restored;
      }
    } on Object {
      // Confirmed observations remain usable when storage is unavailable.
    } finally {
      if (!_disposed) {
        _restoring = false;
        _pending.clear();
        await _save();
      }
      if (!_restored.isCompleted) _restored.complete();
    }
  }

  SupplementalListeningHistory _read(SharedPreferences preferences) {
    try {
      var ledger = SupplementalListeningHistory.decode(
        preferences.getString(supplementalListeningHistoryPreferenceKey),
      );
      final recent = preferences.getString('songbrief_apple_music_recent_v1');
      if (recent != null) {
        try {
          final rows = jsonDecode(recent);
          if (rows is List) {
            final validTracks = <LibraryTrack>[];
            for (final row in rows) {
              if (row is! Map) continue;
              try {
                validTracks.add(
                  LibraryTrack.fromPlatformMap(Map<Object?, Object?>.from(row)),
                );
              } on Object {
                // Keep valid rows when one legacy row is malformed.
              }
            }
            // Build the ledger's matching indexes once for the whole cache.
            ledger = ledger.ingest(validTracks);
          }
        } on Object {
          // One malformed legacy cache does not hide the persisted ledger.
        }
      }
      final outside = preferences.getString(
        'songbrief_outside_library_plays_v1',
      );
      if (outside != null) {
        try {
          final rows = jsonDecode(outside);
          if (rows is List) {
            final observations = <(int, LibraryTrack)>[];
            for (final row in rows) {
              if (row is! Map) continue;
              try {
                final map = Map<Object?, Object?>.from(row);
                final rawAt = map['playedAtMillis'];
                final at = rawAt is int
                    ? rawAt
                    : rawAt is double
                    ? rawAt.round()
                    : null;
                map.remove('playedAtMillis');
                map.remove('lastPlayedAtMillis');
                final track = LibraryTrack.fromPlatformMap(map);
                if (at != null && at > 0) {
                  observations.add((at, track));
                } else {
                  ledger = ledger.ingest([track]);
                }
              } on Object {
                // Keep valid rows when one legacy row is malformed.
              }
            }
            observations.sort((a, b) => a.$1.compareTo(b.$1));
            for (final observation in observations) {
              ledger = ledger.observe(
                observation.$2,
                at: DateTime.fromMillisecondsSinceEpoch(observation.$1),
              );
            }
          }
        } on Object {
          // One malformed legacy cache does not hide the persisted ledger.
        }
      }
      return ledger;
    } on Object {
      return const SupplementalListeningHistory.empty();
    }
  }

  Future<void> _save() {
    final preferences = _preferences;
    if (preferences == null) return _writes;
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
    return _writes;
  }
}

class _PendingHistoryOperation {
  const _PendingHistoryOperation._(this.tracks, this.at);

  factory _PendingHistoryOperation.ingest(Iterable<LibraryTrack> tracks) =>
      _PendingHistoryOperation._(List.unmodifiable(tracks), null);

  factory _PendingHistoryOperation.observe(LibraryTrack track, DateTime at) =>
      _PendingHistoryOperation._([track], at);

  final List<LibraryTrack> tracks;
  final DateTime? at;

  SupplementalListeningHistory apply(SupplementalListeningHistory history) {
    final observedAt = at;
    if (observedAt == null) return history.ingest(tracks);
    return history.observe(tracks.single, at: observedAt);
  }
}
