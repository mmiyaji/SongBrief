import 'library_snapshot_store_base.dart';
import 'library_snapshot_store_fallback.dart'
    if (dart.library.io) 'library_snapshot_store_io.dart'
    as platform;

export 'library_snapshot_store_base.dart';

SnapshotStore createDefaultSnapshotStore() {
  return platform.createSnapshotStore();
}
