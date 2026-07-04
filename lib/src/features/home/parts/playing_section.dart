part of '../home_screen.dart';

class _NowPlayingSection extends ConsumerWidget {
  const _NowPlayingSection({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = stats.overview;
    final playback = ref.watch(playbackControllerProvider);
    final activeTrack = overview.trackById(playback.activeTrackId);
    final track = activeTrack ?? overview.latestTrack;

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
        if (stats.snapshotRecordingEnabled) ...[
          const SizedBox(height: 14),
          _TrendPanel(track: track, history: stats.snapshotHistory),
        ],
        const SizedBox(height: 14),
        _NowPlayingLyricsPanel(track: track),
        if (recentTracks.length > 1) ...[
          const SizedBox(height: 14),
          _RecentTracksPanel(tracks: recentTracks),
        ],
      ],
    );
  }
}

class _NowPlayingLyricsPanel extends StatelessWidget {
  const _NowPlayingLyricsPanel({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context) {
    final lyrics = track.lyrics?.trim();

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x22FFFFFF),
      borderOpacity: 0.12,
      shadowOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrackContextTitle(
            icon: Icons.lyrics_outlined,
            title: _t(context, 'Lyrics', '歌詞'),
          ),
          const SizedBox(height: 12),
          if (lyrics == null || lyrics.isEmpty)
            _TrackContextEmptyText(
              text: _t(
                context,
                'No local lyrics were found for this song.',
                'この曲のローカル歌詞は見つかりませんでした。',
                zh: '未找到此歌曲的本地歌词。',
                ko: '이 곡의 로컬 가사를 찾을 수 없습니다.',
              ),
            )
          else
            _CollapsibleLyricsText(lyrics: lyrics),
        ],
      ),
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
    final busy = playback.isBusy;
    final isActive = playback.isTrackActive(track.id);
    final isPlaying = playback.isTrackPlaying(track.id);
    final number = _numberFormat(context);

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
                    isActive: isActive,
                    isPlaying: isPlaying,
                    onTogglePlayback: () {
                      ref
                          .read(playbackControllerProvider.notifier)
                          .toggleTrack(track.id);
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
                        child: _HeroBadge(
                          label: _t(
                            context,
                            '#1 Song',
                            '#1 曲',
                            zh: '#1 歌曲',
                            ko: '#1 곡',
                          ),
                        ),
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
                                      .toggleTrack(track.id);
                                },
                          tooltip: isPlaying
                              ? _t(context, 'Pause', '一時停止')
                              : _t(context, 'Play this track', 'この曲を再生'),
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                          ),
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
                                  if (isActive) ...[
                                    const SizedBox(height: 10),
                                    _PlaybackStatusChip(
                                      isPlaying: isPlaying,
                                      onDark: true,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  _OpenInAppleMusicButton(
                                    track: track,
                                    onDark: true,
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
                                _SmallMetricPill(
                                  label: _t(context, 'Plays', '再生回数'),
                                  onDark: true,
                                ),
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
    required this.isActive,
    required this.isPlaying,
    required this.onTogglePlayback,
  });

  final LibraryTrack track;
  final AsyncValue<Uint8List?> artwork;
  final NumberFormat number;
  final bool busy;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;

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
                        child: _HeroBadge(
                          label: _t(
                            context,
                            '#1 Song',
                            '#1 曲',
                            zh: '#1 歌曲',
                            ko: '#1 곡',
                          ),
                        ),
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
                          label: _t(context, 'Recent play', '直近再生'),
                        ),
                        if (isActive) _PlaybackStatusChip(isPlaying: isPlaying),
                        if (track.isCloudItem)
                          _TrackChip(
                            icon: Icons.cloud_rounded,
                            label: _t(context, 'Cloud', 'クラウド'),
                          ),
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
                            foregroundColor: theme.colorScheme.onPrimary,
                            minimumSize: const Size.square(54),
                          ),
                          onPressed: busy ? null : onTogglePlayback,
                          tooltip: isPlaying
                              ? _t(context, 'Pause', '一時停止')
                              : _t(context, 'Play this track', 'この曲を再生'),
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 31,
                          ),
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
                            _SmallMetricPill(
                              label: _t(context, 'Plays', '再生回数'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _OpenInAppleMusicButton(track: track),
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
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SmallMetricPill extends StatelessWidget {
  const _SmallMetricPill({required this.label, this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.primary;
    final background = onDark
        ? Colors.black.withValues(alpha: 0.42)
        : theme.colorScheme.primary.withValues(alpha: 0.1);
    final border = onDark
        ? foreground.withValues(alpha: 0.42)
        : foreground.withValues(alpha: 0.28);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({required this.isPlaying, this.onDark = false});

  final bool isPlaying;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = isPlaying
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final darkColor = isPlaying
        ? theme.colorScheme.primary
        : Colors.white.withValues(alpha: 0.78);
    final foreground = onDark ? darkColor : activeColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: onDark
            ? Colors.black.withValues(alpha: 0.42)
            : theme.colorScheme.primary.withValues(
                alpha: isPlaying ? 0.14 : 0.08,
              ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foreground.withValues(alpha: onDark ? 0.42 : 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying
                  ? Icons.graphic_eq_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 16,
              color: foreground,
            ),
            const SizedBox(width: 6),
            Text(
              isPlaying
                  ? _t(context, 'Playing now', '再生中')
                  : _t(context, 'Paused', '一時停止中'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
    final isLight = theme.colorScheme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.84)
            : Colors.black.withValues(alpha: 0.24),
        border: Border(
          top: BorderSide(
            color: isLight
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.7)
                : theme.colorScheme.primary.withValues(alpha: 0.32),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: _HeroStat(
              icon: Icons.play_arrow_rounded,
              label: _t(context, 'Plays', '再生回数'),
              value: _playCountLabel(context, track.playCount),
              color: theme.colorScheme.primary,
              onTap: () => _focusTrackInRanking(context, ref, track),
            ),
          ),
          const _VerticalDividerLine(),
          Expanded(
            child: _HeroStat(
              icon: Icons.fast_forward_rounded,
              label: _t(context, 'Skips', 'スキップ'),
              value: _skipCountLabel(context, track.skipCount),
              color: theme.colorScheme.secondary,
              onTap: () => _focusTrackInRanking(context, ref, track),
            ),
          ),
          const _VerticalDividerLine(),
          Expanded(
            child: _HeroStat(
              icon: Icons.schedule_rounded,
              label: _t(context, 'Last played', '最終再生'),
              value: _shortPlayedAtLabel(context, track.lastPlayedAt),
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
  const _TrendPanel({required this.track, required this.history});

  final LibraryTrack track;
  final SnapshotHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final range = ref.watch(trendRangeProvider);
    final values = _trackTrendValues(
      context: context,
      trackId: track.id,
      history: history,
      range: range,
    );
    final hasSnapshotData = history.snapshots.length >= 2;
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
                  _t(context, 'This week trend', '今週の傾向'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: _t(context, 'About this trend', 'この傾向について'),
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  minimumSize: const Size.square(36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showTrackTrendInfoSheet(context),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasSnapshotData
                ? _t(
                    context,
                    'Play-count changes for this song from daily listening records.',
                    '日々の聴取記録から、この曲の再生回数の増分を表示します。',
                    zh: '根据每日收听记录显示这首歌播放次数的变化。',
                    ko: '일별 청취 기록을 바탕으로 이 곡의 재생 횟수 변화를 표시합니다.',
                  )
                : _t(
                    context,
                    'This chart appears after records from at least two different days are available.',
                    '別の日の記録がもう1回分たまると、このグラフを表示できます。',
                    zh: '至少有两个不同日期的记录后会显示此图表。',
                    ko: '서로 다른 날짜의 기록이 2일 이상 있으면 이 차트를 표시합니다.',
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
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
                    return theme.colorScheme.onPrimary;
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
          _TrendBars(values: values, hasSnapshotData: hasSnapshotData),
        ],
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.values, required this.hasSnapshotData});

  final List<_TrackTrendValue> values;
  final bool hasSnapshotData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!hasSnapshotData) {
      return SizedBox(
        height: 178,
        child: Center(
          child: _TrackContextEmptyText(
            text: _t(
              context,
              'Open SongBrief on another day to build a listening trend.',
              '別の日にもSongBriefを開くと、日々の変化を表示できます。',
              zh: '在其他日期打开 SongBrief 后即可生成收听趋势。',
              ko: '다른 날에도 SongBrief를 열면 청취 추세를 만들 수 있습니다.',
            ),
          ),
        ),
      );
    }

    final max = values.fold<int>(
      0,
      (previous, value) => math.max(previous, value.playDelta),
    );

    return SizedBox(
      height: 178,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.indexed.map((indexed) {
          final index = indexed.$1;
          final value = indexed.$2;
          final ratio = max == 0 ? 0.0 : value.playDelta / max;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 5, right: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _compactNumber(value.playDelta),
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
                        heightFactor: max == 0 ? 0 : ratio.clamp(0.08, 1.0),
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
                    value.label,
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

void _showTrackTrendInfoSheet(BuildContext context) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(context, 'How this trend is calculated', 'この傾向の計算方法'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  context,
                  'SongBrief compares daily listening records and charts the increase in play count for the selected song. Missing days are not guessed; they stay at 0 until another pair of records is available.',
                  'SongBriefは日々の聴取記録を比較し、選択中の曲の再生回数の増分を表示します。記録がない日は推定せず、比較できる別の日の記録がそろうまで0として扱います。',
                  zh: 'SongBrief 会比较每日收听记录，并显示所选歌曲播放次数的增加量。没有记录的日期不会推测，在可比较的另一条记录出现前按 0 处理。',
                  ko: 'SongBrief는 일별 청취 기록을 비교해 선택한 곡의 재생 횟수 증가분을 표시합니다. 기록이 없는 날은 추정하지 않고, 비교할 수 있는 다른 날짜의 기록이 생길 때까지 0으로 처리합니다.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _t(
                  context,
                  '7 days uses daily buckets, 4 weeks uses weekly buckets, and 1 year uses monthly buckets.',
                  '7日間は日別、4週間は週別、1年間は月別のバケットで集計します。',
                  zh: '7天按天汇总，4周按周汇总，1年按月汇总。',
                  ko: '7일은 일별, 4주는 주별, 1년은 월별 단위로 집계합니다.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
                  _t(context, 'Recently played songs', '最近再生した曲'),
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
                child: Text(_t(context, 'See all', 'すべて見る')),
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
              _shortPlayedAtLabel(context, track.lastPlayedAt),
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
              tooltip: _t(context, 'More', 'その他'),
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
    final playback = ref.watch(playbackControllerProvider);
    final isPlaying = playback.isTrackPlaying(track.id);
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
            onPressed: playback.isBusy
                ? null
                : () {
                    Navigator.of(context).pop();
                    ref
                        .read(playbackControllerProvider.notifier)
                        .toggleTrack(track.id);
                  },
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              isPlaying
                  ? _t(context, 'Pause', '一時停止')
                  : _t(context, 'Play', '再生'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showTrackDetailSheet(context, track);
            },
            icon: const Icon(Icons.info_outline_rounded),
            label: Text(_t(context, 'Show details', '詳細を見る')),
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
              const SizedBox(height: 10),
              _OpenInAppleMusicButton(track: track),
              const SizedBox(height: 18),
              _TrackDetailsPanel(track: track),
              const SizedBox(height: 18),
              _TrackLibraryContextPanel(track: track),
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

void _showLibraryGroupListSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required List<_LibraryGroupEntry> groups,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _LibraryGroupListSheet(
      title: title,
      subtitle: subtitle,
      icon: icon,
      groups: groups,
    ),
  );
}

class _LibraryGroupListSheet extends StatelessWidget {
  const _LibraryGroupListSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.groups,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<_LibraryGroupEntry> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final totalPlayCount = groups.fold<int>(
      0,
      (total, group) => total + group.playCount,
    );
    final totalTracks = groups.fold<int>(
      0,
      (total, group) => total + group.trackCount,
    );

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
                          '$subtitle ・ ${_countLabel(context, groups.length, singular: 'group', plural: 'groups', jaUnit: '件', zhUnit: '组', koUnit: '개 그룹')} ・ ${_trackCountLabel(context, totalTracks)} ・ ${_playCountLabel(context, totalPlayCount)}',
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
              const SizedBox(height: 14),
              if (groups.isEmpty)
                Text(
                  _t(context, 'No entries yet.', '項目はまだありません。'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _LibraryGroupRow(group: groups[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
    final totalPlayCount = tracks.fold<int>(
      0,
      (total, track) => total + track.playCount,
    );
    final totalSkipCount = tracks.fold<int>(
      0,
      (total, track) => total + track.skipCount,
    );
    final totalListeningSeconds = tracks.fold<int>(
      0,
      (total, track) => total + track.listeningSeconds,
    );
    final latestTrack = _latestPlayedTrack(tracks);
    final topTrack = tracks.isEmpty ? null : tracks.first;
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
                          '$subtitle ・ ${_trackCountLabel(context, tracks.length)} ・ ${_playCountLabel(context, totalPlayCount)}',
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
                  label: Text(
                    _t(context, 'Show position in ranking', 'ランキング内の位置を見る'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _TrackGroupSummary(
                trackCount: tracks.length,
                totalPlayCount: totalPlayCount,
                totalSkipCount: totalSkipCount,
                totalListeningSeconds: totalListeningSeconds,
                topTrack: topTrack,
                latestTrack: latestTrack,
              ),
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

class _TrackGroupSummary extends StatelessWidget {
  const _TrackGroupSummary({
    required this.trackCount,
    required this.totalPlayCount,
    required this.totalSkipCount,
    required this.totalListeningSeconds,
    required this.topTrack,
    required this.latestTrack,
  });

  final int trackCount;
  final int totalPlayCount;
  final int totalSkipCount;
  final int totalListeningSeconds;
  final LibraryTrack? topTrack;
  final LibraryTrack? latestTrack;

  @override
  Widget build(BuildContext context) {
    final values = [
      _GroupSummaryValue(
        icon: Icons.music_note_rounded,
        label: _t(context, 'Tracks', '曲'),
        value: _numberFormat(context).format(trackCount),
      ),
      _GroupSummaryValue(
        icon: Icons.play_arrow_rounded,
        label: _t(context, 'Plays', '再生回数'),
        value: _numberFormat(context).format(totalPlayCount),
      ),
      _GroupSummaryValue(
        icon: Icons.fast_forward_rounded,
        label: _t(context, 'Skips', 'スキップ'),
        value: _numberFormat(context).format(totalSkipCount),
      ),
      _GroupSummaryValue(
        icon: Icons.schedule_rounded,
        label: _t(context, 'Hours', '時間'),
        value: _hoursLabel(totalListeningSeconds),
      ),
      _GroupSummaryValue(
        icon: Icons.leaderboard_rounded,
        label: _t(context, 'Top song', '上位の曲'),
        value: topTrack?.title ?? _t(context, 'None', 'なし'),
      ),
      _GroupSummaryValue(
        icon: Icons.history_rounded,
        label: _t(context, 'Latest', '直近'),
        value: latestTrack == null
            ? _t(context, 'None', 'なし')
            : latestTrack!.title,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: columns == 3 ? 2.35 : 2.05,
          ),
          itemBuilder: (context, index) =>
              _TrackGroupSummaryTile(value: values[index]),
        );
      },
    );
  }
}

class _TrackGroupSummaryTile extends StatelessWidget {
  const _TrackGroupSummaryTile({required this.value});

  final _GroupSummaryValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.44,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(value.icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
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

class _GroupTrackRow extends ConsumerWidget {
  const _GroupTrackRow({required this.track, required this.rank});

  final LibraryTrack track;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
                _numberFormat(context).format(track.playCount),
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
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }

    final asset = track.artworkAsset;
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.cover);
    }

    return const _MissingArtworkPlaceholder();
  }
}

class _MissingArtworkPlaceholder extends StatelessWidget {
  const _MissingArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortestSide = math.min(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final recordSize = (shortestSide * 1.18).clamp(58.0, 190.0);
          final holeSize = recordSize * 0.22;
          final ringWidth = (recordSize * 0.075).clamp(3.0, 12.0);
          final recordColor = isLight
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.22);
          final ringColor = isLight
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.10);
          final holeColor = theme.colorScheme.surfaceContainerHighest;

          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  right: -recordSize * 0.24,
                  bottom: -recordSize * 0.24,
                  child: SizedBox.square(
                    dimension: recordSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: recordColor,
                        border: Border.all(color: ringColor, width: ringWidth),
                      ),
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: holeColor,
                            border: Border.all(
                              color: ringColor,
                              width: math.max(1.0, ringWidth * 0.45),
                            ),
                          ),
                          child: SizedBox.square(dimension: holeSize),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
            _TrackChip(
              icon: Icons.graphic_eq_rounded,
              label: _t(context, 'Recent play', '直近再生'),
            ),
            if (track.isCloudItem)
              _TrackChip(
                icon: Icons.cloud_rounded,
                label: _t(context, 'Cloud', 'クラウド'),
              ),
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
        const SizedBox(height: 10),
        _OpenInAppleMusicButton(track: track),
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
            ? const _MissingArtworkPlaceholder()
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
    final busy = state.isBusy;
    final isActive = state.isTrackActive(track.id);
    final isPlaying = state.isTrackPlaying(track.id);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (isActive) _PlaybackStatusChip(isPlaying: isPlaying),
        IconButton.filledTonal(
          onPressed: busy
              ? null
              : () {
                  ref
                      .read(playbackControllerProvider.notifier)
                      .skipToPrevious();
                },
          tooltip: _t(context, 'Previous', '前へ'),
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
                      .toggleTrack(track.id);
                },
          tooltip: isPlaying
              ? _t(context, 'Pause', '一時停止')
              : _t(context, 'Play this track', 'この曲を再生'),
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 32,
          ),
        ),
        IconButton.filledTonal(
          onPressed: busy || !state.isPlaying
              ? null
              : () {
                  ref.read(playbackControllerProvider.notifier).pause();
                },
          tooltip: _t(context, 'Pause', '一時停止'),
          icon: const Icon(Icons.pause_rounded),
        ),
        IconButton.filledTonal(
          onPressed: busy
              ? null
              : () {
                  ref.read(playbackControllerProvider.notifier).skipToNext();
                },
          tooltip: _t(context, 'Next', '次へ'),
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

class _OpenInAppleMusicButton extends StatelessWidget {
  const _OpenInAppleMusicButton({required this.track, this.onDark = false});

  final LibraryTrack track;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exactSongLink = hasAppleMusicSongLink(track);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: onDark
              ? Colors.black.withValues(alpha: 0.36)
              : Colors.transparent,
          foregroundColor: onDark ? Colors.white : theme.colorScheme.primary,
          side: BorderSide(
            color: onDark
                ? Colors.white.withValues(alpha: 0.28)
                : theme.colorScheme.primary.withValues(alpha: 0.42),
          ),
        ),
        onPressed: () => _openAppleMusicTrack(context, track),
        icon: const Icon(Icons.open_in_new_rounded),
        label: Text(
          exactSongLink
              ? _t(context, 'Open song in Apple Music', '曲をApple Musicで開く')
              : _t(context, 'Search in Apple Music', 'Apple Musicで検索'),
        ),
      ),
    );
  }
}

class _TrackDetailsPanel extends ConsumerWidget {
  const _TrackDetailsPanel({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          label: _t(context, 'Artist', 'アーティスト'),
          value: track.artist,
          onTap: artistTracks.isEmpty
              ? null
              : () => _showTrackGroupSheet(
                  context,
                  title: track.artist,
                  subtitle: _t(context, 'Artist songs', 'アーティストの曲'),
                  icon: Icons.person_outline,
                  tracks: artistTracks,
                  rankingScope: RankingScope.artists,
                  rankingTitle: track.artist,
                ),
        ),
        const SizedBox(height: 10),
        _TrackDetailRow(
          icon: Icons.album_outlined,
          label: _t(context, 'Album', 'アルバム'),
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
          label: _t(context, 'Album artist', 'アルバムアーティスト'),
          value: albumArtist,
          onTap: albumArtistTracks.isEmpty
              ? null
              : () => _showTrackGroupSheet(
                  context,
                  title: albumArtist,
                  subtitle: _t(context, 'Album artist songs', 'アルバムアーティストの曲'),
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
                label: _t(context, 'Plays', '再生回数'),
                value: _playCountLabel(context, track.playCount),
                onTap: () => _focusTrackInRanking(
                  context,
                  ref,
                  track,
                  closeCurrentRoute: true,
                ),
              ),
              _TrackStatCard(
                icon: Icons.fast_forward_outlined,
                label: _t(context, 'Skips', 'スキップ'),
                value: _skipCountLabel(context, track.skipCount),
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
          label: _t(context, 'Last played', '最後に再生した日'),
          value: _playedAtLabel(context, track.lastPlayedAt),
        ),
        const SizedBox(height: 10),
        _TrackDetailRow(
          icon: Icons.timer_outlined,
          label: _t(context, 'Duration', '曲の長さ'),
          value: _durationLabel(track.duration),
        ),
        if (track.genre != null) ...[
          const SizedBox(height: 10),
          _TrackDetailRow(
            icon: Icons.category_outlined,
            label: _t(context, 'Genre', 'ジャンル'),
            value: track.genre!,
            onTap: genreTracks.isEmpty
                ? null
                : () => _showTrackGroupSheet(
                    context,
                    title: track.genre!,
                    subtitle: _t(context, 'Genre songs', 'ジャンルの曲'),
                    icon: Icons.category_outlined,
                    tracks: genreTracks,
                  ),
          ),
        ],
      ],
    );
  }
}

class _TrackLibraryContextPanel extends ConsumerWidget {
  const _TrackLibraryContextPanel({required this.track});

  final LibraryTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref
        .watch(musicStatsControllerProvider)
        .asData
        ?.value
        .overview;
    final lyrics = track.lyrics?.trim();

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x22FFFFFF),
      borderOpacity: 0.12,
      shadowOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrackContextTitle(
            icon: Icons.playlist_play_rounded,
            title: _t(context, 'Playlists', 'プレイリスト'),
          ),
          const SizedBox(height: 12),
          if (track.playlistNames.isEmpty)
            _TrackContextEmptyText(
              text: _t(
                context,
                'No playlist membership was returned for this song.',
                'この曲が登録されているプレイリストは取得されていません。',
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final playlistName in track.playlistNames)
                  _TrackMetadataChip(
                    icon: Icons.queue_music_rounded,
                    label: playlistName,
                    onTap: overview == null
                        ? null
                        : () {
                            final tracks = _tracksByPlaylist(
                              overview,
                              playlistName,
                            );
                            if (tracks.isEmpty) {
                              return;
                            }
                            _showTrackGroupSheet(
                              context,
                              title: playlistName,
                              subtitle: _t(
                                context,
                                'Playlist songs',
                                'プレイリスト内の曲',
                              ),
                              icon: Icons.playlist_play_rounded,
                              tracks: tracks,
                            );
                          },
                  ),
              ],
            ),
          const SizedBox(height: 20),
          _TrackContextTitle(
            icon: Icons.lyrics_outlined,
            title: _t(context, 'Lyrics', '歌詞'),
          ),
          const SizedBox(height: 12),
          if (lyrics == null || lyrics.isEmpty)
            _TrackContextEmptyText(
              text: _t(
                context,
                'No local lyrics were found for this song.',
                'この曲のローカル歌詞は見つかりませんでした。',
                zh: '未找到此歌曲的本地歌词。',
                ko: '이 곡의 로컬 가사를 찾을 수 없습니다.',
              ),
            )
          else
            _CollapsibleLyricsText(lyrics: lyrics),
        ],
      ),
    );
  }
}

