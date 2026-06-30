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
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(musicStatsRepositoryProvider).load(),
    );
  }
}

class PlaybackController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> playTrack(String trackId) {
    return _run((repository) => repository.playTrack(trackId));
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
    Future<void> Function(MusicStatsRepository repository) action,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => action(ref.read(musicStatsRepositoryProvider)),
    );
  }
}
