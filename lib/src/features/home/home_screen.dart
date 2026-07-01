import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/library_overview.dart';
import '../../domain/library_snapshot.dart';
import '../../domain/library_track.dart';
import '../../domain/music_library_authorization.dart';
import '../../domain/music_stats_state.dart';
import '../../settings/app_preferences.dart';
import '../../theme/app_theme.dart';
import 'home_controller.dart';
import 'widgets/glass_surface.dart';

const _privacyPolicyUrl = 'https://mmiyaji.github.io/SongBrief/privacy/';
const _termsOfUseUrl = 'https://mmiyaji.github.io/SongBrief/terms/';

String _t(BuildContext context, String en, String ja) {
  return Localizations.localeOf(context).languageCode == 'ja' ? ja : en;
}

enum _LibraryBrowseMode {
  songs,
  artists,
  albums,
  genres;

  String get label {
    return switch (this) {
      _LibraryBrowseMode.songs => 'Songs',
      _LibraryBrowseMode.artists => 'Artists',
      _LibraryBrowseMode.albums => 'Albums',
      _LibraryBrowseMode.genres => 'Genres',
    };
  }

  IconData get icon {
    return switch (this) {
      _LibraryBrowseMode.songs => Icons.music_note_rounded,
      _LibraryBrowseMode.artists => Icons.person_rounded,
      _LibraryBrowseMode.albums => Icons.album_rounded,
      _LibraryBrowseMode.genres => Icons.category_rounded,
    };
  }
}

enum _LibrarySortMode {
  recent,
  plays,
  skips,
  title;

  String get label {
    return switch (this) {
      _LibrarySortMode.recent => 'Recently played',
      _LibrarySortMode.plays => 'Most played',
      _LibrarySortMode.skips => 'Most skipped',
      _LibrarySortMode.title => 'Title',
    };
  }
}

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
                  error: (error, stackTrace) => _ErrorState(error: error),
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

class _MobilePlaybackChrome extends StatelessWidget {
  const _MobilePlaybackChrome({
    required this.stats,
    required this.selectedSection,
  });

  final MusicStatsState stats;
  final HomeSection selectedSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = stats.overview.latestTrack;
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
                  color: theme.colorScheme.surface.withValues(alpha: 0.86),
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
    final busy = playback.isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            _MiniArtwork(track: track, artwork: artwork),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: busy
                  ? null
                  : () {
                      ref
                          .read(playbackControllerProvider.notifier)
                          .playTrack(track.id);
                    },
              tooltip: 'Play',
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            IconButton(
              onPressed: busy
                  ? null
                  : () {
                      ref
                          .read(playbackControllerProvider.notifier)
                          .skipToNext();
                    },
              tooltip: 'Next',
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
      onRefresh: () =>
          ref.read(musicStatsControllerProvider.notifier).refreshStats(),
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
            ? _RankingPanel(overview: overview)
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
        _StatusPill(
          label: overview.isDemo ? 'Demo' : stats.authorizationStatus.label,
        ),
      ],
    );
  }
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
        ? 'Allow Music access to read play counts and skip counts.'
        : 'Music access is ${status.label.toLowerCase()}.';

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
            label: const Text('Allow'),
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
              'Demo data shown until iOS Music access is available.',
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

class _NowPlayingSection extends ConsumerWidget {
  const _NowPlayingSection({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = stats.overview;
    final track = overview.latestTrack;

    if (track == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo)
            _AuthorizationPanel(status: stats.authorizationStatus),
          if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo)
            const SizedBox(height: 14),
          const _EmptyLibraryPanel(),
        ],
      );
    }

    final artwork = ref.watch(trackArtworkProvider(track.id));
    final recentTracks = overview.recentTrackDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo) ...[
          _AuthorizationPanel(status: stats.authorizationStatus),
          const SizedBox(height: 14),
        ],
        _HeroTrackPanel(track: track, artwork: artwork),
        const SizedBox(height: 14),
        _TrendPanel(track: track),
        if (recentTracks.length > 1) ...[
          const SizedBox(height: 14),
          _RecentTracksPanel(tracks: recentTracks),
        ],
      ],
    );
  }
}

class _HeroTrackPanel extends ConsumerWidget {
  const _HeroTrackPanel({required this.track, required this.artwork});

  final LibraryTrack track;
  final AsyncValue<Uint8List?> artwork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playback = ref.watch(playbackControllerProvider);
    final busy = playback.isLoading;
    final number = NumberFormat.decimalPattern();

    return GlassSurface(
      padding: EdgeInsets.zero,
      radius: 30,
      tint: const Color(0x24FFFFFF),
      borderOpacity: 0.14,
      shadowOpacity: 0.2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 560) {
                  return _HeroTrackWideHeader(
                    track: track,
                    artwork: artwork,
                    number: number,
                    busy: busy,
                    onPlay: () {
                      ref
                          .read(playbackControllerProvider.notifier)
                          .playTrack(track.id);
                    },
                  );
                }

                return AspectRatio(
                  aspectRatio: 1.05,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _TrackArtworkImage(track: track, artwork: artwork),
                      const _HeroImageShade(),
                      Positioned(
                        left: 18,
                        top: 18,
                        child: _HeroBadge(label: '#1 Song'),
                      ),
                      Positioned(
                        right: 18,
                        top: 18,
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.36,
                            ),
                            foregroundColor: theme.colorScheme.primary,
                            minimumSize: const Size.square(46),
                          ),
                          onPressed: busy
                              ? null
                              : () {
                                  ref
                                      .read(playbackControllerProvider.notifier)
                                      .playTrack(track.id);
                                },
                          tooltip: 'Play this track',
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 22,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineLarge
                                        ?.copyWith(
                                          fontSize: 42,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  number.format(track.playCount),
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                const _SmallMetricPill(label: '再生回数'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            _HeroStatStrip(track: track),
          ],
        ),
      ),
    );
  }
}

class _HeroTrackWideHeader extends StatelessWidget {
  const _HeroTrackWideHeader({
    required this.track,
    required this.artwork,
    required this.number,
    required this.busy,
    required this.onPlay,
  });

