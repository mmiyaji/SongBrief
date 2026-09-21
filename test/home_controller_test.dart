import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final clearAll in [true, false]) {
    test(
      'history ${clearAll ? 'clear' : 'prune'} updates the native widget',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const channel = MethodChannel('app.songbrief/music_library');
        final updates = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'updateHomeWidget') updates.add(call);
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final repository = _WidgetDeletionRepository();
        final container = ProviderContainer(
          overrides: [
            musicStatsRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        await container.read(musicStatsControllerProvider.future);
        final controller = container.read(
          musicStatsControllerProvider.notifier,
        );
        await controller.syncCloudSnapshots();
        expect((updates.last.arguments as Map)['summary']['snapshotCount'], 2);
        updates.clear();

        if (clearAll) {
          await controller.clearSnapshotHistory();
        } else {
          await controller.deleteSnapshotsOlderThan(DateTime(2026, 7, 9));
        }

        expect(updates, hasLength(1));
        final summary = (updates.single.arguments as Map)['summary'] as Map?;
        if (clearAll) {
          expect(summary, isNull);
        } else {
          expect(summary!['snapshotCount'], 1);
          expect(summary['recent7PlayDelta'], 0);
        }
        expect(
          container
              .read(musicStatsControllerProvider)
              .requireValue
              .snapshotHistory
              .snapshotCount,
          clearAll ? 0 : 1,
        );
      },
    );
  }

  test('demo refresh does not replace the native widget history', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('app.songbrief/music_library');
    final updates = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'updateHomeWidget') updates.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final repository = _WidgetRefreshRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(musicStatsControllerProvider.future);
    final controller = container.read(musicStatsControllerProvider.notifier);
    await controller.syncCloudSnapshots();
    updates.clear();
    repository.demo = true;
    await controller.refreshStatsSilently();
    expect(
      container.read(musicStatsControllerProvider).requireValue.isDemo,
      isTrue,
    );
    expect(updates, isEmpty);
  });

  test(
    'granting music access publishes the captured history and starts sync',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('app.songbrief/music_library');
      final updates = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'updateHomeWidget') updates.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final repository = _WidgetRefreshRepository()..demo = true;
      final container = ProviderContainer(
        overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(musicStatsControllerProvider.future);
      final controller = container.read(musicStatsControllerProvider.notifier);
      repository.demo = false;
      await controller.requestAccess();
      await Future<void>.delayed(Duration.zero);
      expect(repository.syncCalls, 1);
      expect(updates, hasLength(1));
      expect((updates.single.arguments as Map)['summary']['snapshotCount'], 2);
    },
  );

  test('silent stats refresh keeps previous data while loading', () async {
    final repository = _ControlledMusicStatsRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);

    final refresh = container
        .read(musicStatsControllerProvider.notifier)
        .refreshStatsSilently();
    await Future<void>.delayed(Duration.zero);

    final duringRefresh = container.read(musicStatsControllerProvider);
    expect(duringRefresh.hasValue, isTrue);
    expect(duringRefresh.requireValue.overview.latestTrack?.title, 'Initial');

    repository.completeRefresh(_state('Updated'));
    await refresh;

    final afterRefresh = container.read(musicStatsControllerProvider);
    expect(afterRefresh.requireValue.overview.latestTrack?.title, 'Updated');
  });

  test('stats refresh does not wait for playback synchronization', () async {
    final repository = _HangingPlaybackRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);
    final refresh = container
        .read(musicStatsControllerProvider.notifier)
        .refreshStatsSilently();
    await Future<void>.delayed(Duration.zero);
    repository.completeRefresh(_state('Updated without playback'));

    await refresh.timeout(const Duration(seconds: 1));
    expect(
      container
          .read(musicStatsControllerProvider)
          .requireValue
          .overview
          .latestTrack
          ?.title,
      'Updated without playback',
    );
  });

  test('overlapping stats refreshes share one repository load', () async {
    final repository = _ControlledMusicStatsRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);
    final notifier = container.read(musicStatsControllerProvider.notifier);

    final silentRefresh = notifier.refreshStatsSilently();
    final manualRefresh = notifier.refreshStats();
    await Future<void>.delayed(Duration.zero);

    expect(identical(silentRefresh, manualRefresh), isTrue);
    expect(repository.loadCount, 2);

    repository.completeRefresh(_state('Coalesced'));
    await Future.wait([silentRefresh, manualRefresh]);

    expect(
      container
          .read(musicStatsControllerProvider)
          .requireValue
          .overview
          .latestTrack
          ?.title,
      'Coalesced',
    );

    await notifier.refreshStatsSilently();
    expect(repository.loadCount, 3);
  });

  test('initial load waits for persisted music data settings', () async {
    SharedPreferences.setMockInitialValues({
      snapshotRecordingEnabledPreferenceKey: false,
    });
    final repository = _ControlledMusicStatsRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);

    expect(container.read(snapshotRecordingProvider), isFalse);
    expect(repository.loadCount, 1);
  });

  test('demo state cannot delete persisted listening history', () async {
    final repository = _ControlledMusicStatsRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);

    await expectLater(
      container
          .read(musicStatsControllerProvider.notifier)
          .clearSnapshotHistory(),
      throwsStateError,
    );
  });

  test('history deletion waits for an in-flight cloud sync', () async {
    final repository = _SnapshotRaceRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);
    await repository.syncStarted.future;

    final deletion = container
        .read(musicStatsControllerProvider.notifier)
        .clearSnapshotHistory();
    await Future<void>.delayed(Duration.zero);

    expect(repository.clearStarted, isFalse);

    repository.releaseSync();
    await deletion;

    expect(repository.clearStarted, isTrue);
    expect(
      container
          .read(musicStatsControllerProvider)
          .requireValue
          .snapshotHistory
          .snapshotCount,
      0,
    );
  });

  test('stats recording waits for an in-flight cloud sync', () async {
    final repository = _SnapshotRaceRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(musicStatsControllerProvider.future);
    await repository.syncStarted.future;

    final refresh = container
        .read(musicStatsControllerProvider.notifier)
        .refreshStatsSilently();
    await Future<void>.delayed(Duration.zero);

    expect(repository.loadCount, 1);

    repository.releaseSync();
    await refresh;

    expect(repository.loadCount, 2);
    await container
        .read(musicStatsControllerProvider.notifier)
        .syncCloudSnapshots();
  });
}

