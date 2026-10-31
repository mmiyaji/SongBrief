import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/data/supplemental_history_cloud_client.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';
import 'package:songbrief/src/features/home/supplemental_history_cloud_controller.dart';
import 'package:songbrief/src/features/home/supplemental_history_controller.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';
import 'package:songbrief/src/settings/supplemental_history_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('merges local and cloud evidence and uploads the union', () async {
    final remote = _history('remote', DateTime.utc(2026, 1, 2));
    final client = _FakeClient(remote.encode());
    final container = await _container(client);
    addTearDown(container.dispose);
    container.read(supplementalHistoryProvider.notifier).ingest([
      _track('local', DateTime.utc(2026, 1, 1)),
    ]);

    final status = await container
        .read(supplementalHistoryCloudControllerProvider.notifier)
        .syncCloud();

    expect(status, SupplementalHistoryCloudStatus.success);
    final combined = container.read(supplementalHistoryProvider);
    expect(combined.tracks.map((track) => track.id).toSet(), {
      'local',
      'remote',
    });
    expect(SupplementalListeningHistory.decode(client.saved).totalPlayCount, 2);
  });

  test('conflicts refetch and merge before retrying the save', () async {
    final client = _FakeClient(
      const SupplementalListeningHistory.empty().encode(),
    )..conflictOnce = true;
    final container = await _container(client);
    addTearDown(container.dispose);
    container.read(supplementalHistoryProvider.notifier).ingest([
      _track('local', DateTime.utc(2026, 1, 1)),
    ]);

    final status = await container
        .read(supplementalHistoryCloudControllerProvider.notifier)
        .syncCloud();

    expect(status, SupplementalHistoryCloudStatus.success);
    expect(client.fetchCount, 2);
    expect(client.saveCount, 2);
    expect(
      SupplementalListeningHistory.decode(client.saved).tracks.single.id,
      'local',
    );
  });

  test('offline and malformed responses preserve the local ledger', () async {
    for (final client in [
      _FakeClient(
        null,
        fetchStatus: SupplementalHistoryCloudStatus.unavailable,
      ),
      _FakeClient('{"version":1,"entries":[{"track":{}}]}'),
    ]) {
      final container = await _container(client);
      container.read(supplementalHistoryProvider.notifier).ingest([
        _track('keep', DateTime.utc(2026, 1, 1)),
      ]);
      final status = await container
          .read(supplementalHistoryCloudControllerProvider.notifier)
          .syncCloud();
      expect(status, isNot(SupplementalHistoryCloudStatus.success));
      expect(
        container.read(supplementalHistoryProvider).tracks.single.id,
        'keep',
      );
      container.dispose();
    }
  });

  test(
    'disabled cloud preference skips fetch while history inclusion is off',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(snapshotCloudSyncEnabledPreferenceKey, false);
      final client = _FakeClient(
        const SupplementalListeningHistory.empty().encode(),
      );
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(prefs),
          supplementalHistoryCloudClientProvider.overrideWithValue(client),
          supplementalHistoryCloudPlatformSupportedProvider.overrideWithValue(
            true,
          ),
        ],
      );
      addTearDown(container.dispose);
      final status = await container
          .read(supplementalHistoryCloudControllerProvider.notifier)
          .syncCloud();
      expect(status, SupplementalHistoryCloudStatus.disabled);
      expect(client.fetchCount, 0);
    },
  );

  test('overlapping sync calls share one in-flight fetch', () async {
    final client = _FakeClient(
      const SupplementalListeningHistory.empty().encode(),
    )..fetchGate = Completer<void>();
    final container = await _container(client);
    addTearDown(container.dispose);
    final controller = container.read(
      supplementalHistoryCloudControllerProvider.notifier,
    );
    final first = controller.syncCloud();
    final second = controller.syncCloud();
    await Future<void>.delayed(Duration.zero);
    expect(client.fetchCount, 1);
    client.fetchGate!.complete();
    expect(await first, SupplementalHistoryCloudStatus.success);
    expect(await second, SupplementalHistoryCloudStatus.success);
  });

  test(
    'two devices converge across reordered syncs and deduplicate evidence',
    () async {
      final shared = _SharedCloud();
      final a = await _container(_SharedClient(shared));
      final b = await _container(_SharedClient(shared));
      final day1 = DateTime.utc(2026, 3, 1);
      final day2 = DateTime.utc(2026, 3, 2);
      a.read(supplementalHistoryProvider.notifier).ingest([_sameSong(day1)]);
      b.read(supplementalHistoryProvider.notifier).ingest([
        _sameSong(day1),
        _sameSong(day2),
      ]);
      final aSync = a.read(supplementalHistoryCloudControllerProvider.notifier);
      final bSync = b.read(supplementalHistoryCloudControllerProvider.notifier);
      await aSync.syncCloud();
      await bSync.syncCloud();
      await aSync.syncCloud();
      await bSync.syncCloud();
      expect(a.read(supplementalHistoryProvider).totalPlayCount, 2);
      expect(b.read(supplementalHistoryProvider).totalPlayCount, 2);

      a.dispose();
      b.dispose();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final observedA = _SharedCloud();
      final oa = await _container(_SharedClient(observedA));
      final ob = await _container(_SharedClient(observedA));
      addTearDown(oa.dispose);
      addTearDown(ob.dispose);
      oa
          .read(supplementalHistoryProvider.notifier)
          .observe(_sameSong(day1), at: day1);
      ob
          .read(supplementalHistoryProvider.notifier)
          .observe(_sameSong(day1), at: day2);
      await oa
          .read(supplementalHistoryCloudControllerProvider.notifier)
          .syncCloud();
      await ob
          .read(supplementalHistoryCloudControllerProvider.notifier)
          .syncCloud();
      await oa
          .read(supplementalHistoryCloudControllerProvider.notifier)
          .syncCloud();
      expect(oa.read(supplementalHistoryProvider).totalPlayCount, 1);
      expect(ob.read(supplementalHistoryProvider).totalPlayCount, 1);
    },
  );

  test(
    'history inclusion off does not disable cloud synchronization',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(supplementalHistoryIncludedPreferenceKey, false);
      final client = _FakeClient(
        const SupplementalListeningHistory.empty().encode(),
      );
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(prefs),
          supplementalHistoryCloudClientProvider.overrideWithValue(client),
          supplementalHistoryCloudPlatformSupportedProvider.overrideWithValue(
            true,
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container
            .read(supplementalHistoryCloudControllerProvider.notifier)
            .syncCloud(),
        SupplementalHistoryCloudStatus.success,
      );
      expect(client.fetchCount, 1);
    },
  );

  test(
    'local append during save survives and triggers a follow-up union',
    () async {
      final client = _FakeClient(
        const SupplementalListeningHistory.empty().encode(),
      )..saveGate = Completer<void>();
      final container = await _container(client);
      addTearDown(container.dispose);
      container.read(supplementalHistoryProvider.notifier).ingest([
        _track('first', DateTime.utc(2026, 1, 1)),
      ]);
      final sync = container
          .read(supplementalHistoryCloudControllerProvider.notifier)
          .syncCloud();
      await Future<void>.delayed(Duration.zero);
      container.read(supplementalHistoryProvider.notifier).ingest([
        _track('during-save', DateTime.utc(2026, 1, 2)),
      ]);
      client.saveGate!.complete();
      expect(await sync, SupplementalHistoryCloudStatus.success);
      expect(client.fetchCount, 2);
      expect(
        SupplementalListeningHistory.decode(client.saved).tracks
            .map((track) => track.id)
            .toSet(),
        {'first', 'during-save'},
      );
    },
  );

  test('turning cloud sync off during fetch prevents upload', () async {
    final client = _FakeClient(
      const SupplementalListeningHistory.empty().encode(),
    )..fetchGate = Completer<void>();
    final container = await _container(client);
    addTearDown(container.dispose);
    container.read(supplementalHistoryProvider.notifier).ingest([
      _track('local', DateTime.utc(2026, 1, 1)),
    ]);
    final sync = container
        .read(supplementalHistoryCloudControllerProvider.notifier)
        .syncCloud();
    await Future<void>.delayed(Duration.zero);
    container.read(snapshotCloudSyncProvider.notifier).setEnabled(false);
    client.fetchGate!.complete();
    expect(await sync, SupplementalHistoryCloudStatus.disabled);
    expect(client.saveCount, 0);
  });

  test('sync waits for asynchronous preferences restoration', () async {
    SharedPreferences.setMockInitialValues({});
    final restored = Completer<SharedPreferences>();
    final client = _FakeClient(
      const SupplementalListeningHistory.empty().encode(),
    );
    final container = ProviderContainer(
      overrides: [
        musicDataPreferencesLoaderProvider.overrideWithValue(
          () => restored.future,
        ),
        supplementalHistoryCloudClientProvider.overrideWithValue(client),
        supplementalHistoryCloudPlatformSupportedProvider.overrideWithValue(
          true,
        ),
      ],
    );
    addTearDown(container.dispose);
    final sync = container
        .read(supplementalHistoryCloudControllerProvider.notifier)
        .syncCloud();
    await Future<void>.delayed(Duration.zero);
    expect(client.fetchCount, 0);
    restored.complete(await SharedPreferences.getInstance());
    expect(await sync, SupplementalHistoryCloudStatus.success);
    expect(client.fetchCount, 1);
  });

  test(
    'exhausted conflicts report conflict and retain local evidence',
    () async {
      final client = _FakeClient(
        const SupplementalListeningHistory.empty().encode(),
      )..conflictsRemaining = 5;
      final container = await _container(client);
      addTearDown(container.dispose);
      container.read(supplementalHistoryProvider.notifier).ingest([
        _track('preserve', DateTime.utc(2026, 1, 1)),
      ]);
      expect(
        await container
            .read(supplementalHistoryCloudControllerProvider.notifier)
            .syncCloud(),
        SupplementalHistoryCloudStatus.conflict,
      );
      expect(client.fetchCount, 3);
      expect(
        container.read(supplementalHistoryProvider).tracks.single.id,
        'preserve',
      );
    },
  );
}

