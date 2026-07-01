import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/music_stats_repository.dart';
import '../../domain/library_overview.dart';
import '../../domain/music_stats_state.dart';

enum TrendRange {
  week,
  month,
  year;

  String get label {
    return switch (this) {
      TrendRange.week => '7日間',
      TrendRange.month => '4週間',
      TrendRange.year => '1年間',
    };
  }
}

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

enum HomeSection {
  playing,
  overview,
  rankings,
  library,
  settings;

  String get label {
    return switch (this) {
      HomeSection.playing => '再生中',
      HomeSection.overview => '概要',
      HomeSection.rankings => 'ランク',
      HomeSection.library => 'ライブラリ',
      HomeSection.settings => '設定',
    };
  }
}

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
    state = section;
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

final trackArtworkProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  trackId,
) {
  return ref.watch(musicStatsRepositoryProvider).fetchArtwork(trackId);
});

final playbackControllerProvider =
    AsyncNotifierProvider<PlaybackController, void>(PlaybackController.new);

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
  }

  Future<void> refreshStats() async {
    await _load(showLoading: true);
  }

  Future<void> refreshStatsSilently() async {
    await _load(showLoading: false);
  }

  void markTrackPlayed(String trackId) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.markTrackPlayed(trackId));
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
  }
}

class PlaybackController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> playTrack(String trackId) {
    return _run(
      (repository) => repository.playTrack(trackId),
      playedTrackId: trackId,
    );
  }

  Future<void> play() {
    return _run((repository) => repository.play());
  }

  Future<void> pause() {
    return _run((repository) => repository.pause());
  }

  Future<void> skipToNext() {
    return _run((repository) => repository.skipToNext());
  }

  Future<void> skipToPrevious() {
    return _run((repository) => repository.skipToPrevious());
  }

  Future<void> _run(
    Future<void> Function(MusicStatsRepository repository) action, {
    String? playedTrackId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => action(ref.read(musicStatsRepositoryProvider)),
    );
    if (state.hasError) {
      return;
    }
    if (playedTrackId != null) {
      ref
          .read(musicStatsControllerProvider.notifier)
          .markTrackPlayed(playedTrackId);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await ref
        .read(musicStatsControllerProvider.notifier)
        .refreshStatsSilently();
  }
}