MusicStatsState _state(String title) {
  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
    overview: LibraryOverview.fromTracks([
      LibraryTrack(
        id: title.toLowerCase(),
        title: title,
        artist: 'Test Artist',
        albumTitle: 'Test Album',
        duration: const Duration(minutes: 3),
        playCount: 1,
        skipCount: 0,
        lastPlayedAt: DateTime(2026),
        isCloudItem: false,
      ),
    ], isDemo: true),
    snapshotHistory: SnapshotHistory.empty,
  );
}

class _ControlledMusicStatsRepository extends MusicStatsRepository {
  _ControlledMusicStatsRepository()
    : super(const _NoopMusicLibraryClient(), LibrarySnapshotRepository());

  var _loadCount = 0;
  Completer<MusicStatsState>? _pendingRefresh;

  int get loadCount => _loadCount;

  @override
  Future<MusicStatsState> load({bool requestAccess = false}) {
    _loadCount += 1;
    if (_loadCount == 1) {
      return Future.value(_state('Initial'));
    }
    _pendingRefresh ??= Completer<MusicStatsState>();
    return _pendingRefresh!.future;
  }

  void completeRefresh(MusicStatsState state) {
    _pendingRefresh?.complete(state);
  }

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() {
    return Future.value();
  }
}

class _HangingPlaybackRepository extends _ControlledMusicStatsRepository {
  final _playback = Completer<MusicPlaybackSnapshot?>();

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() => _playback.future;
}

class _SnapshotRaceRepository extends MusicStatsRepository {
  _SnapshotRaceRepository()
    : super(const _NoopMusicLibraryClient(), LibrarySnapshotRepository());

  final syncStarted = Completer<void>();
  final _syncRelease = Completer<void>();
  var clearStarted = false;
  var loadCount = 0;

  final _history = SnapshotHistory(
    snapshots: [
      DailyLibrarySnapshot(
        dateKey: '2026-07-09',
        capturedAt: DateTime(2026, 7, 9, 12),
        source: 'foreground',
        trackCount: 1,
        totalPlayCount: 4,
        totalSkipCount: 0,
        totalListeningSeconds: 720,
        tracks: const [],
      ),
    ],
  );

  @override
  Future<MusicStatsState> load({bool requestAccess = false}) {
    loadCount += 1;
    return Future.value(_libraryState(_history));
  }

  @override
  Future<SnapshotSyncResult?> syncCloudSnapshots() async {
    if (!syncStarted.isCompleted) {
      syncStarted.complete();
    }
    await _syncRelease.future;
    return const SnapshotSyncResult(
      status: SnapshotSyncStatus.synced,
      downloaded: 1,
    );
  }