Future<ProviderContainer> _container(
  SupplementalHistoryCloudClient client,
) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      musicDataSharedPreferencesProvider.overrideWithValue(prefs),
      supplementalHistoryCloudClientProvider.overrideWithValue(client),
      supplementalHistoryCloudPlatformSupportedProvider.overrideWithValue(true),
    ],
  );
  await container.read(supplementalHistoryProvider.notifier).restored;
  await container.read(snapshotCloudSyncProvider.notifier).restored;
  return container;
}

SupplementalListeningHistory _history(String id, DateTime date) =>
    const SupplementalListeningHistory.empty().ingest([_track(id, date)]);

LibraryTrack _track(String id, DateTime date) => LibraryTrack(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(minutes: 3),
  playCount: 1,
  skipCount: 0,
  isCloudItem: false,
  lastPlayedAt: date,
);

LibraryTrack _sameSong(DateTime date) => LibraryTrack(
  id: 'device-${date.day}',
  title: 'Shared song',
  artist: 'Shared artist',
  albumTitle: 'Shared album',
  duration: const Duration(minutes: 3),
  playCount: 1,
  skipCount: 0,
  isCloudItem: false,
  lastPlayedAt: date,
);

class _FakeClient implements SupplementalHistoryCloudClient {
  _FakeClient(
    this.payload, {
    this.fetchStatus = SupplementalHistoryCloudStatus.success,
  });

