import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SnapshotCloudSyncController', () {
    test('defaults to enabled', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(snapshotCloudSyncProvider), isTrue);
    });

    test('restores a saved opt-out', () async {
      SharedPreferences.setMockInitialValues({
        snapshotCloudSyncEnabledPreferenceKey: false,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(snapshotCloudSyncProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(snapshotCloudSyncProvider), isFalse);
    });

    test('persists user changes', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(snapshotCloudSyncProvider.notifier).setEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(snapshotCloudSyncProvider), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(snapshotCloudSyncEnabledPreferenceKey),
        isFalse,
      );
    });
  });

  group('SnapshotSyncResult', () {
    test('parses a platform payload', () {
      final result = SnapshotSyncResult.fromPlatformValue({
        'status': 'synced',
        'downloaded': 2,
        'uploaded': 1,
        'deleted': 3,
      });

      expect(result.status, SnapshotSyncStatus.synced);
      expect(result.downloaded, 2);
      expect(result.uploaded, 1);
      expect(result.deleted, 3);
      expect(result.changedLocally, isTrue);
    });

    test('maps every known status string', () {
      const expected = {
        'synced': SnapshotSyncStatus.synced,
        'unchanged': SnapshotSyncStatus.unchanged,
        'partial': SnapshotSyncStatus.partial,
        'disabled': SnapshotSyncStatus.disabled,
        'noAccount': SnapshotSyncStatus.noAccount,
        'unavailable': SnapshotSyncStatus.unavailable,
      };
      for (final entry in expected.entries) {
        expect(
          SnapshotSyncResult.fromPlatformValue({'status': entry.key}).status,
          entry.value,
        );
      }
    });

    test('treats malformed payloads as errors', () {
      expect(
        SnapshotSyncResult.fromPlatformValue(null).status,
        SnapshotSyncStatus.error,
      );
      expect(
        SnapshotSyncResult.fromPlatformValue('synced').status,
        SnapshotSyncStatus.error,
      );

      final negative = SnapshotSyncResult.fromPlatformValue({
        'status': 'mystery',
        'downloaded': -4,
      });
      expect(negative.status, SnapshotSyncStatus.error);
      expect(negative.downloaded, 0);
      expect(negative.changedLocally, isFalse);
    });
  });

  group('MusicStatsRepository cloud sync', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    MusicStatsRepository repository(
      _CloudSyncSpyClient client, {
      bool recordingEnabled = true,
      bool cloudSyncEnabled = true,
    }) {
      return MusicStatsRepository(
        client,
        const LibrarySnapshotRepository(),
        snapshotRecordingEnabled: recordingEnabled,
        cloudSyncEnabled: cloudSyncEnabled,
      );
    }

    test('delegates sync to the platform client when enabled', () async {
      final client = _CloudSyncSpyClient()
        ..syncResult = const SnapshotSyncResult(
          status: SnapshotSyncStatus.synced,
          downloaded: 1,
        );

      final result = await repository(client).syncCloudSnapshots();

      expect(client.syncCalls, 1);
      expect(result?.status, SnapshotSyncStatus.synced);
      expect(result?.changedLocally, isTrue);
    });

    test('skips sync when the cloud toggle is off', () async {
      final client = _CloudSyncSpyClient();

      final result = await repository(
        client,
        cloudSyncEnabled: false,
      ).syncCloudSnapshots();

      expect(result, isNull);
      expect(client.syncCalls, 0);
    });

    test('skips sync when recording is disabled', () async {
      final client = _CloudSyncSpyClient();

      final result = await repository(
        client,
        recordingEnabled: false,
      ).syncCloudSnapshots();

      expect(result, isNull);
      expect(client.syncCalls, 0);
    });

    test('skips sync outside the iOS music runtime', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final client = _CloudSyncSpyClient();

      final result = await repository(client).syncCloudSnapshots();

      expect(result, isNull);
      expect(client.syncCalls, 0);
    });

    test('reports client failures as an error result', () async {
      final client = _CloudSyncSpyClient()..throwOnSync = true;

      final result = await repository(client).syncCloudSnapshots();

      expect(result?.status, SnapshotSyncStatus.error);
    });

    test('clearing history also clears the cloud copy', () async {
      final client = _CloudSyncSpyClient();

      await repository(client).clearSnapshotHistory();

      expect(client.deleteCalls, 1);
      expect(client.lastDeleteCutoff, isNull);
    });

    test('deleting old records propagates the cutoff dateKey', () async {
      final client = _CloudSyncSpyClient();

      await repository(client).deleteSnapshotsOlderThan(DateTime(2026, 7, 1));

      expect(client.deleteCalls, 1);
      expect(client.lastDeleteCutoff, '2026-07-01');
    });

    test('cloud deletion failures do not break local deletion', () async {
      final client = _CloudSyncSpyClient()..throwOnDelete = true;

      final history = await repository(client).clearSnapshotHistory();

      expect(history.snapshots, isEmpty);
      expect(client.deleteCalls, 1);
    });

    test('skips cloud deletion when the cloud toggle is off', () async {
      final client = _CloudSyncSpyClient();

      await repository(client, cloudSyncEnabled: false).clearSnapshotHistory();

      expect(client.deleteCalls, 0);
    });

    test('loads a large library through the overview build path', () async {
      final client = _CloudSyncSpyClient()
        ..tracks = List.generate(
          800,
          (index) => LibraryTrack(
            id: 'large-track-$index',
            title: 'Large Track $index',
            artist: 'Artist ${index % 25}',
            albumTitle: 'Album ${index % 40}',
            duration: const Duration(minutes: 3),
            playCount: 800 - index,
            skipCount: index % 9,
            isCloudItem: false,
          ),
        );

      final stats = await repository(client, recordingEnabled: false).load();

      expect(stats.overview.totalTracks, 800);
      expect(stats.overview.tracksByPlayCount.first.title, 'Large Track 0');
      expect(stats.snapshotRecordingEnabled, isFalse);
      expect(stats.snapshotHistory.snapshotCount, 0);
    });
  });
}

