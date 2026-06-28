import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/library_overview.dart';
import '../../domain/library_track.dart';
import '../../domain/music_library_authorization.dart';
import '../../domain/music_stats_state.dart';
import 'home_controller.dart';
import 'widgets/glass_surface.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicStatsControllerProvider);
    final selectedSection = ref.watch(homeSectionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final hasData = state.hasValue;

        return Scaffold(
          backgroundColor: Colors.transparent,
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
      destinations: _navigationDestinations(),
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
    final track = stats.overview.latestTrack;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: GlassSurface(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
          radius: 30,
          tint: const Color(0x3AFFFFFF),
          borderOpacity: 0.16,
          shadowOpacity: 0.24,
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
            _MiniArtwork(artwork: artwork),
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
  const _MiniArtwork({required this.artwork});

  final AsyncValue<Uint8List?> artwork;

  @override
  Widget build(BuildContext context) {
    final bytes = artwork.asData?.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 38,
        child: bytes == null
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
                  label: Text(section.label),
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
                _sectionSubtitle(selectedSection, overview.isDemo),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo) ...[
          _AuthorizationPanel(status: stats.authorizationStatus),
          const SizedBox(height: 14),
        ],
        if (overview.isDemo) ...[
          const _DemoBanner(),
          const SizedBox(height: 14),
        ],
        _NowTrackPanel(track: track, artwork: artwork),
        const SizedBox(height: 14),
        _TrackDetailsPanel(track: track),
        if (overview.recentTracks.length > 1) ...[
          const SizedBox(height: 14),
          _EntryPanel(
            title: '最近再生',
            subtitle: 'ライブラリから取得した直近の曲',
            icon: Icons.history_rounded,
            entries: overview.recentTracks
                .skip(1)
                .take(5)
                .toList(growable: false),
            showLastPlayedAt: true,
          ),
        ],
      ],
    );
  }
}

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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.46),
                      theme.colorScheme.tertiary.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
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

class _TrackDetailsPanel extends StatelessWidget {
  const _TrackDetailsPanel({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TrackDetailRow(
          icon: Icons.album_outlined,
          label: 'アルバム',
          value: track.albumTitle,
        ),
        const SizedBox(height: 10),
        _TrackDetailRow(
          icon: Icons.mic_external_on_outlined,
          label: 'アルバムアーティスト',
          value: track.albumArtist ?? track.artist,
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
              ),
              _TrackStatCard(
                icon: Icons.fast_forward_outlined,
                label: 'スキップ',
                value: '${number.format(track.skipCount)} 回',
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
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
        ],
      ),
    );
  }
}