  String? payload;
  final SupplementalHistoryCloudStatus fetchStatus;
  int fetchCount = 0;
  int saveCount = 0;
  String? saved;
  bool conflictOnce = false;
  int conflictsRemaining = 0;
  Completer<void>? fetchGate;
  Completer<void>? saveGate;

  @override
  Future<SupplementalHistoryCloudResult> fetch() async {
    fetchCount++;
    await fetchGate?.future;
    return SupplementalHistoryCloudResult(
      status: fetchStatus,
      payload: payload,
      revision: 'r$fetchCount',
    );
  }

  @override
  Future<SupplementalHistoryCloudResult> save({
    required String payload,
    required String? revision,
  }) async {
    saveCount++;
    await saveGate?.future;
    if (conflictsRemaining > 0) {
      conflictsRemaining--;
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.conflict,
      );
    }
    if (conflictOnce) {
      conflictOnce = false;
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.conflict,
      );
    }
    saved = payload;
    this.payload = payload;
    return SupplementalHistoryCloudResult(
      status: SupplementalHistoryCloudStatus.success,
      revision: 'saved',
    );
  }
}

class _SharedCloud {
  String? payload;
  int revision = 0;
}

class _SharedClient implements SupplementalHistoryCloudClient {
  _SharedClient(this.store);
  final _SharedCloud store;

  @override
  Future<SupplementalHistoryCloudResult> fetch() async =>
      SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.success,
        payload: store.payload,
        revision: '${store.revision}',
      );

  @override
  Future<SupplementalHistoryCloudResult> save({
    required String payload,
    required String? revision,
  }) async {
    if (revision != '${store.revision}') {
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.conflict,
      );
    }
    store.payload = payload;
    store.revision++;
    return SupplementalHistoryCloudResult(
      status: SupplementalHistoryCloudStatus.success,
      revision: '${store.revision}',
    );
  }
}