  final LibraryTrack track;
  final AsyncValue<Uint8List?> artwork;
  final NumberFormat number;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final albumArtist = track.albumArtist ?? track.artist;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final artworkSize = (constraints.maxWidth * 0.34)
              .clamp(210.0, 310.0)
              .toDouble();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: artworkSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _TrackArtworkImage(track: track, artwork: artwork),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _HeroBadge(label: '#1 Song'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TrackChip(
                          icon: Icons.graphic_eq_rounded,
                          label: 'Recent play',
                        ),
                        if (track.isCloudItem)
                          _TrackChip(icon: Icons.cloud_rounded, label: 'Cloud'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 32,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      albumArtist == track.artist
                          ? track.albumTitle
                          : '$albumArtist - ${track.albumTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.square(54),
                          ),
                          onPressed: busy ? null : onPlay,
                          tooltip: 'Play this track',
                          icon: const Icon(Icons.play_arrow_rounded, size: 31),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              number.format(track.playCount),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const _SmallMetricPill(label: 'Plays'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroImageShade extends StatelessWidget {
  const _HeroImageShade();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.black.withValues(alpha: 0.34));
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SmallMetricPill extends StatelessWidget {
  const _SmallMetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HeroStatStrip extends ConsumerWidget {
  const _HeroStatStrip({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.32),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: _HeroStat(
              icon: Icons.play_arrow_rounded,
              label: '再生回数',
              value: '${number.format(track.playCount)} 回',
              color: theme.colorScheme.primary,
              onTap: () => _focusTrackInRanking(context, ref, track),
            ),
          ),
          const _VerticalDividerLine(),
          Expanded(
            child: _HeroStat(
              icon: Icons.fast_forward_rounded,
              label: 'スキップ',
              value: '${number.format(track.skipCount)} 回',
              color: theme.colorScheme.secondary,
              onTap: () => _focusTrackInRanking(context, ref, track),
            ),
          ),
          const _VerticalDividerLine(),
          Expanded(
            child: _HeroStat(
              icon: Icons.schedule_rounded,
              label: '最終再生',
              value: _shortPlayedAtLabel(track.lastPlayedAt),
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDividerLine extends StatelessWidget {
  const _VerticalDividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.52),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: content,
      ),
    );
  }
}

class _TrendPanel extends ConsumerWidget {
  const _TrendPanel({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final range = ref.watch(trendRangeProvider);
    final values = _trendValues(track, range);
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      radius: 26,
      tint: const Color(0x24FFFFFF),
      borderOpacity: 0.12,
      shadowOpacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.stacked_bar_chart_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '今週の傾向',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TrendRange>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.primary;
                  }
                  return theme.colorScheme.surfaceContainerHighest;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.black;
                  }
                  return theme.colorScheme.onSurfaceVariant;
                }),
                side: WidgetStatePropertyAll(
                  BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.48,
                    ),
                  ),
                ),
              ),
              segments: TrendRange.values
                  .map(
                    (value) => ButtonSegment<TrendRange>(
                      value: value,
                      label: Text(_trendRangeLabel(context, value)),
                    ),
                  )
                  .toList(),
              selected: {range},
              onSelectionChanged: (selection) {
                ref.read(trendRangeProvider.notifier).setRange(selection.first);
              },
            ),
          ),
          const SizedBox(height: 18),
          _TrendBars(values: values, range: range),
        ],
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.values, required this.range});

  final List<int> values;
  final TrendRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = values.reduce((a, b) => a > b ? a : b);
    final labels = _trendLabels(range);

    return SizedBox(
      height: 178,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.indexed.map((indexed) {
          final index = indexed.$1;
          final value = indexed.$2;
          final ratio = max == 0 ? 0.0 : value / max;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 5, right: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _compactNumber(value),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: index == values.length - 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio.clamp(0.08, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: index == values.length - 1
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                          child: const SizedBox(width: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: index == values.length - 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentTracksPanel extends ConsumerStatefulWidget {
  const _RecentTracksPanel({required this.tracks});

  final List<LibraryTrack> tracks;

  @override
  ConsumerState<_RecentTracksPanel> createState() => _RecentTracksPanelState();
}

class _RecentTracksPanelState extends ConsumerState<_RecentTracksPanel> {
  static const _initialVisibleCount = 4;
  static const _loadMoreCount = 4;

  int _visibleCount = _initialVisibleCount;

  @override
  void didUpdateWidget(covariant _RecentTracksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks != widget.tracks &&
        _visibleCount > widget.tracks.length) {
      _visibleCount = _clampInt(
        _visibleCount,
        _initialVisibleCount,
        widget.tracks.length,
      );
    }
  }

  void _loadMore() {
    setState(() {
      _visibleCount = _clampInt(
        _visibleCount + _loadMoreCount,
        _initialVisibleCount,
        widget.tracks.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleTracks = widget.tracks
        .take(_visibleCount)
        .toList(growable: false);
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      radius: 26,
      tint: const Color(0x24FFFFFF),
      borderOpacity: 0.12,
      shadowOpacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '最近再生した曲',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(homeSectionProvider.notifier)
                      .setSection(HomeSection.library);
                },
                child: const Text('すべて見る'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...visibleTracks.map((track) => _RecentTrackRow(track: track)),
          if (visibleTracks.length < widget.tracks.length) ...[
            const SizedBox(height: 8),
            _LoadMoreButton(
              shownCount: visibleTracks.length,
              totalCount: widget.tracks.length,
              nextCount: _loadMoreCount,
              onPressed: _loadMore,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentTrackRow extends ConsumerWidget {
  const _RecentTrackRow({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final artwork = ref.watch(trackArtworkProvider(track.id));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTrackDetailSheet(context, track),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox.square(
                dimension: 50,
                child: _TrackArtworkImage(track: track, artwork: artwork),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _shortPlayedAtLabel(track.lastPlayedAt),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => _TrackActionSheet(track: track),
                );
              },
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackActionSheet extends ConsumerWidget {
  const _TrackActionSheet({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(track.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            track.artist,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(playbackControllerProvider.notifier).playTrack(track.id);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('再生'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showTrackDetailSheet(context, track);
            },
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('詳細を見る'),
          ),
        ],
      ),
    );
  }
}

void _showTrackDetailSheet(BuildContext context, LibraryTrack track) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TrackDetailSheet(track: track),
  );
}

class _TrackDetailSheet extends ConsumerWidget {
  const _TrackDetailSheet({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final artwork = ref.watch(trackArtworkProvider(track.id));
    final height = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.86),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _TrackArtworkImage(track: track, artwork: artwork),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _PlaybackControls(track: track),
              const SizedBox(height: 18),
              _TrackDetailsPanel(track: track),
            ],
          ),
        ),
      ),
    );
  }
}

void _showTrackGroupSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required List<LibraryTrack> tracks,
  RankingScope? rankingScope,
  String? rankingTitle,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TrackGroupSheet(
      title: title,
      subtitle: subtitle,
      icon: icon,
      tracks: tracks,
      rankingScope: rankingScope,
      rankingTitle: rankingTitle,
    ),
  );
}

class _TrackGroupSheet extends ConsumerWidget {
  const _TrackGroupSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tracks,
    this.rankingScope,
    this.rankingTitle,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<LibraryTrack> tracks;
  final RankingScope? rankingScope;
  final String? rankingTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final totalPlayCount = tracks.fold<int>(
      0,
      (total, track) => total + track.playCount,
    );
    final height = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.86),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$subtitle ・ ${tracks.length}曲 ・ ${number.format(totalPlayCount)}回',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (rankingScope != null && rankingTitle != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    _focusRankingEntry(
                      context,
                      ref,
                      scope: rankingScope!,
                      title: rankingTitle!,
                      closeAllRoutes: true,
                    );
                  },
                  icon: const Icon(Icons.leaderboard_rounded),
                  label: const Text('ランキング内の位置を見る'),
                ),
              ],
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return _GroupTrackRow(track: track, rank: index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTrackRow extends ConsumerWidget {
  const _GroupTrackRow({required this.track, required this.rank});

  final LibraryTrack track;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final artwork = ref.watch(trackArtworkProvider(track.id));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTrackDetailSheet(context, track),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$rank',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 42,
                  child: _TrackArtworkImage(track: track, artwork: artwork),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.albumTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                number.format(track.playCount),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackArtworkImage extends StatelessWidget {
  const _TrackArtworkImage({required this.track, required this.artwork});

  final LibraryTrack track;
  final AsyncValue<Uint8List?> artwork;

  @override
  Widget build(BuildContext context) {
    final bytes = artwork.asData?.value;
    final theme = Theme.of(context);
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }

    final asset = track.artworkAsset;
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.cover);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 72,
          color: Colors.white.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _NowTrackPanel extends StatelessWidget {
  const _NowTrackPanel({required this.track, required this.artwork});

  final LibraryTrack track;
  final AsyncValue<Uint8List?> artwork;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      radius: 32,
      tint: const Color(0x32FFFFFF),
      borderOpacity: 0.18,
      shadowOpacity: 0.24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final details = _NowTrackCopy(track: track);

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 232,
                  child: _AlbumArtwork(track: track, artwork: artwork),
                ),
                const SizedBox(width: 22),
                Expanded(child: details),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AlbumArtwork(track: track, artwork: artwork),
              const SizedBox(height: 18),
              details,
            ],
          );
        },
      ),
    );
  }
}

class _NowTrackCopy extends StatelessWidget {
  const _NowTrackCopy({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TrackChip(icon: Icons.graphic_eq_rounded, label: '直近再生'),
            if (track.isCloudItem)
              _TrackChip(icon: Icons.cloud_rounded, label: 'Cloud'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 36,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          track.albumTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        _PlaybackControls(track: track),
      ],
    );
  }
}

class _TrackChip extends StatelessWidget {
  const _TrackChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({required this.track, required this.artwork});

  final LibraryTrack track;
  final AsyncValue<Uint8List?> artwork;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = artwork.asData?.value;

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: bytes == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Icon(
                    Icons.album_rounded,
                    size: 76,
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.album_rounded,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
      ),
    );
  }
}

class _PlaybackControls extends ConsumerWidget {
  const _PlaybackControls({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(playbackControllerProvider);
    final busy = state.isLoading;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: busy
              ? null
              : () {
                  ref
                      .read(playbackControllerProvider.notifier)
                      .skipToPrevious();
                },
          tooltip: 'Previous',
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.square(56),
          ),
          onPressed: busy
              ? null
              : () {
                  ref
                      .read(playbackControllerProvider.notifier)
                      .playTrack(track.id);
                },
          tooltip: 'Play this track',
          icon: const Icon(Icons.play_arrow_rounded, size: 32),
        ),
        IconButton.filledTonal(
          onPressed: busy
              ? null
              : () {
                  ref.read(playbackControllerProvider.notifier).pause();
                },
          tooltip: 'Pause',
          icon: const Icon(Icons.pause_rounded),
        ),
        IconButton.filledTonal(
          onPressed: busy
              ? null
              : () {
                  ref.read(playbackControllerProvider.notifier).skipToNext();
                },
          tooltip: 'Next',
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

class _TrackDetailsPanel extends ConsumerWidget {
  const _TrackDetailsPanel({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = NumberFormat.decimalPattern();
    final overview = ref
        .watch(musicStatsControllerProvider)
        .asData
        ?.value
        .overview;
    final artistTracks = overview == null
        ? const <LibraryTrack>[]
        : _tracksByArtist(overview, track.artist);
    final albumTracks = overview == null
        ? const <LibraryTrack>[]
        : _tracksByAlbum(overview, track);
    final albumArtist = track.albumArtist ?? track.artist;
    final albumArtistTracks = overview == null
        ? const <LibraryTrack>[]
        : _tracksByAlbumArtist(overview, albumArtist);
    final genreTracks = track.genre == null || overview == null
        ? const <LibraryTrack>[]
        : _tracksByGenre(overview, track.genre!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TrackDetailRow(
          icon: Icons.person_outline,
          label: 'アーティスト',
          value: track.artist,
          onTap: artistTracks.isEmpty
              ? null
              : () => _showTrackGroupSheet(
                  context,
                  title: track.artist,
                  subtitle: 'アーティストの曲',
                  icon: Icons.person_outline,
                  tracks: artistTracks,
                  rankingScope: RankingScope.artists,
                  rankingTitle: track.artist,
                ),
        ),
        const SizedBox(height: 10),
        _TrackDetailRow(
          icon: Icons.album_outlined,
          label: 'アルバム',
          value: track.albumTitle,
          onTap: albumTracks.isEmpty
              ? null
              : () => _showTrackGroupSheet(
                  context,
                  title: track.albumTitle,
                  subtitle: albumArtist,
                  icon: Icons.album_outlined,
                  tracks: albumTracks,
                  rankingScope: RankingScope.albums,
                  rankingTitle: _albumRankingTitle(track),
                ),
        ),
        const SizedBox(height: 10),
        _TrackDetailRow(
          icon: Icons.mic_external_on_outlined,
          label: 'アルバムアーティスト',
          value: albumArtist,
          onTap: albumArtistTracks.isEmpty
              ? null
              : () => _showTrackGroupSheet(
                  context,
                  title: albumArtist,
                  subtitle: 'アルバムアーティストの曲',
                  icon: Icons.mic_external_on_outlined,
                  tracks: albumArtistTracks,
                  rankingScope: RankingScope.artists,
                  rankingTitle: albumArtist,
                ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final cards = [
              _TrackStatCard(
                icon: Icons.play_arrow_outlined,
                label: '再生回数',
                value: '${number.format(track.playCount)} 回',
                onTap: () => _focusTrackInRanking(
                  context,
                  ref,
                  track,
                  closeCurrentRoute: true,
                ),
              ),
              _TrackStatCard(
                icon: Icons.fast_forward_outlined,
                label: 'スキップ',
                value: '${number.format(track.skipCount)} 回',
                onTap: () => _focusTrackInRanking(
                  context,
                  ref,
                  track,
                  closeCurrentRoute: true,
                ),
              ),
            ];

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cards[0], const SizedBox(height: 10), cards[1]],
              );
            }

            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _TrackDetailRow(
          icon: Icons.schedule_outlined,
          label: '最後に再生した日',
          value: _playedAtLabel(track.lastPlayedAt),
        ),
        const SizedBox(height: 10),
        _TrackDetailRow(
          icon: Icons.timer_outlined,
          label: '曲の長さ',
          value: _durationLabel(track.duration),
        ),
        if (track.genre != null) ...[
          const SizedBox(height: 10),
          _TrackDetailRow(
            icon: Icons.category_outlined,
            label: 'ジャンル',
            value: track.genre!,
            onTap: genreTracks.isEmpty
                ? null
                : () => _showTrackGroupSheet(
                    context,
                    title: track.genre!,
                    subtitle: 'ジャンルの曲',
                    icon: Icons.category_outlined,
                    tracks: genreTracks,
                  ),
          ),
        ],
      ],
    );
  }
}

class _TrackDetailRow extends StatelessWidget {
  const _TrackDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: 24,
      tint: const Color(0x2CFFFFFF),
      borderOpacity: 0.12,
      shadowOpacity: 0.1,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: content,
    );
  }
}

