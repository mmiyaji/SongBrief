import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_library_preferences.dart';
import 'library_filter_preferences.dart';
import 'snapshot_preferences.dart';

final musicDataPreferencesReadyProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    _waitForPreferenceRestore(
      initialize: () => ref.read(snapshotRecordingProvider),
      restored: () => ref.read(snapshotRecordingProvider.notifier).restored,
    ),
    _waitForPreferenceRestore(
      initialize: () => ref.read(snapshotCloudSyncProvider),
      restored: () => ref.read(snapshotCloudSyncProvider.notifier).restored,
    ),
    _waitForPreferenceRestore(
      initialize: () => ref.read(temporaryDemoLibraryProvider),
      restored: () => ref.read(temporaryDemoLibraryProvider.notifier).restored,
    ),
    _waitForPreferenceRestore(
      initialize: () => ref.read(libraryFilterPreferencesProvider),
      restored: () =>
          ref.read(libraryFilterPreferencesProvider.notifier).restored,
    ),
  ]);
});

Future<void> _waitForPreferenceRestore({
  required void Function() initialize,
  required Future<void> Function() restored,
}) async {
  try {
    initialize();
    await restored();
  } on Object {
    // A single unavailable preference must not block the initial library load.
  }
}
