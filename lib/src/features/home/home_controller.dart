import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/app_analytics.dart';
import '../../data/music_stats_repository.dart';
import '../../data/music_library_channel.dart';
import '../../domain/library_overview.dart';
import '../../domain/library_snapshot.dart';
import '../../domain/library_track.dart';
import '../../domain/music_stats_state.dart';
import '../../settings/music_data_preferences.dart';
import '../../settings/library_filter_preferences.dart';
import '../../settings/music_data_preferences_storage.dart';
import '../../settings/supplemental_history_preferences.dart';
import '../../widgets/home_widget_bridge.dart';
import 'supplemental_history_controller.dart';

enum TrendRange { week, month, year }

class RankingFocus {
  const RankingFocus.track(this.trackId)
    : scope = RankingScope.tracks,
      title = null;

  const RankingFocus.entry({required this.scope, required this.title})
    : trackId = null;

  final RankingScope scope;
  final String? trackId;
  final String? title;
}

enum HomeSection { playing, overview, rankings, library, settings }

/// CI App Store screenshot builds open on a chosen tab and present the demo
/// library as a regular Music library; compiled out otherwise.
const screenshotModeEnabled = bool.fromEnvironment(
  'SONGBRIEF_SCREENSHOT_MODE',
);
const screenshotSectionPreferenceKey = 'songbrief_screenshot_section';

final homeSectionProvider =
    NotifierProvider<HomeSectionController, HomeSection>(
      HomeSectionController.new,
    );

class HomeSectionController extends Notifier<HomeSection> {
  @override
  HomeSection build() {
    if (screenshotModeEnabled) {
      final name = ref
          .read(musicDataSharedPreferencesProvider)
          ?.getString(screenshotSectionPreferenceKey);
      for (final section in HomeSection.values) {
        if (section.name == name) {
          return section;
        }
      }
    }
    return HomeSection.playing;
  }

  void setSection(HomeSection section) {
    if (state == section) {
      return;
    }
    state = section;
    unawaited(
      ref.read(appAnalyticsProvider).logScreenView('home_${section.name}'),
    );
  }
}

final rankingScopeProvider =
    NotifierProvider<RankingScopeController, RankingScope>(
      RankingScopeController.new,
    );

final rankingFocusProvider =
    NotifierProvider<RankingFocusController, RankingFocus?>(
      RankingFocusController.new,
    );

final rankingVisibleCountProvider =
    NotifierProvider<RankingVisibleCountController, Map<RankingScope, int>>(
      RankingVisibleCountController.new,
    );

final snapshotSyncStateProvider =
    NotifierProvider<SnapshotSyncStateController, SnapshotSyncState>(
      SnapshotSyncStateController.new,
    );

/// True while a library refresh runs; the previous stats stay on screen.
final statsRefreshInFlightProvider =
    NotifierProvider<StatsRefreshInFlightController, bool>(
      StatsRefreshInFlightController.new,
    );

final snapshotRefreshDiagnosticsProvider =
    FutureProvider.autoDispose<SnapshotRefreshDiagnostics>((ref) {
      return ref
          .watch(musicStatsRepositoryProvider)
          .snapshotRefreshDiagnostics();
    });

class SnapshotSyncState {
  const SnapshotSyncState({
    this.isSyncing = false,
    this.lastAttemptAt,
    this.result,
  });

  final bool isSyncing;
  final DateTime? lastAttemptAt;
  final SnapshotSyncResult? result;
}

class SnapshotSyncStateController extends Notifier<SnapshotSyncState> {
  @override
  SnapshotSyncState build() => const SnapshotSyncState();

  void begin() {
    state = SnapshotSyncState(
      isSyncing: true,
      lastAttemptAt: state.lastAttemptAt,
      result: state.result,
    );
  }

  void complete(SnapshotSyncResult result) {
    state = SnapshotSyncState(lastAttemptAt: DateTime.now(), result: result);
  }

  void unavailable() {
    complete(const SnapshotSyncResult(status: SnapshotSyncStatus.disabled));
  }
}

class StatsRefreshInFlightController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    state = value;
  }
}

class RankingScopeController extends Notifier<RankingScope> {
  @override
  RankingScope build() {
    return RankingScope.tracks;
  }

  void setScope(RankingScope scope) {
    state = scope;
  }
}