class _TrackStatCard extends StatelessWidget {
  const _TrackStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x2CFFFFFF),
      borderOpacity: 0.12,
      shadowOpacity: 0.1,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: content,
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context) {
    final overview = stats.overview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo) ...[
          _AuthorizationPanel(status: stats.authorizationStatus),
          const SizedBox(height: 16),
        ],
        if (overview.isDemo) ...[
          const _DemoBanner(),
          const SizedBox(height: 16),
        ],
        _OverviewPanel(overview: overview),
        const SizedBox(height: 14),
        _SnapshotStatusPanel(
          history: stats.snapshotHistory,
          isDemo: overview.isDemo,
        ),
        const SizedBox(height: 14),
        _SummaryGrid(overview: overview),
        const SizedBox(height: 14),
        _OverviewInsightPanel(overview: overview),
        const SizedBox(height: 14),
        _OverviewBreakdownPanel(overview: overview),
      ],
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    final topTrack = overview.topTracks.isEmpty
        ? null
        : overview.topTracks.first;
    final skipRate = overview.totalPlayCount == 0
        ? 0.0
        : overview.totalSkipCount / overview.totalPlayCount * 100;

    return GlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 26,
      tint: const Color(0x6BFFFFFF),
      borderOpacity: 0.62,
      shadowOpacity: 0.07,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final signalTiles = _OverviewSignals(
            hours: _hoursLabel(overview.totalListeningSeconds),
            skips: number.format(overview.totalSkipCount),
            skipRate: '${skipRate.toStringAsFixed(1)}%',
          );

          if (constraints.maxWidth >= 640) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _OverviewMain(overview: overview, topTrack: topTrack),
                ),
                const SizedBox(width: 20),
                SizedBox(width: 260, child: signalTiles),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverviewMain(overview: overview, topTrack: topTrack),
              const SizedBox(height: 18),
              signalTiles,
            ],
          );
        },
      ),
    );
  }
}

class _OverviewMain extends StatelessWidget {
  const _OverviewMain({required this.overview, required this.topTrack});

  final LibraryOverview overview;
  final RankingEntry? topTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Plays',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            number.format(overview.totalPlayCount),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 64,
              height: 0.94,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${number.format(overview.totalTracks)} tracks - '
          '${number.format(overview.totalArtists)} artists - '
          '${number.format(overview.totalAlbums)} albums',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (topTrack != null) ...[
          const SizedBox(height: 18),
          _TopTrackLine(entry: topTrack!),
        ],
      ],
    );
  }
}

class _TopTrackLine extends StatelessWidget {
  const _TopTrackLine({required this.entry});

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.equalizer,
                color: theme.colorScheme.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top song',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSignals extends StatelessWidget {
  const _OverviewSignals({
    required this.hours,
    required this.skips,
    required this.skipRate,
  });