class _CollapsibleLyricsText extends StatefulWidget {
  const _CollapsibleLyricsText({required this.lyrics});

  final String lyrics;

  @override
  State<_CollapsibleLyricsText> createState() => _CollapsibleLyricsTextState();
}

class _CollapsibleLyricsTextState extends State<_CollapsibleLyricsText> {
  static const _collapsedLineCount = 3;

  bool _expanded = false;

  String get _lyrics => _normalizeLyricsText(widget.lyrics);

  bool get _shouldCollapse {
    final lyrics = _lyrics;
    final explicitLines = lyrics.split('\n').length;
    return explicitLines > _collapsedLineCount || lyrics.length > 160;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shouldCollapse = _shouldCollapse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          _lyrics,
          maxLines: shouldCollapse && !_expanded ? _collapsedLineCount : null,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.55,
          ),
        ),
        if (shouldCollapse) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            icon: Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              _t(
                context,
                _expanded ? 'Show less' : 'Show all lyrics',
                _expanded ? '閉じる' : '歌詞をすべて表示',
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrackContextTitle extends StatelessWidget {
  const _TrackContextTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackContextEmptyText extends StatelessWidget {
  const _TrackContextEmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        height: 1.45,
      ),
    );
  }
}

class _TrackMetadataChip extends StatelessWidget {
  const _TrackMetadataChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(999);
    final maxLabelWidth = (MediaQuery.sizeOf(context).width - 128)
        .clamp(96.0, 240.0)
        .toDouble();
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: radius,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
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