class RankingFocusController extends Notifier<RankingFocus?> {
  @override
  RankingFocus? build() {
    return null;
  }

  void focus(RankingFocus focus) {
    state = focus;
  }

  void clear() {
    state = null;
  }
}

class RankingVisibleCountController extends Notifier<Map<RankingScope, int>> {
  static const initialCount = 12;
  static const loadMoreCount = 12;

  @override
  Map<RankingScope, int> build() {
    return {for (final scope in RankingScope.values) scope: initialCount};
  }

  int countFor(RankingScope scope) {
    return state[scope] ?? initialCount;
  }

  void loadMore(RankingScope scope, int totalCount) {
    final current = countFor(scope);
    state = {
      ...state,
      scope: _clamp(current + loadMoreCount, initialCount, totalCount),
    };
  }

  void reset(RankingScope scope) {
    state = {...state, scope: initialCount};
  }

  int _clamp(int value, int minimum, int maximum) {
    if (value < minimum) {
      return minimum;
    }
    if (value > maximum) {
      return maximum;
    }
    return value;
  }
}

final musicStatsControllerProvider =
    AsyncNotifierProvider<MusicStatsController, MusicStatsState>(
      MusicStatsController.new,
    );

final trackArtworkProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, trackId) {
      final cacheLink = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer = Timer(const Duration(minutes: 2), cacheLink.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      ref.onDispose(() {
        disposeTimer?.cancel();
      });
      // Read the repository: it is rebuilt whenever preferences such as
      // exclusion rules change, which must not discard cached artwork.
      return ref.read(musicStatsRepositoryProvider).fetchArtwork(trackId);
    });

// Lyrics are fetched on demand because reading them for the whole library is slow.
final trackLyricsProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, trackId) {
      // Cache missing lyrics too: cloud-only songs commonly have no local
      // lyrics, and returning to the player should not repeat a library query.
      final cacheLink = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer = Timer(const Duration(minutes: 2), cacheLink.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      ref.onDispose(() => disposeTimer?.cancel());
      return ref.read(musicStatsRepositoryProvider).fetchLyrics(trackId);
    });

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);

/// Playback notifications carry no updated library counters. Give Music time
/// to persist them, then read the library once for a burst of track changes.
final foregroundLibraryRefreshProvider = Provider<ForegroundLibraryRefresh>((
  ref,
) {
  final refresh = ForegroundLibraryRefresh(() {
    final stats = ref.read(musicStatsControllerProvider).asData?.value;
    if (stats == null || stats.isDemo) return;
    unawaited(
      ref.read(musicStatsControllerProvider.notifier).refreshStatsSilently(),
    );
  });
  ref.listen(playbackControllerProvider, (previous, next) {
    if (previous == null ||
        previous.activeTrackId == null ||
        previous.activeTrackId == next.activeTrackId) {
      return;
    }
    refresh.trackChanged();
  });
  ref.onDispose(refresh.dispose);
  return refresh;
});

class ForegroundLibraryRefresh {
  ForegroundLibraryRefresh(this._refresh);

  final void Function() _refresh;
  Timer? _timer;
  bool _foreground = false;

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void trackChanged() {
    if (!_foreground || _timer != null) return;
    // Keep the first deadline so rapid skipping cannot postpone it forever.
    _timer = Timer(const Duration(seconds: 15), () {
      _timer = null;
      if (_foreground) _refresh();
    });
  }

  void dispose() => setForeground(false);
}

class PlaybackState {
  const PlaybackState({
    this.activeTrackId,
    this.nowPlaying,
    this.isPlaying = false,
    this.isBusy = false,
    this.errorMessage,
  });

  final String? activeTrackId;

  /// The player's description of the current song, used when the song is not
  /// in the library (for example, streamed from an Apple Music playlist).
  final LibraryTrack? nowPlaying;
  final bool isPlaying;
  final bool isBusy;
  final String? errorMessage;

  bool get hasActiveTrack => activeTrackId != null;

  bool isTrackActive(String trackId, {LibraryTrack? track}) =>
      activeTrackId == trackId ||
      (track != null &&
          nowPlaying != null &&
          track.artist.trim().toLowerCase() ==
              nowPlaying!.artist.trim().toLowerCase() &&
          track.title.trim().toLowerCase() ==
              nowPlaying!.title.trim().toLowerCase());

