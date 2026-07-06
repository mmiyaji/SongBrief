import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat, ImageFilter;

import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/apple_music_link.dart';
import '../../domain/library_overview.dart';
import '../../domain/library_snapshot.dart';
import '../../domain/library_track.dart';
import '../../domain/music_library_authorization.dart';
import '../../domain/music_stats_state.dart';
import '../../analytics/crash_reporting.dart';
import '../../export/library_exporter.dart';
import '../../localization/app_text.dart';
import '../../monetization/ad_consent.dart';
import '../../monetization/ad_banner_slot.dart';
import '../../settings/app_lock.dart';
import '../../settings/app_preferences.dart';
import '../../settings/library_filter_preferences.dart';
import '../../settings/snapshot_preferences.dart';
import '../../theme/app_theme.dart';
import 'home_controller.dart';
import 'widgets/glass_surface.dart';

part 'parts/playing_section.dart';
part 'parts/overview_section.dart';
part 'parts/overview_listening_maps.dart';
part 'parts/overview_insights.dart';
part 'parts/overview_recaps.dart';
part 'parts/library_rankings_settings.dart';
part 'parts/shared_helpers.dart';

const _privacyPolicyUrl = 'https://songbrief.ruhenheim.org/privacy/';
const _termsOfUseUrl = 'https://songbrief.ruhenheim.org/terms/';
const _officialWebsiteUrl = 'https://songbrief.ruhenheim.org/';
const _authorUrl = 'https://ruhenheim.org';

final _appVersionLabelProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return _formatAppVersion(packageInfo);
});

String _formatAppVersion(PackageInfo packageInfo) {
  final version = packageInfo.version.trim();
  final buildNumber = packageInfo.buildNumber.trim();
  if (buildNumber.isEmpty) {
    return version;
  }
  return '$version+$buildNumber';
}

String _t(
  BuildContext context,
  String en,
  String ja, {
  String? zh,
  String? ko,
}) {
  return appText(context, en, ja, zh: zh, ko: ko);
}

String _localeName(BuildContext context) {
  return Localizations.localeOf(context).toLanguageTag();
}

NumberFormat _numberFormat(BuildContext context) {
  return NumberFormat.decimalPattern(_localeName(context));
}

DateFormat _dateTimeFormat(BuildContext context) {
  return DateFormat.yMMMd(_localeName(context)).add_Hm();
}

String _countLabel(
  BuildContext context,
  int count, {
  required String singular,
  required String plural,
  required String jaUnit,
  required String zhUnit,
  required String koUnit,
}) {
  final formatted = _numberFormat(context).format(count);
  final languageCode = Localizations.localeOf(context).languageCode;
  return switch (languageCode) {
    'ja' => '$formatted$jaUnit',
    'zh' => '$formatted$zhUnit',
    'ko' => '$formatted$koUnit',
    _ => '$formatted ${count == 1 ? singular : plural}',
  };
}

String _playCountLabel(BuildContext context, int count) {
  return _countLabel(
    context,
    count,
    singular: 'play',
    plural: 'plays',
    jaUnit: '回',
    zhUnit: '次',
    koUnit: '회',
  );
}

String _skipCountLabel(BuildContext context, int count) {
  return _countLabel(
    context,
    count,
    singular: 'skip',
    plural: 'skips',
    jaUnit: '回',
    zhUnit: '次',
    koUnit: '회',
  );
}

String _trackCountLabel(BuildContext context, int count) {
  return _countLabel(
    context,
    count,
    singular: 'track',
    plural: 'tracks',
    jaUnit: '曲',
    zhUnit: '首',
    koUnit: '곡',
  );
}

String _artistCountLabel(BuildContext context, int count) {
  return _countLabel(
    context,
    count,
    singular: 'artist',
    plural: 'artists',
    jaUnit: 'アーティスト',
    zhUnit: '位艺人',
    koUnit: '아티스트',
  );
}

String _albumCountLabel(BuildContext context, int count) {
  return _countLabel(
    context,
    count,
    singular: 'album',
    plural: 'albums',
    jaUnit: 'アルバム',
    zhUnit: '张专辑',
    koUnit: '앨범',
  );
}