class _TrackStatCard extends StatelessWidget {
  const _TrackStatCard({
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
    return GlassSurface(
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
        ],
      ),
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
        _SummaryGrid(overview: overview),
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

class _RankingPanel extends ConsumerWidget {
  const _RankingPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(rankingScopeProvider);
    final entries = overview.entriesFor(scope);
    final theme = Theme.of(context);

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
                      _rankingTitle(scope),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _rankingSubtitle(scope),
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
                      label: Text(value.label),
                    ),
                  )
                  .toList(),
              selected: {scope},
              onSelectionChanged: (selection) {
                ref
                    .read(rankingScopeProvider.notifier)
                    .setScope(selection.first);
              },
            ),
          ),
          const SizedBox(height: 14),
          _RankingList(
            entries: entries.take(12).toList(growable: false),
            showLastPlayedAt: scope == RankingScope.recent,
          ),
        ],
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    if (!overview.hasTracks) {
      return const _EmptyLibraryPanel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibraryStatsPanel(overview: overview),
        const SizedBox(height: 14),
        _EntryPanel(
          title: 'Recently Played',
          subtitle: 'Latest tracks returned by iOS',
          icon: Icons.history,
          entries: overview.recentTracks.take(6).toList(growable: false),
          showLastPlayedAt: true,
        ),
        const SizedBox(height: 14),
        _EntryPanel(
          title: 'Top Albums',
          subtitle: 'Albums aggregated by play count',
          icon: Icons.album,
          entries: overview.topAlbums.take(6).toList(growable: false),
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

class _EntryPanel extends StatelessWidget {
  const _EntryPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
    this.showLastPlayedAt = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<RankingEntry> entries;
  final bool showLastPlayedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x5EFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'No entries yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...entries.indexed.map(
              (indexed) => _CompactEntryRow(
                rank: indexed.$1 + 1,
                entry: indexed.$2,
                showLastPlayedAt: showLastPlayedAt,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactEntryRow extends StatelessWidget {
  const _CompactEntryRow({
    required this.rank,
    required this.entry,
    required this.showLastPlayedAt,
  });

  final int rank;
  final RankingEntry entry;
  final bool showLastPlayedAt;

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
                  showLastPlayedAt && entry.lastPlayedAt != null
                      ? DateFormat.yMMMd().add_Hm().format(entry.lastPlayedAt!)
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

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overview = stats.overview;
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
              Text('Music Access', style: theme.textTheme.titleLarge),
              const SizedBox(height: 14),
              _SettingsRow(
                icon: Icons.privacy_tip,
                label: 'Authorization',
                value: overview.isDemo
                    ? 'Demo mode'
                    : stats.authorizationStatus.label,
              ),
              _SettingsRow(
                icon: Icons.storage,
                label: 'Data source',
                value: overview.isDemo ? 'Sample library' : 'iOS Music library',
              ),
              _SettingsRow(
                icon: Icons.update,
                label: 'Snapshot',
                value: DateFormat.yMMMd().add_Hm().format(overview.generatedAt),
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
                  label: const Text('Refresh'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
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
    return Padding(
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
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({required this.entries, required this.showLastPlayedAt});

  final List<RankingEntry> entries;
  final bool showLastPlayedAt;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxPlayCount = entries
        .map((entry) => entry.playCount)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: entries.indexed
          .map(
            (indexed) => _RankingRow(
              rank: indexed.$1 + 1,
              entry: indexed.$2,
              maxPlayCount: maxPlayCount,
              showLastPlayedAt: showLastPlayedAt,
            ),
          )
          .toList(),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.entry,
    required this.maxPlayCount,
    required this.showLastPlayedAt,
  });

  final int rank;
  final RankingEntry entry;
  final int maxPlayCount;
  final bool showLastPlayedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final ratio = maxPlayCount == 0 ? 0.0 : entry.playCount / maxPlayCount;
    final barColor = Color.lerp(
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      (rank - 1) / 12,
    )!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                        ? theme.colorScheme.primary.withValues(alpha: 0.18)
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
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: ColoredBox(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.36),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio.clamp(0.04, 1.0),
                  child: SizedBox(
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [barColor, barColor.withValues(alpha: 0.65)],
                        ),
                      ),
                    ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.34, 0.66, 1],
          colors: [
            const Color(0xFF050507),
            const Color(0xFF111113),
            const Color(0xFF120A10),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: SizedBox.expand(),
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

String _hoursLabel(int listeningSeconds) {
  final hours = listeningSeconds / 3600;
  if (hours >= 100) {
    return NumberFormat.decimalPattern().format(hours.round());
  }
  return hours.toStringAsFixed(1);
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

String _rankingTitle(RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => 'Top Songs',
    RankingScope.artists => 'Top Artists',
    RankingScope.albums => 'Top Albums',
    RankingScope.recent => 'Recently Played',
  };
}

String _rankingSubtitle(RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => 'Ranked by play count',
    RankingScope.artists => 'Aggregated across each artist',
    RankingScope.albums => 'Aggregated across each album',
    RankingScope.recent => 'Sorted by last played date',
  };
}

List<NavigationDestination> _navigationDestinations() {
  return HomeSection.values
      .map(
        (section) => NavigationDestination(
          icon: Icon(_sectionIcon(section)),
          selectedIcon: Icon(_sectionSelectedIcon(section)),
          label: section.label,
        ),
      )
      .toList();
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

String _sectionSubtitle(HomeSection section, bool isDemo) {
  final source = isDemo ? 'デモライブラリ' : 'Musicライブラリ';
  return switch (section) {
    HomeSection.playing => '$source の直近再生トラック',
    HomeSection.overview => '$source の概要',
    HomeSection.rankings => '$source のランキング',
    HomeSection.library => '$source のブラウズ',
    HomeSection.settings => 'アクセスとスキャン設定',
  };
}
