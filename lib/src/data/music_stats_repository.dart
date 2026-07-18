import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/library_overview.dart';
import '../domain/library_snapshot.dart';
import '../domain/library_track.dart';
import '../domain/music_library_authorization.dart';
import '../domain/music_stats_state.dart';
import '../settings/demo_library_preferences.dart';
import '../settings/library_filter_preferences.dart';
import '../settings/snapshot_preferences.dart';
import 'library_snapshot_repository.dart';
import 'music_library_channel.dart';

const _largeDemoTrackCount = int.fromEnvironment('SONGBRIEF_DEMO_TRACK_COUNT');
const _overviewBuildIsolateTrackThreshold = 700;
const _demoArtworkAssets = [
  'assets/demo_art/skyline_echo.png',
  'assets/demo_art/glass_harbor.png',
  'assets/demo_art/tableau.png',
  'assets/demo_art/subway_light.png',
  'assets/demo_art/late_bloom.png',
  'assets/demo_art/north_line.png',
  'assets/demo_art/signal_blue.png',
  'assets/demo_art/midnight_arcade.png',
];

final musicLibraryClientProvider = Provider<MusicLibraryClient>(
  (ref) => const PlatformMusicLibraryClient(),
);

final musicStatsRepositoryProvider = Provider<MusicStatsRepository>((ref) {
  return MusicStatsRepository(
    ref.watch(musicLibraryClientProvider),
    ref.watch(librarySnapshotRepositoryProvider),
    snapshotRecordingEnabled: ref.watch(snapshotRecordingProvider),
    cloudSyncEnabled: ref.watch(snapshotCloudSyncProvider),
    temporaryDemoLibraryEnabled: ref.watch(temporaryDemoLibraryProvider),
    libraryFilters: ref.watch(libraryFilterPreferencesProvider),
  );
});

class MusicStatsRepository {
  const MusicStatsRepository(
    this._client,
    this._snapshotRepository, {
    this.snapshotRecordingEnabled = true,
    this.cloudSyncEnabled = true,
    this.temporaryDemoLibraryEnabled = false,
    this.libraryFilters,
  });

  final MusicLibraryClient _client;
  final LibrarySnapshotRepository _snapshotRepository;
  final bool snapshotRecordingEnabled;
  final bool cloudSyncEnabled;
  final bool temporaryDemoLibraryEnabled;
  final LibraryFilterPreferences? libraryFilters;

  Future<void> ensureSnapshotRefreshScheduled() async {
    if (!_isIosMusicRuntime) {
      return;
    }
    await _client.scheduleSnapshotRefresh();
  }

  Future<void> rescheduleSnapshotRefresh() async {
    if (!_isIosMusicRuntime) {
      return;
    }
    await _client.rescheduleSnapshotRefresh();
  }

  Future<SnapshotRefreshDiagnostics> snapshotRefreshDiagnostics() async {
    if (!_isIosMusicRuntime) {
      return const SnapshotRefreshDiagnostics.unsupported();
    }
    return _client.snapshotRefreshDiagnostics();
  }

  Future<String?> exportSnapshotRefreshLogs() async {
    if (!_isIosMusicRuntime) {
      return null;
    }
    return _client.exportSnapshotRefreshLogs();
  }

  Future<MusicStatsState> load({bool requestAccess = false}) async {
    if (!_isIosMusicRuntime) {
      return _buildDemoState(MusicLibraryAuthorizationStatus.unsupported);
    }

    final status = requestAccess
        ? await _client.requestAuthorization()
        : await _client.authorizationStatus();

    if (!status.canReadLibrary) {
      if (temporaryDemoLibraryEnabled) {
        return _buildDemoState(status);
      }
      return MusicStatsState(
        authorizationStatus: status,
        overview: LibraryOverview.empty(isDemo: false),
        snapshotHistory: await _snapshotRepository.loadHistory(),
        snapshotRecordingEnabled: snapshotRecordingEnabled,
        lastDataRefreshAt: DateTime.now(),
      );
    }

    final tracks = _filteredTracks(await _client.fetchTracks());
    if (tracks.isEmpty && temporaryDemoLibraryEnabled) {
      return _buildDemoState(status);
    }

    if (snapshotRecordingEnabled) {
      await _client.scheduleSnapshotRefresh();
    }
    final overview = await _buildLibraryOverview(tracks, isDemo: false);
    final snapshotHistory = snapshotRecordingEnabled
        ? await _snapshotRepository.recordSnapshot(
            overview,
            filterSignature: libraryFilters?.snapshotSignature,
          )
        : await _snapshotRepository.loadHistory();
    return MusicStatsState(
      authorizationStatus: status,
      overview: overview,
      snapshotHistory: snapshotHistory,
      snapshotRecordingEnabled: snapshotRecordingEnabled,
      lastDataRefreshAt: DateTime.now(),
    );
  }

