import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_overview.dart';
import '../domain/library_snapshot.dart';
import 'library_snapshot_store.dart';

final librarySnapshotRepositoryProvider = Provider<LibrarySnapshotRepository>((
  ref,
) {
  return const LibrarySnapshotRepository();
});

class LibrarySnapshotRepository {
  const LibrarySnapshotRepository({SnapshotStore? store}) : _store = store;

  static const _legacyMigrationPreferenceKey =
      'songbrief_daily_snapshots_file_store_migrated_v1';

  final SnapshotStore? _store;

  SnapshotStore get _effectiveStore => _store ?? createDefaultSnapshotStore();

  Future<SnapshotHistory> loadHistory() async {
    await _removeLegacyHistoryIfNeeded();
    return _effectiveStore.loadHistory();
  }

  Future<SnapshotHistory> recordSnapshot(
    LibraryOverview overview, {
    DateTime? capturedAt,
    String source = 'foreground',
  }) async {
    if (!overview.hasTracks) {
      return loadHistory();
    }

    await _removeLegacyHistoryIfNeeded();
    await _effectiveStore.writeSnapshot(
      DailyLibrarySnapshot.fromOverview(
        overview,
        capturedAt: capturedAt,
        source: source,
      ),
    );
    return _effectiveStore.loadHistory();
  }

  Future<SnapshotHistory> deleteSnapshotsOlderThan(DateTime cutoff) async {
    await _removeLegacyHistoryIfNeeded();
    await _effectiveStore.deleteSnapshotsOlderThan(cutoff);
    return _effectiveStore.loadHistory();
  }

  Future<SnapshotHistory> clearHistory() async {
    await _removeLegacyHistoryIfNeeded();
    await _effectiveStore.clearHistory();
    return SnapshotHistory.empty;
  }

  Future<void> _removeLegacyHistoryIfNeeded() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_legacyMigrationPreferenceKey) ?? false) {
      return;
    }
    for (final key in legacyLibrarySnapshotPreferencesKeys) {
      await preferences.remove(key);
    }
    await preferences.setBool(_legacyMigrationPreferenceKey, true);
  }
}