  bool isTrackPlaying(String trackId, {LibraryTrack? track}) =>
      isPlaying && isTrackActive(trackId, track: track);

  PlaybackState copyWith({
    String? activeTrackId,
    bool keepActiveTrack = true,
    bool? isPlaying,
    bool? isBusy,
    String? errorMessage,
  }) {
    return PlaybackState(
      activeTrackId: keepActiveTrack
          ? activeTrackId ?? this.activeTrackId
          : activeTrackId,
      nowPlaying: keepActiveTrack ? nowPlaying : null,
      isPlaying: isPlaying ?? this.isPlaying,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: errorMessage,
    );
  }
}

class MusicStatsController extends AsyncNotifier<MusicStatsState> {
  Future<void>? _refreshInFlight;
  Future<void> _snapshotHistoryOperationTail = Future<void>.value();

  @override
  Future<MusicStatsState> build() async {
    final loadingPreviewDelay = _startupLoadingPreviewDelay();
    ref.watch(musicStatsRepositoryProvider);
    await ref.watch(musicDataPreferencesReadyProvider.future);
    final next = await _runSnapshotHistoryOperation(
      () => ref.read(musicStatsRepositoryProvider).load(),
    );
    if (loadingPreviewDelay > Duration.zero) {
      await Future<void>.delayed(loadingPreviewDelay);
    }
    if (!next.overview.isDemo) {
      unawaited(HomeWidgetBridge.update(next.snapshotHistory));
      unawaited(syncCloudSnapshots());
    }
    _refreshRecentHistory(next);
    return next;
  }

  void _refreshRecentHistory(MusicStatsState next) {
    if (!next.isDemo && next.authorizationStatus.canReadLibrary) {
      unawaited(ref.read(recentAppleMusicPlaysProvider.notifier).refresh());
    }
  }

  /// Merges the local history with iCloud in the background and refreshes
  /// the visible history when other devices contributed records.
  Future<void> syncCloudSnapshots() {
    return _runSnapshotHistoryOperation(() async {
      ref.read(snapshotSyncStateProvider.notifier).begin();
      final repository = ref.read(musicStatsRepositoryProvider);
      final result = await repository.syncCloudSnapshots();
      if (result == null) {
        ref.read(snapshotSyncStateProvider.notifier).unavailable();
        return;
      }
      ref.read(snapshotSyncStateProvider.notifier).complete(result);
      if (!result.changedLocally) {
        return;
      }
      final history = await repository.loadSnapshotHistory();
      _replaceSnapshotHistory(history);
      unawaited(HomeWidgetBridge.update(history));
    });
  }

  Future<void> rescheduleSnapshotRefresh() async {
    await ref.read(musicStatsRepositoryProvider).rescheduleSnapshotRefresh();
    ref.invalidate(snapshotRefreshDiagnosticsProvider);
  }

  Future<void> ensureSnapshotRefreshScheduled() async {
    await ref
        .read(musicStatsRepositoryProvider)
        .ensureSnapshotRefreshScheduled();
    ref.invalidate(snapshotRefreshDiagnosticsProvider);
  }

  Future<String?> exportSnapshotRefreshLogs() {
    return ref.read(musicStatsRepositoryProvider).exportSnapshotRefreshLogs();
  }

