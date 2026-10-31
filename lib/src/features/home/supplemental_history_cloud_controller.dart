import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supplemental_history_cloud_client.dart';
import '../../domain/supplemental_listening_history.dart';
import '../../settings/snapshot_preferences.dart';
import 'supplemental_history_controller.dart';

final supplementalHistoryCloudControllerProvider =
    NotifierProvider<
      SupplementalHistoryCloudController,
      SupplementalHistoryCloudStatus
    >(SupplementalHistoryCloudController.new);

class SupplementalHistoryCloudController
    extends Notifier<SupplementalHistoryCloudStatus> {
  static const _debounceDuration = Duration(milliseconds: 700);
  static const _maxConflictRetries = 3;
  static const _maxFollowUps = 2;

  Future<SupplementalHistoryCloudStatus>? _running;
  Timer? _debounce;
  var _disposed = false;
  var _applyingRemote = false;
  var _ledgerRevision = 0;

  @override
  SupplementalHistoryCloudStatus build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    ref.listen(supplementalHistoryProvider, (previous, next) {
      if (!_applyingRemote &&
          previous != null &&
          previous.encode() != next.encode()) {
        _ledgerRevision++;
        _scheduleSync();
      }
    });
    ref.listen(snapshotCloudSyncProvider, (previous, enabled) {
      if (enabled) {
        _scheduleSync();
      } else {
        _debounce?.cancel();
      }
    });
    return SupplementalHistoryCloudStatus.unavailable;
  }

  bool get isSyncing => _running != null;

  /// Synchronizes one coalesced batch. Safe to call on foreground or refresh.
  Future<SupplementalHistoryCloudStatus> syncCloud() {
    final active = _running;
    if (active != null) return active;
    late final Future<SupplementalHistoryCloudStatus> future;
    future = _synchronize().whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
    _running = future;
    return future;
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!_disposed) unawaited(syncCloud());
    });
  }

  Future<SupplementalHistoryCloudStatus> _synchronize() async {
    try {
      if (!ref.read(supplementalHistoryCloudPlatformSupportedProvider)) {
        return _setStatus(SupplementalHistoryCloudStatus.unavailable);
      }
      await ref.read(snapshotCloudSyncProvider.notifier).restored;
      if (_disposed || !ref.read(snapshotCloudSyncProvider)) {
        return _setStatus(SupplementalHistoryCloudStatus.disabled);
      }
      await ref.read(supplementalHistoryProvider.notifier).restored;
      if (_disposed) return state;

      final client = ref.read(supplementalHistoryCloudClientProvider);
      var revision = 0;
      var followUps = 0;
      do {
        final startRevision = _ledgerRevision;
        final fetched = await client.fetch();
        if (_disposed || !ref.read(snapshotCloudSyncProvider)) {
          return _setStatus(SupplementalHistoryCloudStatus.disabled);
        }
        if (fetched.status != SupplementalHistoryCloudStatus.success) {
          return _setStatus(fetched.status);
        }
        final remote = _decodeRemote(fetched.payload);
        revision = startRevision;
        _applyingRemote = true;
        late final Future<void> persistence;
        try {
          persistence = ref
              .read(supplementalHistoryProvider.notifier)
              .mergeRemote(remote);
        } finally {
          _applyingRemote = false;
        }
        await persistence;
        if (_disposed) return state;

        final current = ref.read(supplementalHistoryProvider);
        final encoded = current.encode();
        // A successful read with an empty remote ledger still needs local upload.
        if (encoded !=
            (fetched.payload ??
                const SupplementalListeningHistory.empty().encode())) {
          if (!ref.read(snapshotCloudSyncProvider)) {
            return _setStatus(SupplementalHistoryCloudStatus.disabled);
          }
          final saved = await client.save(
            payload: encoded,
            revision: fetched.revision,
          );
          if (saved.status == SupplementalHistoryCloudStatus.conflict) {
            if (++followUps >= _maxConflictRetries) {
              return _setStatus(SupplementalHistoryCloudStatus.conflict);
            }
            continue;
          }
          if (saved.status != SupplementalHistoryCloudStatus.success) {
            return _setStatus(saved.status);
          }
        }

        if (_ledgerRevision != revision && followUps < _maxFollowUps) {
          followUps++;
          continue;
        }
        if (_ledgerRevision != revision) _scheduleSync();
        return _setStatus(SupplementalHistoryCloudStatus.success);
      } while (!_disposed);
      return state;
    } on Object {
      return _setStatus(SupplementalHistoryCloudStatus.error);
    }
  }

  SupplementalHistoryCloudStatus _setStatus(
    SupplementalHistoryCloudStatus status,
  ) {
    if (!_disposed) state = status;
    return status;
  }

  SupplementalListeningHistory _decodeRemote(String? payload) {
    if (payload == null) return const SupplementalListeningHistory.empty();
    final decoded = jsonDecode(payload);
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['entries'] is! List) {
      throw const FormatException('Invalid supplemental history payload');
    }
    for (final raw in decoded['entries'] as List) {
      if (raw is! Map ||
          raw['track'] is! Map ||
          raw['dates'] is! List ||
          raw['aliases'] is! List ||
          (raw['dates'] as List).any((value) => value is! int) ||
          (raw['dates'] as List).any((value) => (value as int) <= 0) ||
          (raw['aliases'] as List).any((value) => value is! String) ||
          (raw['aliases'] as List).any(
            (value) => !_validAlias(value as String),
          ) ||
          (raw['firstObservedAt'] != null &&
              (raw['firstObservedAt'] is! int ||
                  raw['firstObservedAt'] <= 0))) {
        throw const FormatException('Invalid supplemental history entry');
      }
      final track = raw['track'] as Map;
      if (track['title'] is! String ||
          track['artist'] is! String ||
          track['albumTitle'] is! String ||
          track['id'] is! String ||
          track['durationSeconds'] is! int ||
          track['isCloudItem'] is! bool) {
        throw const FormatException('Invalid supplemental history track');
      }
    }
    final history = SupplementalListeningHistory.decode(payload);
    // The model decoder is intentionally forgiving for local legacy storage;
    // cloud input must be fully valid so a damaged object cannot erase data.
    if (history.tracks.length != (decoded['entries'] as List).length) {
      throw const FormatException('Invalid supplemental history entries');
    }
    return history;
  }

  bool _validAlias(String alias) {
    try {
      final value = jsonDecode(alias);
      return value is List &&
          value.length == 3 &&
          value.every((part) => part is String);
    } on Object {
      return false;
    }
  }
}