String _dayCountLabel(BuildContext context, int count) {
  return _countLabel(
    context,
    count,
    singular: 'day',
    plural: 'days',
    jaUnit: '日',
    zhUnit: '天',
    koUnit: '일',
  );
}

String _trackWebSearchQuery(LibraryTrack track) {
  return _joinSearchTerms([track.title, track.artist]);
}

String _albumWebSearchQuery(LibraryTrack track) {
  return _joinSearchTerms([
    track.albumTitle,
    track.albumArtist ?? track.artist,
  ]);
}

String _artistWebSearchQuery(String artist) {
  return _joinSearchTerms([artist]);
}

String _joinSearchTerms(Iterable<String?> values) {
  return values
      .map((value) => value?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toSet()
      .join(' ');
}

Uri _webSearchUri(String query) {
  return Uri.https('www.google.com', '/search', {'q': query});
}

String _authorizationLabel(
  BuildContext context,
  MusicLibraryAuthorizationStatus status,
) {
  return switch (status) {
    MusicLibraryAuthorizationStatus.notDetermined => _t(
      context,
      'Not requested',
      '未リクエスト',
    ),
    MusicLibraryAuthorizationStatus.authorized => _t(
      context,
      'Authorized',
      '許可済み',
    ),
    MusicLibraryAuthorizationStatus.denied => _t(context, 'Denied', '拒否'),
    MusicLibraryAuthorizationStatus.restricted => _t(
      context,
      'Restricted',
      '制限中',
    ),
    MusicLibraryAuthorizationStatus.unsupported => _t(
      context,
      'Demo mode',
      'デモモード',
    ),
  };
}

String _musicAccessStatusTooltipLabel(
  BuildContext context,
  bool isDemo,
  MusicLibraryAuthorizationStatus status,
) {
  if (isDemo) {
    return _t(context, 'Demo mode', 'デモモード', zh: '演示模式', ko: '데모 모드');
  }

  return switch (status) {
    MusicLibraryAuthorizationStatus.notDetermined => _t(
      context,
      'Apple Music access not requested',
      'Apple Musicアクセス未確認',
      zh: '尚未请求 Apple Music 访问权限',
      ko: 'Apple Music 접근 권한 미요청',
    ),
    MusicLibraryAuthorizationStatus.authorized => _t(
      context,
      'Apple Music authorized',
      'Apple Music認証済み',
      zh: 'Apple Music 已授权',
      ko: 'Apple Music 인증됨',
    ),
    MusicLibraryAuthorizationStatus.denied => _t(
      context,
      'Apple Music access denied',
      'Apple Musicアクセス拒否',
      zh: 'Apple Music 访问被拒绝',
      ko: 'Apple Music 접근 거부됨',
    ),
    MusicLibraryAuthorizationStatus.restricted => _t(
      context,
      'Apple Music access restricted',
      'Apple Musicアクセス制限中',
      zh: 'Apple Music 访问受限',
      ko: 'Apple Music 접근 제한됨',
    ),
    MusicLibraryAuthorizationStatus.unsupported => _t(
      context,
      'Apple Music unavailable',
      'Apple Music利用不可',
      zh: 'Apple Music 不可用',
      ko: 'Apple Music 사용 불가',
    ),
  };
}

String _themeStyleLabel(BuildContext context, SongBriefThemeStyle style) {
  return switch (style) {
    SongBriefThemeStyle.prism => _t(context, 'Prism', 'プリズム'),
    SongBriefThemeStyle.flux => _t(context, 'Flux', 'フラックス'),
    SongBriefThemeStyle.ember => _t(context, 'Ember', 'エンバー'),
    SongBriefThemeStyle.mono => _t(context, 'Mono', 'モノ'),
    SongBriefThemeStyle.aurora => _t(context, 'Aurora', 'オーロラ'),
    SongBriefThemeStyle.grove => _t(context, 'Grove', 'グローブ'),
    SongBriefThemeStyle.pulse => _t(context, 'Pulse', 'パルス'),
    SongBriefThemeStyle.muse => _t(context, 'Muse', 'ミューズ'),
  };
}

String _themeStyleDescription(BuildContext context, SongBriefThemeStyle style) {
  return switch (style) {
    SongBriefThemeStyle.prism => _t(
      context,
      'Light-split accents for a data-first surface.',
      '光の分解をイメージしたデータ重視のテーマです。',
    ),
    SongBriefThemeStyle.flux => _t(
      context,
      'Blue and mint accents with a crisp, calm look.',
      'ブルーとミントを基調にした、すっきりしたテーマです。',
    ),
    SongBriefThemeStyle.ember => _t(
      context,
      'Pink and amber music-focused theme.',
      'ピンクとアンバーを基調にした音楽向けテーマです。',
    ),
    SongBriefThemeStyle.mono => _t(
      context,
      'High-contrast monochrome theme.',
      '白黒を基調にした高コントラストテーマです。',
    ),
    SongBriefThemeStyle.aurora => _t(
      context,
      'Magenta, ice blue, and amber accents with a polar-night feel.',
      'マゼンタ、アイスブルー、アンバーで極夜の光をイメージしたテーマです。',
    ),
    SongBriefThemeStyle.grove => _t(
      context,
      'Natural green with cyan and coral accents.',
      '自然なグリーンにシアンとコーラルを添えたテーマです。',
    ),
    SongBriefThemeStyle.pulse => _t(
      context,
      'Blue, teal, and rose accents for crisp contrast.',
      'ブルー、ティール、ローズで明快に見せるテーマです。',
    ),
    SongBriefThemeStyle.muse => _t(
      context,
      'Violet, teal, and amber accents with a softer tone.',
      'バイオレット、ティール、アンバーを柔らかく組み合わせたテーマです。',
    ),
  };
}

String _themeBrightnessLabel(
  BuildContext context,
  SongBriefThemeBrightness brightness,
) {
  return switch (brightness) {
    SongBriefThemeBrightness.dark => _t(context, 'Dark', 'ダーク'),
    SongBriefThemeBrightness.light => _t(context, 'Light', 'ライト'),
    SongBriefThemeBrightness.system => _t(context, 'System', 'システム'),
  };
}

String _themeBrightnessDescription(
  BuildContext context,
  SongBriefThemeBrightness brightness,
) {
  return switch (brightness) {
    SongBriefThemeBrightness.dark => _t(
      context,
      'Uses a dark appearance.',
      '暗い配色で表示します。',
    ),
    SongBriefThemeBrightness.light => _t(
      context,
      'Uses a light appearance.',
      '明るい配色で表示します。',
    ),
    SongBriefThemeBrightness.system => _t(
      context,
      'Follows the device appearance setting.',
      '端末の外観設定に合わせます。',
      zh: '跟随设备外观设置。',
      ko: '기기의 화면 설정을 따릅니다.',
    ),
  };
}

String _languageLabel(BuildContext context, AppLanguage language) {
  return switch (language) {
    AppLanguage.system => _t(
      context,
      'System',
      'システム (System)',
      zh: '系统 (System)',
      ko: '시스템 (System)',
    ),
    AppLanguage.japanese => '日本語 (Japanese)',
    AppLanguage.english => 'English',
    AppLanguage.chineseSimplified => '简体中文 (Simplified Chinese)',
    AppLanguage.korean => '한국어 (Korean)',
  };
}

String _languageDescription(BuildContext context, AppLanguage language) {
  return switch (language) {
    AppLanguage.system => _t(
      context,
      'Follows the device language when available.',
      '利用可能な場合は端末の言語設定に合わせます。',
      zh: '可用时跟随设备的语言设置。',
      ko: '가능한 경우 기기의 언어 설정을 따릅니다.',
    ),
    AppLanguage.japanese => _t(
      context,
      'Uses Japanese app text.',
      'アプリ内の表示を日本語にします。',
      zh: '应用内文字将显示为日语。',
      ko: '앱 내 문구를 일본어로 표시합니다.',
    ),
    AppLanguage.english => _t(
      context,
      'Uses English app text.',
      'アプリ内の表示を英語にします。',
      zh: '应用内文字将显示为英语。',
      ko: '앱 내 문구를 영어로 표시합니다.',
    ),
    AppLanguage.chineseSimplified => _t(
      context,
      'Uses Simplified Chinese app text.',
      'アプリ内の表示を簡体字中国語にします。',
      zh: '应用内文字将显示为简体中文。',
      ko: '앱 내 문구를 중국어 간체로 표시합니다.',
    ),
    AppLanguage.korean => _t(
      context,
      'Uses Korean app text.',
      'アプリ内の表示を韓国語にします。',
      zh: '应用内文字将显示为韩语。',
      ko: '앱 내 문구를 한국어로 표시합니다.',
    ),
  };
}

enum _LibraryBrowseMode {
  songs,
  artists,
  albums,
  genres,
  playlists;

  IconData get icon {
    return switch (this) {
      _LibraryBrowseMode.songs => Icons.music_note_rounded,
      _LibraryBrowseMode.artists => Icons.person_rounded,
      _LibraryBrowseMode.albums => Icons.album_rounded,
      _LibraryBrowseMode.genres => Icons.category_rounded,
      _LibraryBrowseMode.playlists => Icons.playlist_play_rounded,
    };
  }
}

enum _LibrarySortMode { recent, plays, skips, title }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  DateTime? _lastResumeRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    ref.read(playbackControllerProvider.notifier).syncWithPlayer();
    final now = DateTime.now();
    final lastRefresh = _lastResumeRefreshAt;
    if (lastRefresh != null &&
        now.difference(lastRefresh) < const Duration(minutes: 15)) {
      return;
    }
    _lastResumeRefreshAt = now;
    ref.read(musicStatsControllerProvider.notifier).refreshStatsSilently();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicStatsControllerProvider);
    final selectedSection = ref.watch(homeSectionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final hasData = state.hasValue;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          bottomNavigationBar: hasData && !useRail
              ? _MobilePlaybackChrome(
                  stats: state.requireValue,
                  selectedSection: selectedSection,
                )
              : null,
          body: Stack(
            children: [
              const _Background(),
              SafeArea(
                bottom: useRail,
                child: state.when(
                  data: (stats) => _AdaptiveShell(
                    stats: stats,
                    selectedSection: selectedSection,
                    useRail: useRail,
                  ),
                  error: (error, stackTrace) => const _ErrorState(),
                  loading: () => const _LoadingState(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdaptiveShell extends StatelessWidget {
  const _AdaptiveShell({
    required this.stats,
    required this.selectedSection,
    required this.useRail,
  });

  final MusicStatsState stats;
  final HomeSection selectedSection;
  final bool useRail;

  @override
  Widget build(BuildContext context) {
    final content = _StatsContent(
      stats: stats,
      selectedSection: selectedSection,
      useRail: useRail,
    );

    if (!useRail) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SideTabs(selectedSection: selectedSection),
        Expanded(child: content),
      ],
    );
  }
}

class _BottomTabs extends ConsumerWidget {
  const _BottomTabs({required this.selectedSection});

  final HomeSection selectedSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return NavigationBar(
      selectedIndex: selectedSection.index,
      height: 72,
      backgroundColor: Colors.transparent,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.22),
      destinations: _navigationDestinations(context),
      onDestinationSelected: (index) {
        ref
            .read(homeSectionProvider.notifier)
            .setSection(HomeSection.values[index]);
      },
    );
  }
}

class _MobilePlaybackChrome extends ConsumerWidget {
  const _MobilePlaybackChrome({
    required this.stats,
    required this.selectedSection,
  });

  final MusicStatsState stats;
  final HomeSection selectedSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playback = ref.watch(playbackControllerProvider);
    final activeTrack = stats.overview.trackById(playback.activeTrackId);
    final track = activeTrack ?? stats.overview.latestTrack;
    final isLight = theme.colorScheme.brightness == Brightness.light;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(
                    alpha: isLight ? 0.97 : 0.86,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (track != null) ...[
                        _MiniPlayerBar(track: track),
                        const SizedBox(height: 2),
                      ],
                      _BottomTabs(selectedSection: selectedSection),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final artwork = ref.watch(trackArtworkProvider(track.id));
    final playback = ref.watch(playbackControllerProvider);
    final busy = playback.isBusy;
    final isActive = playback.isTrackActive(track.id);
    final isPlaying = playback.isTrackPlaying(track.id);
    final isLight = theme.colorScheme.brightness == Brightness.light;
    final barColor = isLight
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.black.withValues(alpha: 0.36);
    final borderColor = isLight
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.1);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: _t(context, 'Open current track', '再生中の曲を開く'),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref
                          .read(homeSectionProvider.notifier)
                          .setSection(HomeSection.playing);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          _MiniArtwork(track: track, artwork: artwork),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    isPlaying
                                        ? _t(context, 'Playing now', '再生中')
                                        : _t(context, 'Paused', '一時停止中'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isPlaying
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: busy
                  ? null
                  : () {
                      ref
                          .read(playbackControllerProvider.notifier)
                          .toggleTrack(track.id);
                    },
              tooltip: isPlaying
                  ? _t(context, 'Pause', '一時停止')
                  : _t(context, 'Play', '再生'),
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            IconButton(
              onPressed: busy
                  ? null
                  : () {
                      ref
                          .read(playbackControllerProvider.notifier)
                          .skipToNext();
                    },
              tooltip: _t(context, 'Next', '次へ'),
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.track, required this.artwork});

  final LibraryTrack track;
  final AsyncValue<Uint8List?> artwork;

  @override
  Widget build(BuildContext context) {
    final bytes = artwork.asData?.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 38,
        child: bytes == null
            ? track.artworkAsset == null
                  ? ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.18),
                      child: Icon(
                        Icons.album_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    )
                  : Image.asset(track.artworkAsset!, fit: BoxFit.cover)
            : Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}

class _SideTabs extends ConsumerWidget {
  const _SideTabs({required this.selectedSection});

  final HomeSection selectedSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      child: GlassSurface(
        padding: const EdgeInsets.symmetric(vertical: 12),
        radius: 24,
        tint: const Color(0x26FFFFFF),
        borderOpacity: 0.14,
        shadowOpacity: 0.16,
        child: NavigationRail(
          selectedIndex: selectedSection.index,
          backgroundColor: Colors.transparent,
          extended: width >= 980,
          minExtendedWidth: 188,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Icon(Icons.graphic_eq, color: theme.colorScheme.primary),
          ),
          destinations: HomeSection.values
              .map(
                (section) => NavigationRailDestination(
                  icon: Icon(_sectionIcon(section)),
                  selectedIcon: Icon(_sectionSelectedIcon(section)),
                  label: Text(_sectionLabel(context, section)),
                ),
              )
              .toList(),
          onDestinationSelected: (index) {
            ref
                .read(homeSectionProvider.notifier)
                .setSection(HomeSection.values[index]);
          },
        ),
      ),
    );
  }
}