  Future<MusicStatsState> _buildDemoState(
    MusicLibraryAuthorizationStatus authorizationStatus,
  ) async {
    final tracks = _largeDemoTrackCount > 0
        ? _largeSampleTracks(_largeDemoTrackCount)
        : _sampleTracks();
    final filteredTracks = _filteredTracks(tracks);
    final overview = await _buildLibraryOverview(filteredTracks, isDemo: true);
    return MusicStatsState(
      authorizationStatus: authorizationStatus,
      overview: overview,
      snapshotHistory: snapshotRecordingEnabled
          ? _sampleSnapshotHistory(overview)
          : SnapshotHistory.empty,
      snapshotRecordingEnabled: snapshotRecordingEnabled,
      lastDataRefreshAt: DateTime.now(),
    );
  }

  Future<Uint8List?> fetchArtwork(String trackId, {int size = 640}) {
    if (!_isIosMusicRuntime) {
      return Future<Uint8List?>.value();
    }
    return _client.fetchArtwork(trackId, size: size);
  }

  Future<bool> openAppSettings() {
    if (!_isIosMusicRuntime) {
      return Future.value(false);
    }
    return _client.openAppSettings();
  }

  Future<MusicPlaybackSnapshot?> currentPlayback() {
    if (!_isIosMusicRuntime) {
      return Future<MusicPlaybackSnapshot?>.value();
    }
    return _client.currentPlayback();
  }

  Stream<MusicPlaybackSnapshot> playbackEvents() {
    if (!_isIosMusicRuntime) {
      return const Stream<MusicPlaybackSnapshot>.empty();
    }
    return _client.playbackEvents();
  }

  Future<void> playTrack(String trackId) {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.playTrack(trackId);
  }

