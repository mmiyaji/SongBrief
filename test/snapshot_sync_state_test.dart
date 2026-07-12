import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/features/home/home_controller.dart';

void main() {
  test('snapshot sync state tracks progress and the latest result', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(snapshotSyncStateProvider.notifier);
    expect(container.read(snapshotSyncStateProvider).isSyncing, isFalse);

    controller.begin();
    expect(container.read(snapshotSyncStateProvider).isSyncing, isTrue);

    controller.complete(
      const SnapshotSyncResult(
        status: SnapshotSyncStatus.synced,
        downloaded: 2,
        uploaded: 1,
      ),
    );
    final completed = container.read(snapshotSyncStateProvider);
    expect(completed.isSyncing, isFalse);
    expect(completed.result?.status, SnapshotSyncStatus.synced);
    expect(completed.result?.downloaded, 2);
    expect(completed.lastAttemptAt, isNotNull);
  });
}