class _StatsContent extends ConsumerWidget {
  const _StatsContent({
    required this.stats,
    required this.selectedSection,
    required this.useRail,
  });

  final MusicStatsState stats;
  final HomeSection selectedSection;
  final bool useRail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator.adaptive(
      onRefresh: () => ref
          .read(musicStatsControllerProvider.notifier)
          .refreshStatsSilently(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                useRail ? 24 : 20,
                12,
                useRail ? 28 : 20,
                useRail ? 28 : 172,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(stats: stats, selectedSection: selectedSection),
                      const SizedBox(height: 16),
                      _SectionBody(
                        stats: stats,
                        selectedSection: selectedSection,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.stats, required this.selectedSection});

  final MusicStatsState stats;
  final HomeSection selectedSection;

  @override
  Widget build(BuildContext context) {
    final overview = stats.overview;

    return switch (selectedSection) {
      HomeSection.playing => _NowPlayingSection(stats: stats),
      HomeSection.overview => _OverviewSection(stats: stats),
      HomeSection.rankings =>
        overview.hasTracks
            ? _RankingPanel(
                overview: overview,
                history: stats.snapshotHistory,
                snapshotRecordingEnabled: stats.snapshotRecordingEnabled,
              )
            : const _EmptyLibraryPanel(),
      HomeSection.library => _LibrarySection(overview: overview),
      HomeSection.settings => _SettingsSection(stats: stats),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.stats, required this.selectedSection});

  final MusicStatsState stats;
  final HomeSection selectedSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overview = stats.overview;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SongBrief', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text(
                _sectionSubtitle(context, selectedSection, overview.isDemo),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _MusicAccessStatusPill(
          isDemo: overview.isDemo,
          status: stats.authorizationStatus,
        ),
      ],
    );
  }
}