  Future<void> requestAccess() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _runSnapshotHistoryOperation(
        () => ref.read(musicStatsRepositoryProvider).load(requestAccess: true),
      ),
    );
    if (state.hasValue) {
      _refreshRecentHistory(state.requireValue);
      unawaited(ref.read(appAnalyticsProvider).logEvent('music_access_loaded'));
      if (!state.requireValue.overview.isDemo) {
        unawaited(HomeWidgetBridge.update(state.requireValue.snapshotHistory));
        unawaited(syncCloudSnapshots());
      }
      await ref.read(playbackControllerProvider.notifier).syncWithPlayer();
    }
  }

  Future<bool> openMusicSettings() {
    return ref.read(musicStatsRepositoryProvider).openAppSettings();
  }

  Future<void> refreshStats() {
    return _refreshStats(showLoading: true);
  }

  Future<void> refreshStatsSilently() {
    return _refreshStats(showLoading: false);
  }

  Future<void> _refreshStats({required bool showLoading}) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final mode = showLoading ? 'manual' : 'silent';
    unawaited(
      ref
          .read(appAnalyticsProvider)
          .logEvent('library_refresh', parameters: {'mode': mode}),
    );
    final inFlightIndicator = ref.read(statsRefreshInFlightProvider.notifier)
      ..set(true);
    late final Future<void> operation;
    operation = _load(showLoading: showLoading).whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
        if (ref.mounted) {
          inFlightIndicator.set(false);
        }
      }
    });
    _refreshInFlight = operation;
    return operation;
  }

  Future<SnapshotHistory?> deleteSnapshotsOlderThan(DateTime cutoff) async {
    _ensureMutableSnapshotHistory();
    return _runSnapshotHistoryOperation(() async {
      final history = await ref
          .read(musicStatsRepositoryProvider)
          .deleteSnapshotsOlderThan(cutoff);
      _replaceSnapshotHistory(history);
      await HomeWidgetBridge.update(history);
      return history;
    });
  }

  Future<SnapshotHistory?> clearSnapshotHistory() async {
    _ensureMutableSnapshotHistory();
    return _runSnapshotHistoryOperation(() async {
      final history = await ref
          .read(musicStatsRepositoryProvider)
          .clearSnapshotHistory();
      _replaceSnapshotHistory(history);
      await HomeWidgetBridge.update(history);
      return history;
    });
  }

  Future<T> _runSnapshotHistoryOperation<T>(Future<T> Function() operation) {
    final previous = _snapshotHistoryOperationTail;
    final completion = Completer<void>();
    _snapshotHistoryOperationTail = completion.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        completion.complete();
      }
    }();
  }

  void _replaceSnapshotHistory(SnapshotHistory history) {
    if (!ref.mounted) {
      return;
    }
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.withSnapshotHistory(history));
  }

  void _ensureMutableSnapshotHistory() {
    final current = state.asData?.value;
    if (current == null || current.overview.isDemo) {
      throw StateError('Demo listening records cannot modify saved history.');
    }
  }

  Future<void> _load({required bool showLoading}) async {
    final previous = state.asData?.value;
    if (showLoading) {
      state = const AsyncLoading();
    }
    final next = await AsyncValue.guard(
      () => _runSnapshotHistoryOperation(
        () => ref.read(musicStatsRepositoryProvider).load(),
      ),
    );
    state = switch (next) {
      AsyncData() => next,
      AsyncError() when !showLoading && previous != null => AsyncData(previous),
      _ => next,
    };
    if (state.hasValue) {
      _refreshRecentHistory(state.requireValue);
      final overview = state.requireValue.overview;
      if (!overview.isDemo) {
        unawaited(HomeWidgetBridge.update(state.requireValue.snapshotHistory));
      }
      unawaited(
        ref
            .read(appAnalyticsProvider)
            .logEvent(
              'library_refresh_completed',
              parameters: {
                'mode': showLoading ? 'manual' : 'silent',
                'source': overview.isDemo ? 'demo' : 'music_library',
                'track_count': overview.totalTracks,
                'artist_count': overview.totalArtists,
                'album_count': overview.totalAlbums,
              },
            ),
      );
      unawaited(ref.read(playbackControllerProvider.notifier).syncWithPlayer());
      if (!overview.isDemo) {
        unawaited(syncCloudSnapshots());
      }
    } else if (next.hasError) {
      unawaited(
        ref
            .read(appAnalyticsProvider)
            .logEvent(
              'library_refresh_failed',
              parameters: {'mode': showLoading ? 'manual' : 'silent'},
            ),
      );
    }
  }
}

Duration _startupLoadingPreviewDelay() {
  if (!Uri.base.queryParameters.containsKey('loading_preview')) {
    return Duration.zero;
  }
  return const Duration(seconds: 4);
}

const outsideLibraryPlaysPreferenceKey = 'songbrief_outside_library_plays_v1';
const _maxOutsideLibraryPlays = 50;

final outsideLibraryPlaysProvider =
    NotifierProvider<OutsideLibraryPlaysController, List<LibraryTrack>>(
      OutsideLibraryPlaysController.new,
    );

