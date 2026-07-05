import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/app_analytics.dart';
import '../../data/music_stats_repository.dart';
import '../../data/music_library_channel.dart';
import '../../domain/library_overview.dart';
import '../../domain/library_snapshot.dart';
import '../../domain/music_stats_state.dart';

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

final homeSectionProvider =
    NotifierProvider<HomeSectionController, HomeSection>(
      HomeSectionController.new,
    );

class HomeSectionController extends Notifier<HomeSection> {
  @override
  HomeSection build() {
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

final trendRangeProvider = NotifierProvider<TrendRangeController, TrendRange>(
  TrendRangeController.new,
);

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

class TrendRangeController extends Notifier<TrendRange> {
  @override
  TrendRange build() {
    return TrendRange.week;
  }

  void setRange(TrendRange range) {
    state = range;
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
      return ref.watch(musicStatsRepositoryProvider).fetchArtwork(trackId);
    });

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);

class PlaybackState {
  const PlaybackState({
    this.activeTrackId,
    this.isPlaying = false,
    this.isBusy = false,
    this.errorMessage,
  });

  final String? activeTrackId;
  final bool isPlaying;
  final bool isBusy;
  final String? errorMessage;

  bool get hasActiveTrack => activeTrackId != null;

  bool isTrackActive(String trackId) => activeTrackId == trackId;

  bool isTrackPlaying(String trackId) => isPlaying && isTrackActive(trackId);

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
      isPlaying: isPlaying ?? this.isPlaying,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: errorMessage,
    );
  }
}

class MusicStatsController extends AsyncNotifier<MusicStatsState> {
  @override
  Future<MusicStatsState> build() {
    return ref.watch(musicStatsRepositoryProvider).load();
  }

  Future<void> requestAccess() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(musicStatsRepositoryProvider).load(requestAccess: true),
    );
    if (state.hasValue) {
      unawaited(ref.read(appAnalyticsProvider).logEvent('music_access_loaded'));
      await ref.read(playbackControllerProvider.notifier).syncWithPlayer();
    }
  }

  Future<void> refreshStats() async {
    unawaited(
      ref
          .read(appAnalyticsProvider)
          .logEvent('library_refresh', parameters: const {'mode': 'manual'}),
    );
    await _load(showLoading: true);
  }

  Future<void> refreshStatsSilently() async {
    unawaited(
      ref
          .read(appAnalyticsProvider)
          .logEvent('library_refresh', parameters: const {'mode': 'silent'}),
    );
    await _load(showLoading: false);
  }

  Future<SnapshotHistory?> deleteSnapshotsOlderThan(DateTime cutoff) async {
    final history = await ref
        .read(musicStatsRepositoryProvider)
        .deleteSnapshotsOlderThan(cutoff);
    _replaceSnapshotHistory(history);
    return history;
  }

  Future<SnapshotHistory?> clearSnapshotHistory() async {
    final history = await ref
        .read(musicStatsRepositoryProvider)
        .clearSnapshotHistory();
    _replaceSnapshotHistory(history);
    return history;
  }

  void _replaceSnapshotHistory(SnapshotHistory history) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.withSnapshotHistory(history));
  }

  Future<void> _load({required bool showLoading}) async {
    final previous = state.asData?.value;
    if (showLoading) {
      state = const AsyncLoading();
    }
    final next = await AsyncValue.guard(
      () => ref.read(musicStatsRepositoryProvider).load(),
    );
    state = switch (next) {
      AsyncData() => next,
      AsyncError() when !showLoading && previous != null => AsyncData(previous),
      _ => next,
    };
    if (state.hasValue) {
      final overview = state.requireValue.overview;
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
      await ref.read(playbackControllerProvider.notifier).syncWithPlayer();
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

  Future<void> playTrack(String trackId) async {
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
              parameters: const {'action': 'play_track'},
            ),
      );
    } on Object catch (error) {
      state = previous.copyWith(isBusy: false, errorMessage: error.toString());
    }
  }

  Future<void> toggleTrack(String trackId) {
    if (state.isTrackPlaying(trackId)) {
      return pause();
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
    state = PlaybackState(
      activeTrackId: snapshot.trackId,
      isPlaying: snapshot.isPlaying,
    );
  }
}
