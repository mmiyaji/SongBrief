import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_overview.dart';
import '../domain/library_snapshot.dart';
import 'library_snapshot_store.dart';

final librarySnapshotRepositoryProvider = Provider<LibrarySnapshotRepository>((
  ref,
) {
  return LibrarySnapshotRepository();
});

class LibrarySnapshotRepository {
  LibrarySnapshotRepository({SnapshotStore? store}) : _store = store;

  static const _legacyMigrationPreferenceKey =
      'songbrief_daily_snapshots_file_store_migrated_v1';

  final SnapshotStore? _store;
  bool _legacyMigrationChecked = false;

  SnapshotStore get _effectiveStore => _store ?? createDefaultSnapshotStore();

  Future<SnapshotHistory> loadHistory() async {
    await _migrateLegacyHistoryIfNeeded();
    return _effectiveStore.loadHistory();
  }

  Future<SnapshotHistory> recordSnapshot(
    LibraryOverview overview, {
    DateTime? capturedAt,
    String source = 'foreground',
    String? filterSignature,
  }) async {
    if (!overview.hasTracks) {
      return loadHistory();
    }

    await _migrateLegacyHistoryIfNeeded();
    final snapshot = DailyLibrarySnapshot.fromOverview(
      overview,
      capturedAt: capturedAt,
      source: source,
      filterSignature: filterSignature,
    );
    await _effectiveStore.writeSnapshot(snapshot);
    return _effectiveStore.loadHistory();
  }

  Future<SnapshotHistory> deleteSnapshotsOlderThan(DateTime cutoff) async {
    await _migrateLegacyHistoryIfNeeded();
    await _effectiveStore.deleteSnapshotsOlderThan(cutoff);
    return _effectiveStore.loadHistory();
  }

  Future<SnapshotHistory> clearHistory() async {
    await _migrateLegacyHistoryIfNeeded();
    await _effectiveStore.clearHistory();
    return SnapshotHistory.empty;
  }

  Future<void> _migrateLegacyHistoryIfNeeded() async {
    if (_legacyMigrationChecked) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final legacyValues = {
      for (final key in legacyLibrarySnapshotPreferencesKeys)
        key: preferences.getString(key),
    };
    final hasLegacyHistory = legacyValues.values.any(
      (value) => value != null && value.isNotEmpty,
    );
    if ((preferences.getBool(_legacyMigrationPreferenceKey) ?? false) &&
        !hasLegacyHistory) {
      _legacyMigrationChecked = true;
      return;
    }
    final store = _effectiveStore;
    for (final entry in legacyValues.entries) {
      final history = await _decodeLegacyHistory(entry.value);
      for (final snapshot in history.snapshots) {
        await store.writeSnapshot(snapshot);
      }
      await preferences.remove(entry.key);
    }
    await preferences.setBool(_legacyMigrationPreferenceKey, true);
    _legacyMigrationChecked = true;
  }
}

Future<SnapshotHistory> _decodeLegacyHistory(String? raw) async {
  if (raw == null || raw.isEmpty) {
    return SnapshotHistory.empty;
  }
  return compute(_decodeSnapshotHistory, raw);
}

SnapshotHistory _decodeSnapshotHistory(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return SnapshotHistory.fromJson(decoded.cast<String, Object?>());
    }
  } on FormatException {
    return SnapshotHistory.empty;
  }
  return SnapshotHistory.empty;
}