final visibleOutsideLibraryPlaysProvider = Provider<List<LibraryTrack>>((ref) {
  if (!ref.watch(supplementalHistoryIncludedProvider)) return const [];
  final observed = ref.watch(outsideLibraryPlaysProvider);
  final recent = ref.watch(recentAppleMusicPlaysProvider);
  final countedTracks = ref.watch(supplementalHistoryProvider).tracks;
  // Prefer the latest real timestamp; undated service rows retain API order.
  final candidates = [...observed, ...recent, ...countedTracks].indexed.toList()
    ..sort((a, b) {
      final aTime = a.$2.lastPlayedAt;
      final bTime = b.$2.lastPlayedAt;
      if (aTime == null && bTime == null) return a.$1.compareTo(b.$1);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final comparison = bTime.compareTo(aTime);
      return comparison == 0 ? a.$1.compareTo(b.$1) : comparison;
    });
  final plays = uniqueHistoryTracks(candidates.map((entry) => entry.$2));
  final filters = ref.watch(libraryFilterPreferencesProvider);
  final repository = ref.watch(musicStatsRepositoryProvider);
  final counted = LibraryTrackCatalog()
    ..replace(countedTracks);
  // Re-evaluate cached membership after a library refresh, too.
  ref.watch(musicStatsControllerProvider);
  return List.unmodifiable(
    plays.where(
      (track) =>
          repository.libraryTrackMatching(track) == null &&
          !filters.excludes(track),
    ).map((track) {
      final count = counted.match(track)?.playCount ?? 0;
      return track.copyWith(playCount: count);
    }),
  );
});

/// Supplemental Apple Music history is isolated from counters and snapshots.
const recentAppleMusicPlaysPreferenceKey = 'songbrief_apple_music_recent_v1';

final recentAppleMusicPlaysProvider =
    NotifierProvider<RecentAppleMusicPlaysController, List<LibraryTrack>>(
      RecentAppleMusicPlaysController.new,
    );

class RecentAppleMusicPlaysController extends Notifier<List<LibraryTrack>> {
  Future<void>? _inFlight;
  DateTime? _lastAttempt;

  /// Diagnostic only; supplemental failures never replace the library state.
  Object? lastError;
  DateTime? get lastAttemptAt => _lastAttempt;

  @override
  List<LibraryTrack> build() {
    final raw = ref
        .read(musicDataSharedPreferencesProvider)
        ?.getString(recentAppleMusicPlaysPreferenceKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return _dedupe(
        decoded.whereType<Map<String, Object?>>().map(
          (json) => LibraryTrack.fromPlatformMap(json),
        ),
      );
    } on Object {
      return const [];
    }
  }

  Future<void> refresh() {
    if (_inFlight case final pending?) return pending;
    final now = DateTime.now();
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) < const Duration(minutes: 1)) {
      return Future.value();
    }
    _lastAttempt = now;
    final repository = ref.read(musicStatsRepositoryProvider);
    return _inFlight = () async {
      try {
        final tracks = await repository.fetchRecentlyPlayedTracks();
        if (!ref.mounted) return;
        lastError = null;
        state = _dedupe(tracks);
        ref.read(supplementalHistoryProvider.notifier).ingest(state);
        await ref
            .read(musicDataSharedPreferencesProvider)
            ?.setString(
              recentAppleMusicPlaysPreferenceKey,
              jsonEncode(
                state
                    .map(
                      (track) => {
                        'id': track.id,
                        'title': track.title,
                        'artist': track.artist,
                        'albumTitle': track.albumTitle,
                        'genre': track.genre,
                        'appleMusicStoreId': track.appleMusicStoreId,
                        'appleMusicUrl': track.appleMusicUrl,
                        'durationSeconds': track.duration.inSeconds,
                        'lastPlayedAtMillis':
                            track.lastPlayedAt?.millisecondsSinceEpoch,
                        'isCloudItem': true,
                      },
                    )
                    .toList(),
              ),
            );
      } on Object catch (error) {
        lastError = error;
        // Offline, denied, or unavailable: preserve independently cached history.
      } finally {
        _inFlight = null;
      }
    }();
  }

  static List<LibraryTrack> _dedupe(Iterable<LibraryTrack> tracks) {
    final result = <LibraryTrack>[];
    for (final track in tracks) {
      if (!result.any((existing) => sameHistoryTrack(existing, track))) {
        result.add(track.copyWith(playCount: 0, skipCount: 0));
      }
      if (result.length == 500) break;
    }
    return List.unmodifiable(result);
  }
}

