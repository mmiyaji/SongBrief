import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_library_preferences.dart';
import 'library_filter_preferences.dart';
import 'snapshot_preferences.dart';

final musicDataPreferencesReadyProvider = FutureProvider<void>((ref) async {
  ref.read(snapshotRecordingProvider);
  ref.read(snapshotCloudSyncProvider);
  ref.read(temporaryDemoLibraryProvider);
  ref.read(libraryFilterPreferencesProvider);

  await Future.wait([
    ref.read(snapshotRecordingProvider.notifier).restored,
    ref.read(snapshotCloudSyncProvider.notifier).restored,
    ref.read(temporaryDemoLibraryProvider.notifier).restored,
    ref.read(libraryFilterPreferencesProvider.notifier).restored,
  ]);
});