  @override
  Future<SnapshotHistory> loadSnapshotHistory() {
    return Future.value(_history);
  }

  @override
  Future<SnapshotHistory> clearSnapshotHistory() async {
    clearStarted = true;
    return SnapshotHistory.empty;
  }

  void releaseSync() {
    if (!_syncRelease.isCompleted) {
      _syncRelease.complete();
    }
  }
}

class _WidgetDeletionRepository extends _SnapshotRaceRepository {
  late final history = SnapshotHistory(
    snapshots: [
      DailyLibrarySnapshot(
        dateKey: '2026-07-08',
        capturedAt: DateTime(2026, 7, 8, 12),
        source: 'foreground',
        trackCount: 1,
        totalPlayCount: 1,
        totalSkipCount: 0,
        totalListeningSeconds: 180,
        tracks: const [],
      ),
      ..._history.snapshots,
    ],
  );

  @override
  Future<MusicStatsState> load({bool requestAccess = false}) async =>
      _libraryState(history);

  @override
  Future<SnapshotSyncResult?> syncCloudSnapshots() async => null;

  @override
  Future<SnapshotHistory> deleteSnapshotsOlderThan(DateTime cutoff) async {
    return SnapshotHistory(
      snapshots: history.snapshots
          .where((snapshot) => !snapshot.capturedAt.isBefore(cutoff))
          .toList(),
    );
  }
}

class _WidgetRefreshRepository extends _WidgetDeletionRepository {
  bool demo = false;
  int syncCalls = 0;

  @override
  Future<MusicStatsState> load({bool requestAccess = false}) async =>
      demo ? _state('Demo') : _libraryState(history);

  @override
  Future<SnapshotSyncResult?> syncCloudSnapshots() async {
    syncCalls += 1;
    return null;
  }
}

class _NoopMusicLibraryClient implements MusicLibraryClient {
  const _NoopMusicLibraryClient();

  @override
  Future<MusicLibraryAuthorizationStatus> authorizationStatus() {
    return Future.value(MusicLibraryAuthorizationStatus.unsupported);
  }

  @override
  Future<MusicLibraryAuthorizationStatus> requestAuthorization() {
    return Future.value(MusicLibraryAuthorizationStatus.unsupported);
  }

  @override
  Future<bool> openAppSettings() => Future.value(false);

  @override
  Future<List<LibraryTrack>> fetchTracks() {
    return Future.value(const []);
  }

  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() {
    return Future.value();
  }

  @override
  Stream<MusicPlaybackSnapshot> playbackEvents() {
    return const Stream.empty();
  }

  @override
  Future<Uint8List?> fetchArtwork(String trackId, {required int size}) {
    return Future.value();
  }

  @override
  Future<void> playTrack(String trackId) {
    return Future.value();
  }

  @override
  Future<void> play() {
    return Future.value();
  }

  @override
  Future<void> pause() {
    return Future.value();
  }

  @override
  Future<void> skipToNext() {
    return Future.value();
  }

  @override
  Future<void> skipToPrevious() {
    return Future.value();
  }

  @override
  Future<void> scheduleSnapshotRefresh() {
    return Future.value();
  }

  @override
  Future<void> rescheduleSnapshotRefresh() => Future.value();

  @override
  Future<SnapshotRefreshDiagnostics> snapshotRefreshDiagnostics() async {
    return const SnapshotRefreshDiagnostics.unsupported();
  }

  @override
  Future<String?> exportSnapshotRefreshLogs() async => null;

  @override
  Future<SnapshotSyncResult> syncSnapshotHistory() {
    return Future.value(
      const SnapshotSyncResult(status: SnapshotSyncStatus.unchanged),
    );
  }

  @override
  Future<SnapshotSyncResult> deleteCloudSnapshots({String? olderThanDateKey}) {
    return Future.value(
      const SnapshotSyncResult(status: SnapshotSyncStatus.unchanged),
    );
  }
}

MusicStatsState _libraryState(SnapshotHistory history) {
  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
    overview: LibraryOverview.fromTracks([
      LibraryTrack(
        id: 'library-track',
        title: 'Library Track',
        artist: 'Test Artist',
        albumTitle: 'Test Album',
        duration: const Duration(minutes: 3),
        playCount: 4,
        skipCount: 0,
        lastPlayedAt: DateTime(2026, 7, 9),
        isCloudItem: false,
      ),
    ], isDemo: false),
    snapshotHistory: history,
  );
}