/// Songs observed playing while the app was open, retained separately from
/// Apple Music's supplemental history and all library statistics.
class OutsideLibraryPlaysController extends Notifier<List<LibraryTrack>> {
  @override
  List<LibraryTrack> build() {
    final raw = ref
        .read(musicDataSharedPreferencesProvider)
        ?.getString(outsideLibraryPlaysPreferenceKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return List.unmodifiable(
        decoded.whereType<Map<String, Object?>>().map(_fromJson).nonNulls,
      );
    } on FormatException {
      return const [];
    }
  }

  /// Records [track] as played now; a repeat of the latest entry only moves
  /// its time forward.
  void record(LibraryTrack track, {DateTime? at}) {
    final playedAt = at ?? DateTime.now();
    // Seeing a song proves a minimum of one play, not a distinct MusicKit
    // timestamped event. Polls and pause/resume must not add playback events.
    ref.read(supplementalHistoryProvider.notifier).observe(track, at: playedAt);
    final entry = track.copyWith(lastPlayedAt: playedAt);
    final rest = state.isNotEmpty && state.first.id == track.id
        ? state.skip(1)
        : state;
    state = List.unmodifiable([entry, ...rest].take(_maxOutsideLibraryPlays));
    unawaited(
      ref
              .read(musicDataSharedPreferencesProvider)
              ?.setString(
                outsideLibraryPlaysPreferenceKey,
                jsonEncode(state.map(_toJson).toList()),
              ) ??
          Future<bool>.value(false),
    );
  }

  static Map<String, Object?> _toJson(LibraryTrack track) => {
    'id': track.id,
    'title': track.title,
    'artist': track.artist,
    'albumTitle': track.albumTitle,
    'appleMusicStoreId': track.appleMusicStoreId,
    'appleMusicUrl': track.appleMusicUrl,
    'genre': track.genre,
    'playlistNames': track.playlistNames,
    'durationSeconds': track.duration.inSeconds,
    'playedAtMillis': track.lastPlayedAt?.millisecondsSinceEpoch,
  };

  static LibraryTrack? _fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final playedAt = json['playedAtMillis'];
    if (id is! String || title is! String || playedAt is! int) return null;
    final artist = json['artist'];
    final album = json['albumTitle'];
    final duration = json['durationSeconds'];
    return LibraryTrack(
      id: id,
      title: title,
      artist: artist is String ? artist : 'Unknown Artist',
      albumTitle: album is String ? album : 'Unknown Album',
      appleMusicStoreId: json['appleMusicStoreId'] is String
          ? json['appleMusicStoreId'] as String : null,
      appleMusicUrl: json['appleMusicUrl'] is String
          ? json['appleMusicUrl'] as String : null,
      genre: json['genre'] is String ? json['genre'] as String : null,
      playlistNames:
          (json['playlistNames'] as List?)?.whereType<String>().toList() ??
          const [],
      duration: Duration(seconds: duration is int ? duration : 0),
      playCount: 0,
      skipCount: 0,
      isCloudItem: true,
      lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(playedAt),
    );
  }
}

class PlaybackController extends Notifier<PlaybackState> {
  @override
  PlaybackState build() {
    final subscription = ref
        .watch(musicStatsRepositoryProvider)
        .playbackEvents()
        .listen(
          _applyExternalPlayback,
          onError: (Object error) {
            state = state.copyWith(
              isBusy: false,
              errorMessage: error.toString(),
            );
          },
        );
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
    unawaited(syncWithPlayer());
    return const PlaybackState();
  }

  Future<void> playTrack(String trackId) {
    return _startTrack(trackId, analyticsAction: 'play_track');
  }

  Future<void> restartTrack(String trackId) {
    return _startTrack(trackId, analyticsAction: 'restart_track');
  }

  Future<void> _startTrack(
    String trackId, {
    required String analyticsAction,
  }) async {
    final previous = state;
    state = PlaybackState(activeTrackId: trackId, isBusy: true);
    try {
      await ref.read(musicStatsRepositoryProvider).playTrack(trackId);
      state = PlaybackState(activeTrackId: trackId, isPlaying: true);
      unawaited(
        ref
            .read(appAnalyticsProvider)
            .logEvent(
              'playback_control',
              parameters: {'action': analyticsAction},
            ),
      );
    } on Object catch (error) {
      state = previous.copyWith(isBusy: false, errorMessage: error.toString());
    }
  }

