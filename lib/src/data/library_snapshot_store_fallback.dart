import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_snapshot.dart';
import 'library_snapshot_store_base.dart';

SnapshotStore createSnapshotStore() {
  return const PreferencesSnapshotStore();
}

class PreferencesSnapshotStore implements SnapshotStore {
  const PreferencesSnapshotStore();

  @override
  Future<SnapshotHistory> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final raw = preferences.getString(librarySnapshotFallbackPreferencesKey);
    if (raw == null || raw.isEmpty) {
      return SnapshotHistory.empty;
    }
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

  @override
  Future<void> writeSnapshot(DailyLibrarySnapshot snapshot) async {
    final history = (await loadHistory()).withSnapshot(snapshot);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      librarySnapshotFallbackPreferencesKey,
      jsonEncode(history.toJson()),
    );
  }

  @override
  Future<void> deleteSnapshotsOlderThan(DateTime cutoff) async {
    final history = await loadHistory();
    final snapshots = history.snapshots
        .where((snapshot) => !snapshot.capturedAt.isBefore(cutoff))
        .toList(growable: false);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      librarySnapshotFallbackPreferencesKey,
      jsonEncode(
        SnapshotHistory(snapshots: List.unmodifiable(snapshots)).toJson(),
      ),
    );
  }

  @override
  Future<void> clearHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(librarySnapshotFallbackPreferencesKey);
  }
}