  final String hours;
  final String skips;
  final String skipRate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SignalTile(icon: Icons.schedule, label: 'Hours', value: hours),
        _SignalTile(icon: Icons.fast_forward, label: 'Skips', value: skips),
        _SignalTile(icon: Icons.speed, label: 'Skip rate', value: skipRate),
      ],
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 118),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(height: 10),
              Text(value, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotStatusPanel extends StatelessWidget {
  const _SnapshotStatusPanel({required this.history, required this.isDemo});

  final SnapshotHistory history;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final latest = history.latest;
    final delta = history.latestDelta;

    if (isDemo || latest == null) {
      return GlassSurface(
        padding: const EdgeInsets.all(18),
        radius: 24,
        tint: const Color(0x54FFFFFF),
        borderOpacity: 0.38,
        shadowOpacity: 0.05,
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily snapshots', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    isDemo
                        ? 'Available after iOS Music access is granted.'
                        : 'The first snapshot will be saved after the next scan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final latestDate = DateFormat.yMMMd().add_Hm().format(latest.capturedAt);
    final observedDays = delta?.observedDays ?? 0;
    final topDeltas =
        delta?.trackDeltas.take(3).toList(growable: false) ??
        const <TrackCounterDelta>[];

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x54FFFFFF),
      borderOpacity: 0.38,
      shadowOpacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily snapshots', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      'Last scan $latestDate - ${_snapshotSourceLabel(latest.source)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: '${history.snapshotCount} days'),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _SnapshotMetric(
                  label: 'Window',
                  value: observedDays <= 0 ? 'Baseline' : '$observedDays days',
                ),
                _SnapshotMetric(
                  label: 'New plays',
                  value: number.format(delta?.totalPlayDelta ?? 0),
                ),
                _SnapshotMetric(
                  label: 'New skips',
                  value: number.format(delta?.totalSkipDelta ?? 0),
                ),
              ];

              if (constraints.maxWidth < 560) {
                return Column(
                  children: metrics
                      .map(
                        (metric) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: metric,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: metrics
                    .map(
                      (metric) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: metric,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (topDeltas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Top gains since previous scan',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...topDeltas.map(
              (track) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '+${number.format(track.playDelta)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (delta != null) ...[
            const SizedBox(height: 12),
            Text(
              'No play count changes were observed between the last two scans.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(value, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    final values = [
      _SummaryValue(
        icon: Icons.person,
        label: 'Artists',
        value: number.format(overview.totalArtists),
      ),
      _SummaryValue(
        icon: Icons.album,
        label: 'Albums',
        value: number.format(overview.totalAlbums),
      ),
      _SummaryValue(
        icon: Icons.music_note,
        label: 'Tracks',
        value: number.format(overview.totalTracks),
      ),
      _SummaryValue(
        icon: Icons.schedule,
        label: 'Hours',
        value: _hoursLabel(overview.totalListeningSeconds),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 620 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 4 ? 1.72 : 1.45,
          ),
          itemBuilder: (context, index) => _SummaryCard(value: values[index]),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value});

  final _SummaryValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(12),
      radius: 18,
      tint: const Color(0x55FFFFFF),
      shadowOpacity: 0.035,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(value.icon, color: theme.colorScheme.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value.value, style: theme.textTheme.titleMedium),
                ),
                Text(
                  value.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewInsightPanel extends StatelessWidget {
  const _OverviewInsightPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    final topArtist = overview.topArtists.isEmpty
        ? null
        : overview.topArtists.first;
    final topAlbum = overview.topAlbums.isEmpty
        ? null
        : overview.topAlbums.first;
    final recentTrackCount = _recentlyPlayedCount(
      overview.tracks,
      const Duration(days: 30),
    );
    final playedTrackCount = overview.tracks
        .where((track) => track.playCount > 0)
        .length;
    final unplayedTrackCount = overview.totalTracks - playedTrackCount;
    final cloudTrackCount = overview.tracks
        .where((track) => track.isCloudItem)
        .length;
    final averagePlays = overview.totalTracks == 0
        ? 0.0
        : overview.totalPlayCount / overview.totalTracks;

    final insights = [
      _OverviewInsightValue(
        icon: Icons.person_pin_rounded,
        label: 'Favorite artist',
        value: topArtist?.title ?? 'None',
        detail: topArtist == null
            ? 'No plays yet'
            : '${number.format(topArtist.playCount)} plays',
      ),
      _OverviewInsightValue(
        icon: Icons.album_rounded,
        label: 'Favorite album',
        value: topAlbum?.title ?? 'None',
        detail: topAlbum == null
            ? 'No plays yet'
            : '${number.format(topAlbum.playCount)} plays',
      ),
      _OverviewInsightValue(
        icon: Icons.history_rounded,
        label: 'Recent 30d',
        value: number.format(recentTrackCount),
        detail: _percentageDetail(recentTrackCount, overview.totalTracks),
      ),
      _OverviewInsightValue(
        icon: Icons.radio_button_unchecked_rounded,
        label: 'Unplayed',
        value: number.format(unplayedTrackCount),
        detail: _percentageDetail(unplayedTrackCount, overview.totalTracks),
      ),
      _OverviewInsightValue(
        icon: Icons.repeat_rounded,
        label: 'Avg plays',
        value: averagePlays.toStringAsFixed(1),
        detail: 'per track',
      ),
      _OverviewInsightValue(
        icon: Icons.cloud_rounded,
        label: 'Cloud items',
        value: number.format(cloudTrackCount),
        detail: _percentageDetail(cloudTrackCount, overview.totalTracks),
      ),
    ];

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x4FFFFFFF),
      borderOpacity: 0.34,
      shadowOpacity: 0.045,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            icon: Icons.insights_rounded,
            title: 'Listening insights',
            subtitle: 'Different cuts of the current library scan',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 3
                  : constraints.maxWidth >= 460
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: insights.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: columns == 1 ? 3.7 : 2.05,
                ),
                itemBuilder: (context, index) =>
                    _OverviewInsightTile(value: insights[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewBreakdownPanel extends StatelessWidget {
  const _OverviewBreakdownPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artistRows = _rankingBreakdownRows(
      overview.topArtists,
      theme.colorScheme.primary,
    );
    final genreRows = _genreBreakdownRows(overview.tracks, theme);
    final sourceRows = _sourceBreakdownRows(overview.tracks, theme);

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x4FFFFFFF),
      borderOpacity: 0.34,
      shadowOpacity: 0.045,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            icon: Icons.bar_chart_rounded,
            title: 'Library distribution',
            subtitle: 'Where plays and tracks are concentrated',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final sections = [
                _BreakdownSection(
                  title: 'Top artists',
                  emptyLabel: 'No artist play data yet.',
                  rows: artistRows,
                ),
                _BreakdownSection(
                  title: 'Genres',
                  emptyLabel: 'No genre metadata was returned.',
                  rows: genreRows,
                ),
                _BreakdownSection(
                  title: 'Source',
                  emptyLabel: 'No source data yet.',
                  rows: sourceRows,
                ),
              ];

              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sections
                      .map(
                        (section) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: section,
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Column(
                children: sections
                    .map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: section,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewInsightTile extends StatelessWidget {
  const _OverviewInsightTile({required this.value});

  final _OverviewInsightValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.48,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                value.icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({
    required this.title,
    required this.emptyLabel,
    required this.rows,
  });

  final String title;
  final String emptyLabel;
  final List<_BreakdownValue> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProportionalBarRow(value: row),
            ),
          ),
      ],
    );
  }
}

class _ProportionalBarRow extends StatelessWidget {
  const _ProportionalBarRow({required this.value});

  final _BreakdownValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                value.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value.trailing,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: ColoredBox(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.ratio.clamp(0.04, 1.0),
                child: SizedBox(
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: value.color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingPanel extends ConsumerWidget {
  const _RankingPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(rankingScopeProvider);
    final entries = overview.entriesFor(scope);
    final focus = ref.watch(rankingFocusProvider);
    final visibleCount = ref.watch(
      rankingVisibleCountProvider.select(
        (counts) => counts[scope] ?? RankingVisibleCountController.initialCount,
      ),
    );
    final theme = Theme.of(context);
    final scopedFocus = focus?.scope == scope ? focus : null;
    final visibleEntries = _visibleRankingEntries(
      entries,
      scopedFocus,
      visibleCount,
    );

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 26,
      tint: const Color(0x62FFFFFF),
      borderOpacity: 0.58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rankingTitle(context, scope),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _rankingSubtitle(context, scope),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  ref
                      .read(musicStatsControllerProvider.notifier)
                      .refreshStats();
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<RankingScope>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                ),
                side: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return BorderSide(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.55)
                        : theme.colorScheme.outlineVariant,
                  );
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.primary.withValues(alpha: 0.12);
                  }
                  return Colors.white.withValues(alpha: 0.22);
                }),
              ),
              segments: RankingScope.values
                  .map(
                    (value) => ButtonSegment<RankingScope>(
                      value: value,
                      label: Text(_rankingScopeLabel(context, value)),
                    ),
                  )
                  .toList(),
              selected: {scope},
              onSelectionChanged: (selection) {
                ref.read(rankingFocusProvider.notifier).clear();
                ref
                    .read(rankingScopeProvider.notifier)
                    .setScope(selection.first);
              },
            ),
          ),
          const SizedBox(height: 14),
          _RankingList(
            overview: overview,
            scope: scope,
            entries: visibleEntries,
            showLastPlayedAt: scope == RankingScope.recent,
            focus: scopedFocus,
          ),
          if (visibleEntries.length < entries.length) ...[
            const SizedBox(height: 12),
            _LoadMoreButton(
              shownCount: visibleEntries.length,
              totalCount: entries.length,
              nextCount: RankingVisibleCountController.loadMoreCount,
              onPressed: () {
                ref
                    .read(rankingVisibleCountProvider.notifier)
                    .loadMore(scope, entries.length);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _LibrarySection extends StatefulWidget {
  const _LibrarySection({required this.overview});

  final LibraryOverview overview;

  @override
  State<_LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends State<_LibrarySection> {
  static const _initialVisibleCount = 18;
  static const _loadMoreCount = 18;

  final _searchController = TextEditingController();
  _LibraryBrowseMode _mode = _LibraryBrowseMode.songs;
  _LibrarySortMode _sort = _LibrarySortMode.recent;
  String _query = '';
  int _visibleCount = _initialVisibleCount;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LibrarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overview != widget.overview) {
      final totalCount = _currentResultCount(widget.overview);
      _visibleCount = _clampInt(
        _visibleCount,
        _initialVisibleCount,
        totalCount,
      );
    }
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _visibleCount = _initialVisibleCount;
    });
  }

  void _clearQuery() {
    _searchController.clear();
    _setQuery('');
  }

  void _setMode(_LibraryBrowseMode mode) {
    setState(() {
      _mode = mode;
      _visibleCount = _initialVisibleCount;
    });
  }

  void _setSort(_LibrarySortMode sort) {
    setState(() {
      _sort = sort;
      _visibleCount = _initialVisibleCount;
    });
  }

  void _loadMore() {
    setState(() {
      _visibleCount = _clampInt(
        _visibleCount + _loadMoreCount,
        _initialVisibleCount,
        _currentResultCount(widget.overview),
      );
    });
  }

  int _currentResultCount(LibraryOverview overview) {
    final tracks = _filteredLibraryTracks(overview.tracks, _query);
    if (_mode == _LibraryBrowseMode.songs) {
      return tracks.length;
    }
    return _libraryGroupsForMode(_mode, tracks, _sort).length;
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    if (!overview.hasTracks) {
      return const _EmptyLibraryPanel();
    }

    final filteredTracks = _filteredLibraryTracks(overview.tracks, _query);
    final sortedTracks = _sortLibraryTracks(filteredTracks, _sort);
    final groups = _mode == _LibraryBrowseMode.songs
        ? const <_LibraryGroupEntry>[]
        : _libraryGroupsForMode(_mode, filteredTracks, _sort);
    final totalCount = _mode == _LibraryBrowseMode.songs
        ? sortedTracks.length
        : groups.length;
    final shownCount = _clampInt(_visibleCount, 0, totalCount);
    final visibleTracks = sortedTracks.take(shownCount).toList(growable: false);
    final visibleGroups = groups.take(shownCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibraryStatsPanel(overview: overview),
        const SizedBox(height: 14),
        _LibrarySearchPanel(
          controller: _searchController,
          query: _query,
          mode: _mode,
          sort: _sort,
          resultCount: totalCount,
          onQueryChanged: _setQuery,
          onClearQuery: _clearQuery,
          onModeChanged: _setMode,
          onSortChanged: _setSort,
        ),
        const SizedBox(height: 14),
        if (_mode == _LibraryBrowseMode.songs)
          _LibraryTrackPanel(
            tracks: visibleTracks,
            totalCount: totalCount,
            nextCount: _loadMoreCount,
            onLoadMore: _loadMore,
          )
        else
          _LibraryGroupPanel(
            mode: _mode,
            groups: visibleGroups,
            totalCount: totalCount,
            nextCount: _loadMoreCount,
            onLoadMore: _loadMore,
          ),
      ],
    );
  }
}