  Future<void> toggleTrack(String trackId) {
    final overview = ref.exists(musicStatsControllerProvider)
        ? ref.read(musicStatsControllerProvider).asData?.value.overview
        : null;
    final track = overview?.trackById(trackId);
    if (state.isTrackPlaying(trackId, track: track)) {
      return pause();
    }
    if (state.isTrackActive(trackId, track: track)) {
      return play();
    }
    return playTrack(trackId);
  }

  Future<void> play() async {
    final previous = state;
    state = previous.copyWith(isBusy: true);
    try {
      await ref.read(musicStatsRepositoryProvider).play();
      state = previous.copyWith(
        isPlaying: previous.hasActiveTrack,
        isBusy: false,
      );
      unawaited(
        ref
            .read(appAnalyticsProvider)
            .logEvent('playback_control', parameters: const {'action': 'play'}),
      );
    } on Object catch (error) {
      state = previous.copyWith(isBusy: false, errorMessage: error.toString());
    }
  }

  Future<void> pause() async {
    final previous = state;
    state = previous.copyWith(isBusy: true);
    try {
      await ref.read(musicStatsRepositoryProvider).pause();
      state = previous.copyWith(isPlaying: false, isBusy: false);
      unawaited(
        ref
            .read(appAnalyticsProvider)
            .logEvent(
              'playback_control',
              parameters: const {'action': 'pause'},
            ),
      );
    } on Object catch (error) {
      state = previous.copyWith(isBusy: false, errorMessage: error.toString());
    }
  }

  Future<void> skipToNext() {
    return _runTransport(
      (repository) => repository.skipToNext(),
      analyticsAction: 'skip_next',
    );
  }

  Future<void> skipToPrevious() {
    return _runTransport(
      (repository) => repository.skipToPrevious(),
      analyticsAction: 'skip_previous',
    );
  }

  Future<void> _runTransport(
    Future<void> Function(MusicStatsRepository repository) action, {
    bool keepPlaying = true,
    required String analyticsAction,
  }) async {
    final previous = state;
    state = previous.copyWith(isBusy: true);
    try {
      await action(ref.read(musicStatsRepositoryProvider));
      state = previous.copyWith(
        isPlaying: previous.isPlaying && keepPlaying,
        isBusy: false,
      );
      unawaited(
        ref
            .read(appAnalyticsProvider)
            .logEvent(
              'playback_control',
              parameters: {'action': analyticsAction},
            ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await syncWithPlayer();
    } on Object catch (error) {
      state = previous.copyWith(isBusy: false, errorMessage: error.toString());
    }
  }

  Future<void> syncWithPlayer() async {
    try {
      final snapshot = await ref
          .read(musicStatsRepositoryProvider)
          .currentPlayback();
      if (snapshot == null) {
        return;
      }
      _applyExternalPlayback(snapshot);
    } on Object catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: error.toString());
    }
  }

  void _applyExternalPlayback(MusicPlaybackSnapshot snapshot) {
    final track = snapshot.track;
    final repository = ref.read(musicStatsRepositoryProvider);
    // Only compare against an already loaded library; never start a load here.
    final overview = ref.exists(musicStatsControllerProvider)
        ? ref.read(musicStatsControllerProvider).asData?.value.overview
        : null;
    final libraryTrack = track == null
        ? null
        : repository.libraryTrackMatching(track) ??
              overview?.trackById(track.id) ??
              overview
                  ?.tracksForArtist(track.artist)
                  .where(
                    (candidate) =>
                        candidate.title.trim().toLowerCase() ==
                        track.title.trim().toLowerCase(),
                  )
                  .firstOrNull;
    if (track != null &&
        snapshot.isPlaying &&
        overview != null &&
        !overview.isDemo &&
        libraryTrack == null &&
        !ref.read(libraryFilterPreferencesProvider).excludes(track)) {
      ref.read(outsideLibraryPlaysProvider.notifier).record(track);
    }
    state = PlaybackState(
      activeTrackId: libraryTrack?.id ?? snapshot.track?.id ?? snapshot.trackId,
      nowPlaying: libraryTrack ?? snapshot.track,
      isPlaying: snapshot.isPlaying,
    );
  }
}