  Future<void> play() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.play();
  }

  Future<void> pause() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.pause();
  }

  Future<void> skipToNext() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.skipToNext();
  }

  Future<void> skipToPrevious() {
    if (!_isIosMusicRuntime) {
      return Future.value();
    }
    return _client.skipToPrevious();
  }

  Future<SnapshotHistory> recordSnapshot(LibraryOverview overview) {
    if (!snapshotRecordingEnabled) {
      return _snapshotRepository.loadHistory();
    }
    if (!_isIosMusicRuntime || overview.isDemo) {
      return Future.value(SnapshotHistory.empty);
    }
    return _snapshotRepository.recordSnapshot(
      overview,
      filterSignature: libraryFilters?.snapshotSignature,
    );
  }

  Future<SnapshotHistory> deleteSnapshotsOlderThan(DateTime cutoff) async {
    await _propagateCloudDeletion(olderThanDateKey: snapshotDateKey(cutoff));
    final history = await _snapshotRepository.deleteSnapshotsOlderThan(cutoff);
    return history;
  }

  Future<SnapshotHistory> clearSnapshotHistory() async {
    await _propagateCloudDeletion();
    final history = await _snapshotRepository.clearHistory();
    return history;
  }

  bool get canSyncCloudSnapshots =>
      _isIosMusicRuntime && snapshotRecordingEnabled && cloudSyncEnabled;

  /// Merges local and iCloud snapshot histories. Returns null when cloud
  /// sync does not apply to this runtime or configuration.
  Future<SnapshotSyncResult?> syncCloudSnapshots() async {
    if (!canSyncCloudSnapshots) {
      return null;
    }
    try {
      return await _client.syncSnapshotHistory();
    } on Object {
      return const SnapshotSyncResult(status: SnapshotSyncStatus.error);
    }
  }

  Future<SnapshotHistory> loadSnapshotHistory() {
    return _snapshotRepository.loadHistory();
  }

  Future<void> _propagateCloudDeletion({String? olderThanDateKey}) async {
    if (!_isIosMusicRuntime) {
      return;
    }
    final result = await _client.deleteCloudSnapshots(
      olderThanDateKey: olderThanDateKey,
    );
    if (!result.deletionCompleted) {
      throw SnapshotCloudDeletionException(result.status);
    }
  }

  List<LibraryTrack> _filteredTracks(List<LibraryTrack> tracks) {
    return libraryFilters?.apply(tracks) ?? tracks;
  }

  List<LibraryTrack> _sampleTracks() {
    final now = DateTime.now();
    return [
      LibraryTrack(
        id: 'demo-1',
        title: 'Skyline Echo',
        artist: 'Nami Arata',
        albumTitle: 'Night Transit',
        genre: 'Electronic',
        artworkAsset: 'assets/demo_art/skyline_echo.png',
        releaseDate: DateTime(2021, 5, 14),
        duration: const Duration(minutes: 4, seconds: 12),
        playCount: 184,
        skipCount: 3,
        lastPlayedAt: now.subtract(const Duration(hours: 3)),
        lyrics:
            'City lights are waking slow\n'
            'Footsteps keep the meter low\n'
            'Every window hums along\n'
            'To the skyline echo song',
        playlistNames: const ['Late Night Focus', 'Recently Played'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-2',
        title: 'Glass Harbor',
        artist: 'Nami Arata',
        albumTitle: 'Night Transit',
        genre: 'Electronic',
        artworkAsset: 'assets/demo_art/glass_harbor.png',
        releaseDate: DateTime(2021, 5, 14),
        duration: const Duration(minutes: 3, seconds: 45),
        playCount: 162,
        skipCount: 8,
        lastPlayedAt: now.subtract(const Duration(days: 1, hours: 2)),
        playlistNames: const ['Late Night Focus', 'Harbor Walk'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-3',
        title: 'Tableau',
        artist: 'The Pale Keys',
        albumTitle: 'Still Frames',
        genre: 'Indie Rock',
        artworkAsset: 'assets/demo_art/tableau.png',
        releaseDate: DateTime(2018, 10, 2),
        duration: const Duration(minutes: 5, seconds: 6),
        playCount: 147,
        skipCount: 11,
        lastPlayedAt: now.subtract(const Duration(days: 2)),
        lyrics:
            'Hold the frame and let it breathe\n'
            'Quiet colors underneath\n'
            'Nothing moves and nothing stays',
        playlistNames: const ['Recently Played', 'Studio Notes'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-4',
        title: 'Subway Light',
        artist: 'The Pale Keys',
        albumTitle: 'Still Frames',
        genre: 'Indie Rock',
        artworkAsset: 'assets/demo_art/subway_light.png',
        releaseDate: DateTime(2018, 10, 2),
        duration: const Duration(minutes: 3, seconds: 28),
        playCount: 121,
        skipCount: 40,
        lastPlayedAt: now.subtract(const Duration(days: 4)),
        playlistNames: const ['City Pop Tests'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-5',
        title: 'Late Bloom',
        artist: 'Mika Seno',
        albumTitle: 'Small Signals',
        genre: 'Pop',
        artworkAsset: 'assets/demo_art/late_bloom.png',
        releaseDate: DateTime(2024, 2, 9),
        duration: const Duration(minutes: 4, seconds: 2),
        playCount: 116,
        skipCount: 5,
        lastPlayedAt: now.subtract(const Duration(days: 118)),
        lyrics:
            'Small signals find their way\n'
            'Through the ordinary day',
        playlistNames: const ['Morning Rotation'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-6',
        title: 'North Line',
        artist: 'Mika Seno',
        albumTitle: 'Small Signals',
        genre: 'Pop',
        artworkAsset: 'assets/demo_art/north_line.png',
        releaseDate: DateTime(2024, 2, 9),
        duration: const Duration(minutes: 2, seconds: 58),
        playCount: 96,
        skipCount: 1,
        lastPlayedAt: now.subtract(const Duration(days: 9)),
        playlistNames: const ['Morning Rotation', 'Train Window'],
        isCloudItem: false,
      ),
      LibraryTrack(
        id: 'demo-7',
        title: 'Signal Blue',
        artist: 'Kite Room',
        albumTitle: 'Afterimage',
        genre: 'Ambient',
        artworkAsset: 'assets/demo_art/signal_blue.png',
        releaseDate: DateTime(2015, 7, 24),
        duration: const Duration(minutes: 6, seconds: 18),
        playCount: 78,
        skipCount: 0,
        lastPlayedAt: now.subtract(const Duration(days: 142)),
        playlistNames: const ['Train Window'],
        isCloudItem: false,
      ),
    ];
  }

  List<LibraryTrack> _largeSampleTracks(int count) {
    final safeCount = count < 1 ? 1 : count;
    final now = DateTime.now();
    final artists = safeCount < 20 ? safeCount : safeCount ~/ 20;
    final albums = safeCount < 10 ? safeCount : safeCount ~/ 10;
    const genres = [
      'Electronic',
      'Indie Rock',
      'Pop',
      'Ambient',
      'Jazz',
      'Classical',
      'Hip-Hop',
      'Soundtrack',
      'Folk',
      'Metal',
    ];

    return List.generate(safeCount, (index) {
      final artistIndex = index % artists;
      final albumIndex = index % albums;
      final genre = genres[index % genres.length];
      final playCount = (safeCount - index) % 400 + (index % 17);
      final skipCount = index % 31;
      final playlistBase = index % 1000;
      return LibraryTrack(
        id: 'large-demo-$index',
        title: 'Demo Track ${index.toString().padLeft(5, '0')}',
        artist: 'Demo Artist ${artistIndex.toString().padLeft(4, '0')}',
        albumTitle: 'Demo Album ${albumIndex.toString().padLeft(4, '0')}',
        albumArtist: 'Demo Artist ${artistIndex.toString().padLeft(4, '0')}',
        genre: genre,
        artworkAsset: _demoArtworkAssets[index % _demoArtworkAssets.length],
        releaseDate: DateTime(1975 + index % 50, index % 12 + 1, 1),
        duration: Duration(minutes: 2 + index % 5, seconds: index % 60),
        playCount: playCount,
        skipCount: skipCount,
        lastPlayedAt: index % 5 == 0
            ? null
            : now.subtract(Duration(hours: index % 720)),
        playlistNames: [
          'Playlist ${playlistBase.toString().padLeft(4, '0')}',
          'Mood ${(playlistBase % 80).toString().padLeft(2, '0')}',
          if (index % 3 == 0)
            'Rotation ${(playlistBase % 40).toString().padLeft(2, '0')}',
        ],
        isCloudItem: index % 7 == 0,
      );
    }, growable: false);
  }

  SnapshotHistory _sampleSnapshotHistory(LibraryOverview overview) {
    const snapshotDays = 90;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day, 6);
    var history = SnapshotHistory.empty;

    for (var snapshotIndex = 0; snapshotIndex < snapshotDays; snapshotIndex++) {
      final day = todayStart.subtract(
        Duration(days: snapshotDays - 1 - snapshotIndex),
      );
      final tracks = List<LibraryTrack>.generate(overview.tracks.length, (
        trackIndex,
      ) {
        final track = overview.tracks[trackIndex];
        return track.copyWith(
          playCount: _demoCounterAtSnapshot(
            current: track.playCount,
            deltas: _demoPlayDeltas(
              trackIndex: trackIndex,
              current: track.playCount,
              days: snapshotDays,
            ),
            snapshotIndex: snapshotIndex,
          ),
          skipCount: _demoCounterAtSnapshot(
            current: track.skipCount,
            deltas: _demoSkipDeltas(
              trackIndex: trackIndex,
              current: track.skipCount,
              days: snapshotDays,
            ),
            snapshotIndex: snapshotIndex,
          ),
          lastPlayedAt: track.lastPlayedAt,
        );
      }, growable: false);
      history = history.withSnapshot(
        DailyLibrarySnapshot.fromOverview(
          LibraryOverview.fromTracks(tracks, isDemo: true),
          capturedAt: day,
          source: 'demo',
        ),
      );
    }

    return history;
  }

  int _demoCounterAtSnapshot({
    required int current,
    required List<int> deltas,
    required int snapshotIndex,
  }) {
    var remaining = 0;
    for (var index = snapshotIndex; index < deltas.length; index++) {
      remaining += deltas[index];
    }
    final value = current - remaining;
    return value < 0 ? 0 : value;
  }

  List<int> _demoPlayDeltas({
    required int trackIndex,
    required int current,
    required int days,
  }) {
    if (days <= 1 || current <= 0) {
      return const <int>[];
    }
    final raw = List<int>.generate(days - 1, (dayIndex) {
      final weekdayPulse = dayIndex % 7 == 5 || dayIndex % 7 == 6 ? 1 : 0;
      final releasePush = trackIndex % 9 == 0 && dayIndex > days - 28 ? 2 : 0;
      final rediscoveryWave =
          trackIndex % 11 == 4 && dayIndex > 16 && dayIndex < 36 ? 2 : 0;
      final steadyFavorite = trackIndex < 8 && (dayIndex + trackIndex) % 3 == 0
          ? 1
          : 0;
      final longTail = trackIndex >= 8 && (dayIndex + trackIndex) % 17 == 0
          ? 1
          : 0;
      return weekdayPulse +
          releasePush +
          rediscoveryWave +
          steadyFavorite +
          longTail;
    });
    return _fitDeltasToCurrent(raw, current);
  }

  List<int> _demoSkipDeltas({
    required int trackIndex,
    required int current,
    required int days,
  }) {
    if (days <= 1 || current <= 0) {
      return const <int>[];
    }
    final raw = List<int>.generate(days - 1, (dayIndex) {
      if (trackIndex % 13 == 3 && dayIndex % 9 == 0) {
        return 2;
      }
      if (trackIndex % 5 == 1 && dayIndex % 14 == 0) {
        return 1;
      }
      return 0;
    });
    return _fitDeltasToCurrent(raw, current);
  }

  List<int> _fitDeltasToCurrent(List<int> raw, int current) {
    final total = raw.fold<int>(0, (sum, value) => sum + value);
    if (total <= current) {
      return raw;
    }
    var remaining = current;
    final fitted = <int>[];
    for (final value in raw) {
      if (remaining <= 0) {
        fitted.add(0);
      } else if (value <= remaining) {
        fitted.add(value);
        remaining -= value;
      } else {
        fitted.add(remaining);
        remaining = 0;
      }
    }
    return List<int>.unmodifiable(fitted);
  }
}

class SnapshotCloudDeletionException implements Exception {
  const SnapshotCloudDeletionException(this.status);

  final SnapshotSyncStatus status;

  @override
  String toString() => 'Snapshot cloud deletion failed: ${status.name}';
}

bool get _isIosMusicRuntime {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

Future<LibraryOverview> _buildLibraryOverview(
  List<LibraryTrack> tracks, {
  required bool isDemo,
}) {
  if (tracks.length < _overviewBuildIsolateTrackThreshold) {
    return Future.value(LibraryOverview.fromTracks(tracks, isDemo: isDemo));
  }
  return compute(
    _buildLibraryOverviewInIsolate,
    _LibraryOverviewBuildInput(tracks: tracks, isDemo: isDemo),
  );
}

LibraryOverview _buildLibraryOverviewInIsolate(
  _LibraryOverviewBuildInput input,
) {
  return LibraryOverview.fromTracks(input.tracks, isDemo: input.isDemo);
}

class _LibraryOverviewBuildInput {
  const _LibraryOverviewBuildInput({
    required this.tracks,
    required this.isDemo,
  });

  final List<LibraryTrack> tracks;
  final bool isDemo;
}
