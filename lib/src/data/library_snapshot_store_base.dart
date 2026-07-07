import '../domain/library_snapshot.dart';

abstract interface class SnapshotStore {
  Future<SnapshotHistory> loadHistory();

  Future<void> writeSnapshot(DailyLibrarySnapshot snapshot);

  Future<void> deleteSnapshotsOlderThan(DateTime cutoff);

  Future<void> clearHistory();
}
