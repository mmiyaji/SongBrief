import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/data/supplemental_history_cloud_client.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/features/home/supplemental_history_cloud_controller.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';

void main() {
  test('snapshot success does not hide outside history failure', () {
    final container = ProviderContainer(
      overrides: [
        supplementalHistoryCloudPlatformSupportedProvider.overrideWithValue(
          true,
        ),
        snapshotCloudSyncProvider.overrideWith(_Enabled.new),
        supplementalHistoryCloudControllerProvider.overrideWith(_Cloud.new),
      ],
    );
    addTearDown(container.dispose);
    final outside = container.read(
      supplementalHistoryCloudControllerProvider.notifier,
    ) as _Cloud;
    container
        .read(snapshotSyncStateProvider.notifier)
        .complete(
          const SnapshotSyncResult(
            status: SnapshotSyncStatus.synced,
            uploaded: 2,
          ),
        );
    expect(
      container.read(listeningHistorySyncStateProvider).result?.status,
      SnapshotSyncStatus.partial,
    );
    outside.setStatus(SupplementalHistoryCloudStatus.success);
    expect(
      container.read(listeningHistorySyncStateProvider).result?.status,
      SnapshotSyncStatus.synced,
    );
    expect(
      container.read(listeningHistorySyncStateProvider).result?.uploaded,
      2,
    );
  });

  test(
    'outside history sync remains visible when daily snapshots are disabled',
    () {
      final container = ProviderContainer(
        overrides: [
          supplementalHistoryCloudPlatformSupportedProvider.overrideWithValue(
            true,
          ),
          snapshotCloudSyncProvider.overrideWith(_Enabled.new),
          supplementalHistoryCloudControllerProvider.overrideWith(_Cloud.new),
        ],
      );
      addTearDown(container.dispose);
      final outside = container.read(
        supplementalHistoryCloudControllerProvider.notifier,
      ) as _Cloud;
      container.read(snapshotSyncStateProvider.notifier).unavailable();
      expect(
        container.read(listeningHistorySyncStateProvider).result?.status,
        SnapshotSyncStatus.error,
      );
      outside.setStatus(SupplementalHistoryCloudStatus.success);
      expect(
        container.read(listeningHistorySyncStateProvider).result?.status,
        SnapshotSyncStatus.synced,
      );
    },
  );
}

class _Enabled extends SnapshotCloudSyncController {
  @override
  bool build() => true;
}

class _Cloud extends SupplementalHistoryCloudController {
  @override
  SupplementalHistoryCloudStatus build() =>
      SupplementalHistoryCloudStatus.error;
  void setStatus(SupplementalHistoryCloudStatus status) => state = status;
}