class _LibrarySearchPanel extends StatelessWidget {
  const _LibrarySearchPanel({
    required this.controller,
    required this.query,
    required this.mode,
    required this.sort,
    required this.resultCount,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onModeChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final String query;
  final _LibraryBrowseMode mode;
  final _LibrarySortMode sort;
  final int resultCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<_LibraryBrowseMode> onModeChanged;
  final ValueChanged<_LibrarySortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x5EFFFFFF),
      borderOpacity: 0.42,
      shadowOpacity: 0.04,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            icon: Icons.search_rounded,
            title: _t(context, 'Library browser', 'ライブラリ'),
            subtitle: _t(
              context,
              '${number.format(resultCount)} ${_libraryBrowseModeLabel(context, mode).toLowerCase()} matched',
              '${number.format(resultCount)}件の${_libraryBrowseModeLabel(context, mode)}',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _t(
                context,
                'Search songs, artists, albums, or genres',
                '曲、アーティスト、アルバム、ジャンルを検索',
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearQuery,
                      tooltip: _t(context, 'Clear search', '検索をクリア'),
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.48,
                  ),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final modeControl = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_LibraryBrowseMode>(
                  showSelectedIcon: false,
                  segments: _LibraryBrowseMode.values
                      .map(
                        (value) => ButtonSegment<_LibraryBrowseMode>(
                          value: value,
                          icon: Icon(value.icon, size: 18),
                          label: Text(_libraryBrowseModeLabel(context, value)),
                        ),
                      )
                      .toList(),
                  selected: {mode},
                  onSelectionChanged: (selection) {
                    onModeChanged(selection.first);
                  },
                ),
              );
              final sortControl = DropdownButtonFormField<_LibrarySortMode>(
                initialValue: sort,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t(context, 'Sort', '並び替え'),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.44),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: _LibrarySortMode.values
                    .map(
                      (value) => DropdownMenuItem<_LibrarySortMode>(
                        value: value,
                        child: Text(_librarySortModeLabel(context, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onSortChanged(value);
                  }
                },
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    modeControl,
                    const SizedBox(height: 12),
                    sortControl,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: modeControl),
                  const SizedBox(width: 14),
                  SizedBox(width: 220, child: sortControl),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LibraryTrackPanel extends StatelessWidget {
  const _LibraryTrackPanel({
    required this.tracks,
    required this.totalCount,
    required this.nextCount,
    required this.onLoadMore,
  });

  final List<LibraryTrack> tracks;
  final int totalCount;
  final int nextCount;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x5EFFFFFF),
      borderOpacity: 0.42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            icon: Icons.queue_music_rounded,
            title: 'Songs',
            subtitle: 'Searchable track details with play controls',
          ),
          const SizedBox(height: 12),
          if (totalCount == 0)
            Text(
              'No songs matched the current search.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            ...tracks.map((track) => _LibraryTrackRow(track: track)),
            if (tracks.length < totalCount) ...[
              const SizedBox(height: 10),
              _LoadMoreButton(
                shownCount: tracks.length,
                totalCount: totalCount,
                nextCount: nextCount,
                onPressed: onLoadMore,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LibraryTrackRow extends ConsumerWidget {
  const _LibraryTrackRow({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final artwork = ref.watch(trackArtworkProvider(track.id));
    final playback = ref.watch(playbackControllerProvider);
    final busy = playback.isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showTrackDetailSheet(context, track),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 50,
                  child: _TrackArtworkImage(track: track, artwork: artwork),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artist} - ${track.albumTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _MiniStatLabel(
                          icon: Icons.play_arrow_rounded,
                          value: number.format(track.playCount),
                        ),
                        _MiniStatLabel(
                          icon: Icons.fast_forward_rounded,
                          value: number.format(track.skipCount),
                        ),
                        _MiniStatLabel(
                          icon: Icons.schedule_rounded,
                          value: _shortPlayedAtLabel(track.lastPlayedAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: busy
                    ? null
                    : () {
                        ref
                            .read(playbackControllerProvider.notifier)
                            .playTrack(track.id);
                      },
                tooltip: 'Play',
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryGroupPanel extends StatelessWidget {
  const _LibraryGroupPanel({
    required this.mode,
    required this.groups,
    required this.totalCount,
    required this.nextCount,
    required this.onLoadMore,
  });

  final _LibraryBrowseMode mode;
  final List<_LibraryGroupEntry> groups;
  final int totalCount;
  final int nextCount;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x5EFFFFFF),
      borderOpacity: 0.42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            icon: mode.icon,
            title: _libraryBrowseModeLabel(context, mode),
            subtitle: _t(
              context,
              'Grouped library content with drill-down details',
              'グループごとの詳細へ移動できます',
            ),
          ),
          const SizedBox(height: 12),
          if (totalCount == 0)
            Text(
              _t(
                context,
                'No ${_libraryBrowseModeLabel(context, mode).toLowerCase()} matched the current search.',
                '現在の検索に一致する${_libraryBrowseModeLabel(context, mode)}はありません。',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            ...groups.map((group) => _LibraryGroupRow(group: group)),
            if (groups.length < totalCount) ...[
              const SizedBox(height: 10),
              _LoadMoreButton(
                shownCount: groups.length,
                totalCount: totalCount,
                nextCount: nextCount,
                onPressed: onLoadMore,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LibraryGroupRow extends ConsumerWidget {
  const _LibraryGroupRow({required this.group});

  final _LibraryGroupEntry group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final representative = group.representativeTrack;
    final artwork = representative == null
        ? const AsyncData<Uint8List?>(null)
        : ref.watch(trackArtworkProvider(representative.id));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showTrackGroupSheet(
          context,
          title: group.title,
          subtitle: group.subtitle,
          icon: group.icon,
          tracks: group.tracks,
          rankingScope: group.rankingScope,
          rankingTitle: group.rankingTitle,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  group.rankingScope == RankingScope.artists ? 999 : 12,
                ),
                child: SizedBox.square(
                  dimension: 50,
                  child: representative == null
                      ? ColoredBox(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                          child: Icon(
                            group.icon,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : _TrackArtworkImage(
                          track: representative,
                          artwork: artwork,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    number.format(group.playCount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${group.trackCount} tracks',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatLabel extends StatelessWidget {
  const _MiniStatLabel({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LibraryStatsPanel extends StatelessWidget {
  const _LibraryStatsPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x62FFFFFF),
      child: Row(
        children: [
          Expanded(
            child: _InlineMetric(
              label: 'Artists',
              value: number.format(overview.totalArtists),
              icon: Icons.person,
            ),
          ),
          Expanded(
            child: _InlineMetric(
              label: 'Albums',
              value: number.format(overview.totalAlbums),
              icon: Icons.album,
            ),
          ),
          Expanded(
            child: _InlineMetric(
              label: 'Tracks',
              value: number.format(overview.totalTracks),
              icon: Icons.music_note,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EntryPanel extends StatefulWidget {
  const _EntryPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<RankingEntry> entries;

  @override
  State<_EntryPanel> createState() => _EntryPanelState();
}

class _EntryPanelState extends State<_EntryPanel> {
  static const _initialVisibleCount = 6;
  static const _loadMoreCount = 6;

  int _visibleCount = _initialVisibleCount;

  @override
  void didUpdateWidget(covariant _EntryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries &&
        _visibleCount > widget.entries.length) {
      _visibleCount = _clampInt(
        _visibleCount,
        _initialVisibleCount,
        widget.entries.length,
      );
    }
  }

  void _loadMore() {
    setState(() {
      _visibleCount = _clampInt(
        _visibleCount + _loadMoreCount,
        _initialVisibleCount,
        widget.entries.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleEntries = widget.entries
        .take(_visibleCount)
        .toList(growable: false);
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x5EFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.entries.isEmpty)
            Text(
              'No entries yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            ...visibleEntries.indexed.map(
              (indexed) =>
                  _CompactEntryRow(rank: indexed.$1 + 1, entry: indexed.$2),
            ),
            if (visibleEntries.length < widget.entries.length) ...[
              const SizedBox(height: 8),
              _LoadMoreButton(
                shownCount: visibleEntries.length,
                totalCount: widget.entries.length,
                nextCount: _loadMoreCount,
                onPressed: _loadMore,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompactEntryRow extends StatelessWidget {
  const _CompactEntryRow({required this.rank, required this.entry});

  final int rank;
  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            number.format(entry.playCount),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.shownCount,
    required this.totalCount,
    required this.nextCount,
    required this.onPressed,
  });

  final int shownCount;
  final int totalCount;
  final int nextCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final remainingCount = totalCount - shownCount;
    final actualNextCount = _clampInt(nextCount, 0, remainingCount);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: remainingCount <= 0 ? null : onPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'さらに${number.format(actualNextCount)}件表示',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overview = stats.overview;
    final selectedTheme = ref.watch(themeStyleProvider);
    final selectedLanguage = ref.watch(appLanguageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo) ...[
          _AuthorizationPanel(status: stats.authorizationStatus),
          const SizedBox(height: 14),
        ],
        GlassSurface(
          padding: const EdgeInsets.all(18),
          radius: 24,
          tint: const Color(0x62FFFFFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'Music Access', 'ミュージックアクセス'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _SettingsRow(
                icon: Icons.privacy_tip,
                label: _t(context, 'Authorization', '認証状態'),
                value: overview.isDemo
                    ? _t(context, 'Demo mode', 'デモモード')
                    : stats.authorizationStatus.label,
              ),
              _SettingsRow(
                icon: Icons.storage,
                label: _t(context, 'Data source', 'データソース'),
                value: overview.isDemo
                    ? _t(context, 'Sample library', 'サンプルライブラリ')
                    : _t(context, 'iOS Music library', 'iOSミュージックライブラリ'),
              ),
              _SettingsRow(
                icon: Icons.update,
                label: _t(context, 'Snapshot', 'スナップショット'),
                value: DateFormat.yMMMd().add_Hm().format(overview.generatedAt),
              ),
              const SizedBox(height: 16),
              Text(
                _t(context, 'Theme', 'テーマ'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<SongBriefThemeStyle>(
                  showSelectedIcon: false,
                  segments: SongBriefThemeStyle.values
                      .map(
                        (style) => ButtonSegment<SongBriefThemeStyle>(
                          value: style,
                          label: Text(style.label),
                        ),
                      )
                      .toList(),
                  selected: {selectedTheme},
                  onSelectionChanged: (selection) {
                    ref
                        .read(themeStyleProvider.notifier)
                        .setStyle(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedTheme.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _t(context, 'Language', '言語'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppLanguage>(
                  showSelectedIcon: false,
                  segments: AppLanguage.values
                      .map(
                        (language) => ButtonSegment<AppLanguage>(
                          value: language,
                          label: Text(language.label),
                        ),
                      )
                      .toList(),
                  selected: {selectedLanguage},
                  onSelectionChanged: (selection) {
                    ref
                        .read(appLanguageProvider.notifier)
                        .setLanguage(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _t(context, 'App Info', 'アプリ情報'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.info_outline,
                label: _t(context, 'Application', 'アプリケーション'),
                value: 'SongBrief',
              ),
              _SettingsRow(
                icon: Icons.sell_outlined,
                label: _t(context, 'Version', 'バージョン'),
                value: _appVersionLabel,
              ),
              _SettingsRow(
                icon: Icons.extension_outlined,
                label: _t(context, 'Libraries', 'ライブラリ'),
                value: _librarySummaryLabel,
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: _t(context, 'Privacy Policy', 'プライバシーポリシー'),
                value: _t(context, 'Open', '開く'),
                onTap: () => _openExternalUrl(context, _privacyPolicyUrl),
              ),
              _SettingsRow(
                icon: Icons.gavel_outlined,
                label: _t(context, 'Terms of Use', '利用規約'),
                value: _t(context, 'Open', '開く'),
                onTap: () => _openExternalUrl(context, _termsOfUseUrl),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _showLibrariesSheet(context);
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(_t(context, 'Libraries', 'ライブラリ')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'SongBrief',
                        applicationVersion: _appVersionLabel,
                        applicationIcon: Icon(
                          Icons.graphic_eq_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: Text(_t(context, 'Licenses', 'ライセンス')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    ref
                        .read(musicStatsControllerProvider.notifier)
                        .refreshStats();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(_t(context, 'Refresh', '更新')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      return;
    }
  } on Exception {
    // Fall through to the user-facing error below.
  }

  if (!context.mounted) {
    return;
  }

  messenger?.showSnackBar(SnackBar(content: Text('Could not open $url')));
}

void _showLibrariesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _LibrariesSheet(),
  );
}

class _LibrariesSheet extends StatelessWidget {
  const _LibrariesSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Libraries', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ..._usedLibraries.map(
              (library) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(library, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onTap == null ? null : theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: content,
    );
  }
}

class _RankingList extends StatefulWidget {
  const _RankingList({
    required this.overview,
    required this.scope,
    required this.entries,
    required this.showLastPlayedAt,
    required this.focus,
  });

  final LibraryOverview overview;
  final RankingScope scope;
  final List<RankingEntry> entries;
  final bool showLastPlayedAt;
  final RankingFocus? focus;

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList> {
  final _focusedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scheduleFocusedScroll();
  }

  @override
  void didUpdateWidget(covariant _RankingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus ||
        oldWidget.scope != widget.scope ||
        oldWidget.entries != widget.entries) {
      _scheduleFocusedScroll();
    }
  }

  void _scheduleFocusedScroll() {
    if (_focusedIndex() < 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _focusedRowKey.currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.34,
      );
    });
  }

  int _focusedIndex() {
    final focus = widget.focus;
    if (focus == null || focus.scope != widget.scope) {
      return -1;
    }
    return widget.entries.indexWhere(
      (entry) => _entryMatchesFocus(entry, focus),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final focusedIndex = _focusedIndex();
    final maxPlayCount = widget.entries
        .map((entry) => entry.playCount)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: widget.entries.indexed
          .map(
            (indexed) => _RankingRow(
              rank: indexed.$1 + 1,
              rowKey: indexed.$1 == focusedIndex ? _focusedRowKey : null,
              overview: widget.overview,
              scope: widget.scope,
              entry: indexed.$2,
              maxPlayCount: maxPlayCount,
              showLastPlayedAt: widget.showLastPlayedAt,
              isFocused: indexed.$1 == focusedIndex,
            ),
          )
          .toList(),
    );
  }
}

class _RankingRow extends ConsumerWidget {
  const _RankingRow({
    required this.rank,
    required this.rowKey,
    required this.overview,
    required this.scope,
    required this.entry,
    required this.maxPlayCount,
    required this.showLastPlayedAt,
    required this.isFocused,
  });

  final int rank;
  final Key? rowKey;
  final LibraryOverview overview;
  final RankingScope scope;
  final RankingEntry entry;
  final int maxPlayCount;
  final bool showLastPlayedAt;
  final bool isFocused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final ratio = maxPlayCount == 0 ? 0.0 : entry.playCount / maxPlayCount;
    final barColor = Color.lerp(
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      (rank - 1) / 12,
    )!;
    final track = overview.trackById(entry.representativeTrackId);
    final artwork = track == null
        ? const AsyncData<Uint8List?>(null)
        : ref.watch(trackArtworkProvider(track.id));

    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: isFocused
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFocused
                ? theme.colorScheme.primary.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: track == null
              ? null
              : () => _showTrackDetailSheet(context, track),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: rank <= 3
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.18,
                                )
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        '$rank',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: rank <= 3
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RankingArtwork(
                      entry: entry,
                      track: track,
                      artwork: artwork,
                      scope: scope,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            showLastPlayedAt && entry.lastPlayedAt != null
                                ? DateFormat.yMMMd().add_Hm().format(
                                    entry.lastPlayedAt!,
                                  )
                                : entry.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      number.format(entry.playCount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: ColoredBox(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.36,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio.clamp(0.04, 1.0),
                        child: SizedBox(
                          height: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: barColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingArtwork extends StatelessWidget {
  const _RankingArtwork({
    required this.entry,
    required this.track,
    required this.artwork,
    required this.scope,
  });

  final RankingEntry entry;
  final LibraryTrack? track;
  final AsyncValue<Uint8List?> artwork;
  final RankingScope scope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = artwork.asData?.value;
    final asset = track?.artworkAsset;
    final isArtist = scope == RankingScope.artists;
    final radius = BorderRadius.circular(isArtist ? 999 : 12);

    final Widget child;
    if (bytes != null) {
      child = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (asset != null) {
      child = Image.asset(asset, fit: BoxFit.cover);
    } else {
      child = ColoredBox(
        color: theme.colorScheme.primary.withValues(alpha: 0.14),
        child: Center(
          child: Text(
            entry.title.isEmpty ? '?' : entry.title.substring(0, 1),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(dimension: 46, child: child),
    );
  }
}

class _EmptyLibraryPanel extends StatelessWidget {
  const _EmptyLibraryPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      child: Row(
        children: [
          Icon(Icons.album, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No Music library songs were returned by iOS.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Could not load the music library.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const SizedBox.expand(),
    );
  }
}

void _focusTrackInRanking(
  BuildContext context,
  WidgetRef ref,
  LibraryTrack track, {
  bool closeCurrentRoute = false,
}) {
  ref.read(rankingScopeProvider.notifier).setScope(RankingScope.tracks);
  ref.read(rankingFocusProvider.notifier).focus(RankingFocus.track(track.id));
  ref.read(homeSectionProvider.notifier).setSection(HomeSection.rankings);
  if (closeCurrentRoute) {
    Navigator.of(context).pop();
  }
}

void _focusRankingEntry(
  BuildContext context,
  WidgetRef ref, {
  required RankingScope scope,
  required String title,
  bool closeAllRoutes = false,
}) {
  ref.read(rankingScopeProvider.notifier).setScope(scope);
  ref
      .read(rankingFocusProvider.notifier)
      .focus(RankingFocus.entry(scope: scope, title: title));
  ref.read(homeSectionProvider.notifier).setSection(HomeSection.rankings);
  if (closeAllRoutes) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

List<RankingEntry> _visibleRankingEntries(
  List<RankingEntry> entries,
  RankingFocus? focus,
  int requestedCount,
) {
  final minimumVisibleEntries = RankingVisibleCountController.initialCount;
  final baseVisibleCount = _clampInt(
    requestedCount,
    minimumVisibleEntries,
    entries.length,
  );
  if (focus == null) {
    return entries.take(baseVisibleCount).toList(growable: false);
  }

  final focusIndex = entries.indexWhere(
    (entry) => _entryMatchesFocus(entry, focus),
  );
  final visibleCount = focusIndex < 0
      ? baseVisibleCount
      : _clampInt(focusIndex + 1, baseVisibleCount, entries.length);
  return entries.take(visibleCount).toList(growable: false);
}

int _clampInt(int value, int minimum, int maximum) {
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return value;
}

bool _entryMatchesFocus(RankingEntry entry, RankingFocus focus) {
  if (focus.scope != RankingScope.tracks &&
      focus.scope != RankingScope.recent) {
    return entry.title == focus.title;
  }
  final trackId = focus.trackId;
  return trackId != null && entry.representativeTrackId == trackId;
}

List<LibraryTrack> _tracksByArtist(LibraryOverview overview, String artist) {
  return _sortedDrilldownTracks(
    overview.tracks.where((track) => track.artist == artist),
  );
}

List<LibraryTrack> _tracksByAlbumArtist(
  LibraryOverview overview,
  String albumArtist,
) {
  return _sortedDrilldownTracks(
    overview.tracks.where(
      (track) => (track.albumArtist ?? track.artist) == albumArtist,
    ),
  );
}

List<LibraryTrack> _tracksByAlbum(
  LibraryOverview overview,
  LibraryTrack album,
) {
  final albumArtist = album.albumArtist ?? album.artist;
  return _sortedDrilldownTracks(
    overview.tracks.where(
      (track) =>
          track.albumTitle == album.albumTitle &&
          (track.albumArtist ?? track.artist) == albumArtist,
    ),
  );
}

List<LibraryTrack> _tracksByGenre(LibraryOverview overview, String genre) {
  return _sortedDrilldownTracks(
    overview.tracks.where((track) => track.genre == genre),
  );
}

List<LibraryTrack> _sortedDrilldownTracks(Iterable<LibraryTrack> tracks) {
  final sorted = tracks.toList()
    ..sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      if (byPlays != 0) {
        return byPlays;
      }
      return a.title.compareTo(b.title);
    });
  return List.unmodifiable(sorted);
}

String _albumRankingTitle(LibraryTrack track) {
  return '${track.albumArtist ?? track.artist} - ${track.albumTitle}';
}

int _recentlyPlayedCount(List<LibraryTrack> tracks, Duration window) {
  final threshold = DateTime.now().subtract(window);
  return tracks.where((track) {
    final playedAt = track.lastPlayedAt;
    return playedAt != null && !playedAt.isBefore(threshold);
  }).length;
}

String _percentageDetail(int value, int total) {
  if (total <= 0) {
    return '0% of tracks';
  }
  return '${(value / total * 100).toStringAsFixed(1)}% of tracks';
}

List<_BreakdownValue> _rankingBreakdownRows(
  List<RankingEntry> entries,
  Color baseColor,
) {
  final visible = entries.take(5).toList(growable: false);
  if (visible.isEmpty) {
    return const [];
  }

  final maxValue = visible
      .map((entry) => entry.playCount)
      .reduce((a, b) => a > b ? a : b);
  return visible.indexed
      .map(
        (indexed) => _BreakdownValue(
          label: indexed.$2.title,
          trailing: '${_compactNumber(indexed.$2.playCount)} plays',
          ratio: maxValue == 0 ? 0 : indexed.$2.playCount / maxValue,
          color: Color.lerp(baseColor, Colors.white, indexed.$1 * 0.08)!,
        ),
      )
      .toList(growable: false);
}

List<_BreakdownValue> _genreBreakdownRows(
  List<LibraryTrack> tracks,
  ThemeData theme,
) {
  final groups = <String, _LibraryGroupAccumulator>{};
  for (final track in tracks) {
    final genre = track.genre;
    if (genre == null || genre.trim().isEmpty) {
      continue;
    }
    groups
        .putIfAbsent(
          genre,
          () => _LibraryGroupAccumulator(
            key: genre,
            title: genre,
            subtitle: 'Genre',
            icon: Icons.category_rounded,
          ),
        )
        .add(track);
  }

  final values = groups.values.map((group) => group.toEntry()).toList()
    ..sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      if (byPlays != 0) {
        return byPlays;
      }
      return b.trackCount.compareTo(a.trackCount);
    });
  final visible = values.take(5).toList(growable: false);
  if (visible.isEmpty) {
    return const [];
  }

  final maxValue = visible
      .map((entry) => entry.playCount == 0 ? entry.trackCount : entry.playCount)
      .reduce((a, b) => a > b ? a : b);
  return visible.indexed
      .map((indexed) {
        final value = indexed.$2.playCount == 0
            ? indexed.$2.trackCount
            : indexed.$2.playCount;
        return _BreakdownValue(
          label: indexed.$2.title,
          trailing: indexed.$2.playCount == 0
              ? '${indexed.$2.trackCount} tracks'
              : '${_compactNumber(indexed.$2.playCount)} plays',
          ratio: maxValue == 0 ? 0 : value / maxValue,
          color: Color.lerp(
            theme.colorScheme.secondary,
            Colors.white,
            indexed.$1 * 0.08,
          )!,
        );
      })
      .toList(growable: false);
}

List<_BreakdownValue> _sourceBreakdownRows(
  List<LibraryTrack> tracks,
  ThemeData theme,
) {
  if (tracks.isEmpty) {
    return const [];
  }

  final cloudCount = tracks.where((track) => track.isCloudItem).length;
  final localCount = tracks.length - cloudCount;
  final rows = [
    ('Local', localCount, theme.colorScheme.tertiary),
    ('Cloud', cloudCount, theme.colorScheme.primary),
  ].where((row) => row.$2 > 0).toList(growable: false);

  return rows
      .map(
        (row) => _BreakdownValue(
          label: row.$1,
          trailing: '${row.$2} tracks',
          ratio: row.$2 / tracks.length,
          color: row.$3,
        ),
      )
      .toList(growable: false);
}

List<LibraryTrack> _filteredLibraryTracks(
  List<LibraryTrack> tracks,
  String query,
) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) {
    return tracks;
  }

  return tracks
      .where((track) {
        final fields = [
          track.title,
          track.artist,
          track.albumTitle,
          track.albumArtist,
          track.genre,
        ];
        return fields.whereType<String>().any(
          (field) => _normalizeSearchText(field).contains(normalizedQuery),
        );
      })
      .toList(growable: false);
}

List<LibraryTrack> _sortLibraryTracks(
  Iterable<LibraryTrack> tracks,
  _LibrarySortMode sort,
) {
  final sorted = tracks.toList(growable: false);
  sorted.sort((a, b) {
    final primary = switch (sort) {
      _LibrarySortMode.recent => _compareDateDesc(
        a.lastPlayedAt,
        b.lastPlayedAt,
      ),
      _LibrarySortMode.plays => b.playCount.compareTo(a.playCount),
      _LibrarySortMode.skips => b.skipCount.compareTo(a.skipCount),
      _LibrarySortMode.title => _normalizeSearchText(
        a.title,
      ).compareTo(_normalizeSearchText(b.title)),
    };
    if (primary != 0) {
      return primary;
    }
    final byTitle = _normalizeSearchText(
      a.title,
    ).compareTo(_normalizeSearchText(b.title));
    if (byTitle != 0) {
      return byTitle;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
}

List<_LibraryGroupEntry> _libraryGroupsForMode(
  _LibraryBrowseMode mode,
  List<LibraryTrack> tracks,
  _LibrarySortMode sort,
) {
  if (mode == _LibraryBrowseMode.songs) {
    return const [];
  }

  final groups = <String, _LibraryGroupAccumulator>{};
  for (final track in tracks) {
    final accumulator = switch (mode) {
      _LibraryBrowseMode.songs => null,
      _LibraryBrowseMode.artists => groups.putIfAbsent(
        track.artist,
        () => _LibraryGroupAccumulator(
          key: track.artist,
          title: track.artist,
          subtitle: 'Artist',
          icon: Icons.person_rounded,
          rankingScope: RankingScope.artists,
          rankingTitle: track.artist,
        ),
      ),
      _LibraryBrowseMode.albums => groups.putIfAbsent(
        _albumRankingTitle(track),
        () => _LibraryGroupAccumulator(
          key: _albumRankingTitle(track),
          title: track.albumTitle,
          subtitle: track.albumArtist ?? track.artist,
          icon: Icons.album_rounded,
          rankingScope: RankingScope.albums,
          rankingTitle: _albumRankingTitle(track),
        ),
      ),
      _LibraryBrowseMode.genres =>
        track.genre == null || track.genre!.trim().isEmpty
            ? null
            : groups.putIfAbsent(
                track.genre!,
                () => _LibraryGroupAccumulator(
                  key: track.genre!,
                  title: track.genre!,
                  subtitle: 'Genre',
                  icon: Icons.category_rounded,
                ),
              ),
    };
    accumulator?.add(track);
  }

  final entries = groups.values.map((group) => group.toEntry()).toList();
  entries.sort((a, b) {
    final primary = switch (sort) {
      _LibrarySortMode.recent => _compareDateDesc(
        a.lastPlayedAt,
        b.lastPlayedAt,
      ),
      _LibrarySortMode.plays => b.playCount.compareTo(a.playCount),
      _LibrarySortMode.skips => b.skipCount.compareTo(a.skipCount),
      _LibrarySortMode.title => _normalizeSearchText(
        a.title,
      ).compareTo(_normalizeSearchText(b.title)),
    };
    if (primary != 0) {
      return primary;
    }
    return _normalizeSearchText(
      a.title,
    ).compareTo(_normalizeSearchText(b.title));
  });
  return entries;
}

int _compareDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return b.compareTo(a);
}

String _normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}

class _OverviewInsightValue {
  const _OverviewInsightValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
}

class _BreakdownValue {
  const _BreakdownValue({
    required this.label,
    required this.trailing,
    required this.ratio,
    required this.color,
  });

  final String label;
  final String trailing;
  final double ratio;
  final Color color;
}

class _LibraryGroupEntry {
  const _LibraryGroupEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tracks,
    required this.playCount,
    required this.skipCount,
    required this.listeningSeconds,
    required this.lastPlayedAt,
    required this.representativeTrack,
    this.rankingScope,
    this.rankingTitle,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<LibraryTrack> tracks;
  final int playCount;
  final int skipCount;
  final int listeningSeconds;
  final DateTime? lastPlayedAt;
  final LibraryTrack? representativeTrack;
  final RankingScope? rankingScope;
  final String? rankingTitle;

  int get trackCount => tracks.length;
}

class _LibraryGroupAccumulator {
  _LibraryGroupAccumulator({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.rankingScope,
    this.rankingTitle,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final RankingScope? rankingScope;
  final String? rankingTitle;
  final List<LibraryTrack> tracks = [];

  void add(LibraryTrack track) {
    tracks.add(track);
  }

  _LibraryGroupEntry toEntry() {
    final sortedTracks = _sortLibraryTracks(tracks, _LibrarySortMode.plays);
    final playCount = tracks.fold<int>(
      0,
      (total, track) => total + track.playCount,
    );
    final skipCount = tracks.fold<int>(
      0,
      (total, track) => total + track.skipCount,
    );
    final listeningSeconds = tracks.fold<int>(
      0,
      (total, track) => total + track.listeningSeconds,
    );
    DateTime? lastPlayedAt;
    for (final track in tracks) {
      final playedAt = track.lastPlayedAt;
      if (playedAt != null &&
          (lastPlayedAt == null || playedAt.isAfter(lastPlayedAt))) {
        lastPlayedAt = playedAt;
      }
    }

    return _LibraryGroupEntry(
      title: title,
      subtitle: subtitle,
      icon: icon,
      tracks: List.unmodifiable(sortedTracks),
      playCount: playCount,
      skipCount: skipCount,
      listeningSeconds: listeningSeconds,
      lastPlayedAt: lastPlayedAt,
      representativeTrack: sortedTracks.isEmpty ? null : sortedTracks.first,
      rankingScope: rankingScope,
      rankingTitle: rankingTitle,
    );
  }
}

class _SummaryValue {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

const _appVersionLabel = '1.0.0+1';

const _librarySummaryLabel = 'Flutter, Riverpod, fl_chart, intl';

const _usedLibraries = <String>[
  'Flutter',
  'flutter_riverpod',
  'fl_chart',
  'intl',
  'liquid_glass_renderer',
  'shared_preferences',
  'url_launcher',
  'cupertino_icons',
  'flutter_lints',
  'flutter_native_splash',
  'flutter_launcher_icons',
];

String _hoursLabel(int listeningSeconds) {
  final hours = listeningSeconds / 3600;
  if (hours >= 100) {
    return NumberFormat.decimalPattern().format(hours.round());
  }
  return hours.toStringAsFixed(1);
}

String _snapshotSourceLabel(String source) {
  return switch (source) {
    'background' => 'background refresh',
    _ => 'app scan',
  };
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString();
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String _playedAtLabel(DateTime? dateTime) {
  if (dateTime == null) {
    return 'なし';
  }
  return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
}

String _shortPlayedAtLabel(DateTime? dateTime) {
  if (dateTime == null) {
    return 'なし';
  }
  final now = DateTime.now();
  if (dateTime.year == now.year &&
      dateTime.month == now.month &&
      dateTime.day == now.day) {
    return '今日 ${DateFormat('HH:mm').format(dateTime)}';
  }
  return DateFormat('M/d').format(dateTime);
}

List<int> _trendValues(LibraryTrack track, TrendRange range) {
  final base = (track.playCount * 92).clamp(1200, 42000);
  final multipliers = switch (range) {
    TrendRange.week => const [0.58, 0.69, 0.76, 0.62, 0.9, 1.0, 0.82],
    TrendRange.month => const [0.66, 0.72, 0.94, 0.86, 0.78, 1.0, 0.91],
    TrendRange.year => const [0.42, 0.55, 0.63, 0.74, 0.88, 0.96, 1.0],
  };
  return multipliers
      .map((multiplier) => (base * multiplier).round())
      .toList(growable: false);
}

List<String> _trendLabels(TrendRange range) {
  return switch (range) {
    TrendRange.week => const [
      '5/15',
      '5/16',
      '5/17',
      '5/18',
      '5/19',
      '5/20',
      '今日',
    ],
    TrendRange.month => const ['1週', '2週', '3週', '4週', '5週', '6週', '今週'],
    TrendRange.year => const ['1月', '2月', '3月', '4月', '5月', '6月', '今月'],
  };
}

String _compactNumber(int value) {
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}K';
  }
  return NumberFormat.decimalPattern().format(value);
}

String _trendRangeLabel(BuildContext context, TrendRange range) {
  return switch (range) {
    TrendRange.week => _t(context, '7 days', '7日間'),
    TrendRange.month => _t(context, '4 weeks', '4週間'),
    TrendRange.year => _t(context, '1 year', '1年間'),
  };
}

String _rankingScopeLabel(BuildContext context, RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => _t(context, 'Songs', '曲'),
    RankingScope.artists => _t(context, 'Artists', 'アーティスト'),
    RankingScope.albums => _t(context, 'Albums', 'アルバム'),
    RankingScope.recent => _t(context, 'Recent', '最近'),
  };
}

String _libraryBrowseModeLabel(BuildContext context, _LibraryBrowseMode mode) {
  return switch (mode) {
    _LibraryBrowseMode.songs => _t(context, 'Songs', '曲'),
    _LibraryBrowseMode.artists => _t(context, 'Artists', 'アーティスト'),
    _LibraryBrowseMode.albums => _t(context, 'Albums', 'アルバム'),
    _LibraryBrowseMode.genres => _t(context, 'Genres', 'ジャンル'),
  };
}

String _librarySortModeLabel(BuildContext context, _LibrarySortMode sort) {
  return switch (sort) {
    _LibrarySortMode.recent => _t(context, 'Recently played', '最近再生'),
    _LibrarySortMode.plays => _t(context, 'Most played', '再生回数順'),
    _LibrarySortMode.skips => _t(context, 'Most skipped', 'スキップ順'),
    _LibrarySortMode.title => _t(context, 'Title', 'タイトル'),
  };
}

String _rankingTitle(BuildContext context, RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => _t(context, 'Top Songs', 'トップ曲'),
    RankingScope.artists => _t(context, 'Top Artists', 'トップアーティスト'),
    RankingScope.albums => _t(context, 'Top Albums', 'トップアルバム'),
    RankingScope.recent => _t(context, 'Recently Played', '最近再生した曲'),
  };
}

String _rankingSubtitle(BuildContext context, RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => _t(context, 'Ranked by play count', '再生回数順'),
    RankingScope.artists => _t(
      context,
      'Aggregated across each artist',
      'アーティストごとの合計',
    ),
    RankingScope.albums => _t(
      context,
      'Aggregated across each album',
      'アルバムごとの合計',
    ),
    RankingScope.recent => _t(
      context,
      'Sorted by last played date',
      '最後に再生した日時順',
    ),
  };
}

List<NavigationDestination> _navigationDestinations(BuildContext context) {
  return HomeSection.values
      .map(
        (section) => NavigationDestination(
          icon: Icon(_sectionIcon(section)),
          selectedIcon: Icon(_sectionSelectedIcon(section)),
          label: _sectionLabel(context, section),
        ),
      )
      .toList();
}

String _sectionLabel(BuildContext context, HomeSection section) {
  return switch (section) {
    HomeSection.playing => _t(context, 'Playing', '再生中'),
    HomeSection.overview => _t(context, 'Overview', '概要'),
    HomeSection.rankings => _t(context, 'Rankings', 'ランキング'),
    HomeSection.library => _t(context, 'Library', 'ライブラリ'),
    HomeSection.settings => _t(context, 'Settings', '設定'),
  };
}

IconData _sectionIcon(HomeSection section) {
  return switch (section) {
    HomeSection.playing => Icons.play_circle_outline_rounded,
    HomeSection.overview => Icons.space_dashboard_outlined,
    HomeSection.rankings => Icons.leaderboard_outlined,
    HomeSection.library => Icons.library_music_outlined,
    HomeSection.settings => Icons.tune_outlined,
  };
}

IconData _sectionSelectedIcon(HomeSection section) {
  return switch (section) {
    HomeSection.playing => Icons.play_circle_rounded,
    HomeSection.overview => Icons.space_dashboard,
    HomeSection.rankings => Icons.leaderboard,
    HomeSection.library => Icons.library_music,
    HomeSection.settings => Icons.tune,
  };
}

String _sectionSubtitle(
  BuildContext context,
  HomeSection section,
  bool isDemo,
) {
  final source = isDemo
      ? _t(context, 'demo library', 'デモライブラリ')
      : _t(context, 'Music library', 'ミュージックライブラリ');
  return switch (section) {
    HomeSection.playing => _t(
      context,
      'Recent playback from the $source',
      '$source の直近再生トラック',
    ),
    HomeSection.overview => _t(
      context,
      'Overview of the $source',
      '$source の概要',
    ),
    HomeSection.rankings => _t(
      context,
      'Rankings from the $source',
      '$source のランキング',
    ),
    HomeSection.library => _t(context, 'Browse the $source', '$source のブラウズ'),
    HomeSection.settings => _t(
      context,
      'Access and scan settings',
      'アクセスとスキャン設定',
    ),
  };
}

// ignore: unused_element
String _legacySectionSubtitle(HomeSection section, bool isDemo) {
  final source = isDemo ? 'デモライブラリ' : 'Musicライブラリ';
  return switch (section) {
    HomeSection.playing => '$source の直近再生トラック',
    HomeSection.overview => '$source の概要',
    HomeSection.rankings => '$source のランキング',
    HomeSection.library => '$source のブラウズ',
    HomeSection.settings => 'アクセスとスキャン設定',
  };
}