class _MusicAccessStatusPill extends StatefulWidget {
  const _MusicAccessStatusPill({required this.isDemo, required this.status});

  final bool isDemo;
  final MusicLibraryAuthorizationStatus status;

  @override
  State<_MusicAccessStatusPill> createState() => _MusicAccessStatusPillState();
}

class _MusicAccessStatusPillState extends State<_MusicAccessStatusPill> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _musicAccessStatusTooltipLabel(
      context,
      widget.isDemo,
      widget.status,
    );
    final icon = widget.isDemo
        ? Icons.science_outlined
        : _musicAccessStatusIcon(widget.status);
    final color = _musicAccessStatusColor(theme, widget.isDemo, widget.status);

    return Tooltip(
      key: _tooltipKey,
      message: label,
      triggerMode: TooltipTriggerMode.manual,
      showDuration: const Duration(seconds: 2),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              _tooltipKey.currentState?.ensureTooltipVisible();
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GlassSurface(
                padding: const EdgeInsets.all(10),
                radius: 18,
                tint: const Color(0x55FFFFFF),
                shadowOpacity: 0.02,
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _musicAccessStatusIcon(MusicLibraryAuthorizationStatus status) {
  return switch (status) {
    MusicLibraryAuthorizationStatus.authorized => Icons.apple_rounded,
    MusicLibraryAuthorizationStatus.notDetermined => Icons.music_note_outlined,
    MusicLibraryAuthorizationStatus.denied ||
    MusicLibraryAuthorizationStatus.restricted => Icons.lock_outline_rounded,
    MusicLibraryAuthorizationStatus.unsupported => Icons.info_outline_rounded,
  };
}

Color _musicAccessStatusColor(
  ThemeData theme,
  bool isDemo,
  MusicLibraryAuthorizationStatus status,
) {
  if (isDemo) {
    return theme.colorScheme.onSurfaceVariant;
  }
  return switch (status) {
    MusicLibraryAuthorizationStatus.authorized => theme.colorScheme.primary,
    MusicLibraryAuthorizationStatus.notDetermined =>
      theme.colorScheme.onSurfaceVariant,
    MusicLibraryAuthorizationStatus.denied ||
    MusicLibraryAuthorizationStatus.restricted => theme.colorScheme.error,
    MusicLibraryAuthorizationStatus.unsupported =>
      theme.colorScheme.onSurfaceVariant,
  };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: 16,
      tint: const Color(0x55FFFFFF),
      shadowOpacity: 0.02,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AuthorizationPanel extends ConsumerWidget {
  const _AuthorizationPanel({required this.status});

  final MusicLibraryAuthorizationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final message = status == MusicLibraryAuthorizationStatus.notDetermined
        ? _t(
            context,
            'Allow Music access to read play counts and skip counts.',
            '再生回数とスキップ回数を読み取るため、ミュージックへのアクセスを許可してください。',
          )
        : _t(
            context,
            'Music access is ${_authorizationLabel(context, status).toLowerCase()}.',
            'ミュージックアクセスは「${_authorizationLabel(context, status)}」です。',
            zh: '音乐访问权限：${_authorizationLabel(context, status)}。',
            ko: '음악 접근 상태: ${_authorizationLabel(context, status)}.',
          );

    return GlassSurface(
      tint: const Color(0x5CFFFFFF),
      radius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final action = FilledButton.icon(
            onPressed: () {
              ref.read(musicStatsControllerProvider.notifier).requestAccess();
            },
            icon: const Icon(Icons.lock_open),
            label: Text(_t(context, 'Allow', '許可')),
          );

          final content = Row(
            children: [
              Icon(Icons.library_music, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
            ],
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      radius: 18,
      tint: const Color(0x50FFFFFF),
      shadowOpacity: 0.025,
      child: Row(
        children: [
          Icon(Icons.phone_iphone, color: theme.colorScheme.tertiary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                context,
                'Demo data shown until iOS Music access is available.',
                'iOSミュージックへのアクセスが利用可能になるまでデモデータを表示しています。',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
