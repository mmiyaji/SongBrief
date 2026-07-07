import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_overview.dart';
import '../domain/library_snapshot.dart';

final librarySnapshotRepositoryProvider = Provider<LibrarySnapshotRepository>((
  ref,
) {
  return const LibrarySnapshotRepository();
});

class LibrarySnapshotRepository {
  const LibrarySnapshotRepository();

  static const _maxStoredSnapshotCharacters = 1500000;
  static const _legacyMigrationPreferenceKey =
      'songbrief_daily_snapshots_v2_legacy_migrated';

  Future<SnapshotHistory> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    // The iOS background task and CloudKit sync write this key natively, so
    // the Dart-side cache must be refreshed before reading.
    await preferences.reload();
    await _removeLegacyHistoryIfNeeded(preferences);
    final raw = preferences.getString(librarySnapshotPreferencesKey);
    if (raw == null || raw.isEmpty) {
      return SnapshotHistory.empty;
    }

    try {
      final history = await compute(_decodeSnapshotHistory, raw);
      if (raw.length <= _maxStoredSnapshotCharacters) {
        return history;
      }
      final trimmed = await _storeHistoryWithinSize(preferences, history);
      return trimmed;
    } on FormatException {
      return SnapshotHistory.empty;
    }
  }

  Future<SnapshotHistory> recordSnapshot(
    LibraryOverview overview, {
    DateTime? capturedAt,
    String source = 'foreground',
  }) async {
    if (!overview.hasTracks) {
      return loadHistory();
    }

    final history = await loadHistory();
    final next = history.withSnapshot(
      DailyLibrarySnapshot.fromOverview(
        overview,
        capturedAt: capturedAt,
        source: source,
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    return _storeHistoryWithinSize(preferences, next);
  }

  Future<SnapshotHistory> deleteSnapshotsOlderThan(DateTime cutoff) async {
    final history = await loadHistory();
    final snapshots = history.snapshots
        .where((snapshot) => !snapshot.capturedAt.isBefore(cutoff))
        .toList(growable: false);
    final next = SnapshotHistory(snapshots: List.unmodifiable(snapshots));
    final preferences = await SharedPreferences.getInstance();
    return _storeHistoryWithinSize(preferences, next);
  }

  Future<SnapshotHistory> clearHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(librarySnapshotPreferencesKey);
    return SnapshotHistory.empty;
  }

  Future<SnapshotHistory> _storeHistoryWithinSize(
    SharedPreferences preferences,
    SnapshotHistory history,
  ) async {
    final encoded = await _encodeHistoryWithinSize(history);
    await preferences.setString(librarySnapshotPreferencesKey, encoded.value);
    return encoded.history;
  }

  Future<void> _removeLegacyHistoryIfNeeded(
    SharedPreferences preferences,
  ) async {
    if (preferences.getBool(_legacyMigrationPreferenceKey) ?? false) {
      return;
    }
    for (final key in legacyLibrarySnapshotPreferencesKeys) {
      await preferences.remove(key);
    }
    await preferences.setBool(_legacyMigrationPreferenceKey, true);
  }
}

class _EncodedSnapshotHistory {
  const _EncodedSnapshotHistory({required this.history, required this.value});

  final SnapshotHistory history;
  final String value;
}

SnapshotHistory _decodeSnapshotHistory(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map) {
    return SnapshotHistory.fromJson(decoded.cast<String, Object?>());
  }
  return SnapshotHistory.empty;
}

String _encodeSnapshotHistory(Map<String, Object?> json) {
  return jsonEncode(json);
}

Future<_EncodedSnapshotHistory> _encodeHistoryWithinSize(
  SnapshotHistory history,
) async {
  final encoded = await compute(_encodeSnapshotHistory, history.toJson());
  if (encoded.length <=
      LibrarySnapshotRepository._maxStoredSnapshotCharacters) {
    return _EncodedSnapshotHistory(history: history, value: encoded);
  }

  final withCompactedCounters = await _findLargestRecentTrackCounterWindow(
    history,
  );
  if (withCompactedCounters != null) {
    return withCompactedCounters;
  }

  return _findLargestSnapshotWindow(
    _historyWithRecentTrackCounters(history, 0),
  );
}

Future<_EncodedSnapshotHistory?> _findLargestRecentTrackCounterWindow(
  SnapshotHistory history,
) async {
  _EncodedSnapshotHistory? best;
  var low = 0;
  var high = history.snapshotCount;
  while (low <= high) {
    final midpoint = (low + high) >> 1;
    final candidate = _historyWithRecentTrackCounters(history, midpoint);
    final encoded = await compute(_encodeSnapshotHistory, candidate.toJson());
    if (encoded.length <=
        LibrarySnapshotRepository._maxStoredSnapshotCharacters) {
      best = _EncodedSnapshotHistory(history: candidate, value: encoded);
      low = midpoint + 1;
    } else {
      high = midpoint - 1;
    }
  }
  return best;
}

Future<_EncodedSnapshotHistory> _findLargestSnapshotWindow(
  SnapshotHistory history,
) async {
  var best = _EncodedSnapshotHistory(
    history: SnapshotHistory.empty,
    value: await compute(
      _encodeSnapshotHistory,
      SnapshotHistory.empty.toJson(),
    ),
  );
  var low = 0;
  var high = history.snapshotCount;
  while (low <= high) {
    final midpoint = (low + high) >> 1;
    final candidate = _lastSnapshots(history, midpoint);
    final encoded = await compute(_encodeSnapshotHistory, candidate.toJson());
    if (encoded.length <=
        LibrarySnapshotRepository._maxStoredSnapshotCharacters) {
      best = _EncodedSnapshotHistory(history: candidate, value: encoded);
      low = midpoint + 1;
    } else {
      high = midpoint - 1;
    }
  }
  return best;
}

SnapshotHistory _historyWithRecentTrackCounters(
  SnapshotHistory history,
  int recentSnapshotsWithCounters,
) {
  final snapshots = history.snapshots;
  final firstDetailedIndex = snapshots.length - recentSnapshotsWithCounters;
  return SnapshotHistory(
    snapshots: List.unmodifiable([
      for (var index = 0; index < snapshots.length; index += 1)
        if (index < firstDetailedIndex)
          _snapshotWithoutTrackCounters(snapshots[index])
        else
          snapshots[index],
    ]),
  );
}

SnapshotHistory _lastSnapshots(SnapshotHistory history, int count) {
  if (count <= 0) {
    return SnapshotHistory.empty;
  }
  final snapshots = history.snapshots;
  final start = snapshots.length > count ? snapshots.length - count : 0;
  return SnapshotHistory(
    snapshots: List.unmodifiable(snapshots.sublist(start)),
  );
}

DailyLibrarySnapshot _snapshotWithoutTrackCounters(
  DailyLibrarySnapshot snapshot,
) {
  if (snapshot.tracks.isEmpty) {
    return snapshot;
  }
  return DailyLibrarySnapshot(
    dateKey: snapshot.dateKey,
    capturedAt: snapshot.capturedAt,
    source: snapshot.source,
    trackCount: snapshot.trackCount,
    totalPlayCount: snapshot.totalPlayCount,
    totalSkipCount: snapshot.totalSkipCount,
    totalListeningSeconds: snapshot.totalListeningSeconds,
    tracks: const [],
  );
}