class _CloudSyncSpyClient implements MusicLibraryClient {
  int syncCalls = 0;
  int deleteCalls = 0;
  String? lastDeleteCutoff;
  bool throwOnSync = false;
  bool throwOnDelete = false;
  List<LibraryTrack> tracks = const [];
  SnapshotSyncResult syncResult = const SnapshotSyncResult(
    status: SnapshotSyncStatus.unchanged,
  );

  @override
  Future<SnapshotSyncResult> syncSnapshotHistory() async {
    syncCalls += 1;
    if (throwOnSync) {
      throw StateError('sync failed');
    }
    return syncResult;
  }

  @override
  Future<SnapshotSyncResult> deleteCloudSnapshots({
    String? olderThanDateKey,
  }) async {
    deleteCalls += 1;
    lastDeleteCutoff = olderThanDateKey;
    if (throwOnDelete) {
      throw StateError('delete failed');
    }
    return const SnapshotSyncResult(status: SnapshotSyncStatus.synced);
  }

  @override
  Future<MusicLibraryAuthorizationStatus> authorizationStatus() async {
    return MusicLibraryAuthorizationStatus.authorized;
  }

  @override
  Future<MusicLibraryAuthorizationStatus> requestAuthorization() async {
    return MusicLibraryAuthorizationStatus.authorized;
  }

  @override
  Future<List<LibraryTrack>> fetchTracks() async {
    return tracks;
  }

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() async {
    return null;
  }

  @override
  Stream<MusicPlaybackSnapshot> playbackEvents() {
    return const Stream.empty();
  }

  @override
  Future<Uint8List?> fetchArtwork(String trackId, {required int size}) async {
    return null;
  }

  @override
  Future<void> playTrack(String trackId) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> scheduleSnapshotRefresh() async {}
}
