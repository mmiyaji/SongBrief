part of '../home_screen.dart';

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
          overview: overview,
          isDemo: overview.isDemo,
        ),
        const SizedBox(height: 14),
        _SummaryGrid(overview: overview),
        const SizedBox(height: 14),
        _OverviewAnalyticsPanel(
          overview: overview,
          history: stats.snapshotHistory,
        ),
        const SizedBox(height: 14),
        _OverviewInsightPanel(overview: overview),
        const SizedBox(height: 14),
        _SmartListsPanel(overview: overview),
        const SizedBox(height: 14),
        _OverviewBreakdownPanel(overview: overview),
        const SizedBox(height: 14),
        AdBannerSlot(placement: _t(context, 'Overview', '概要')),
      ],
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final number = _numberFormat(context);
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
    final number = _numberFormat(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context, 'Total Plays', '総再生回数'),
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
          '${_trackCountLabel(context, overview.totalTracks)} ・ '
          '${_artistCountLabel(context, overview.totalArtists)} ・ '
          '${_albumCountLabel(context, overview.totalAlbums)}',
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
                    _t(context, 'Top song', 'トップ曲'),
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
        _SignalTile(
          icon: Icons.schedule,
          label: _t(context, 'Hours', '時間'),
          value: hours,
        ),
        _SignalTile(
          icon: Icons.fast_forward,
          label: _t(context, 'Skips', 'スキップ'),
          value: skips,
        ),
        _SignalTile(
          icon: Icons.speed,
          label: _t(context, 'Skip rate', 'スキップ率'),
          value: skipRate,
        ),
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
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.78,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
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
  const _SnapshotStatusPanel({
    required this.history,
    required this.overview,
    required this.isDemo,
  });

  final SnapshotHistory history;
  final LibraryOverview overview;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = _numberFormat(context);
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
                  Text(
                    _t(context, 'Daily snapshots', '日次スナップショット'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isDemo
                        ? _t(
                            context,
                            'Available after iOS Music access is granted.',
                            'iOSミュージックへのアクセス許可後に利用できます。',
                          )
                        : _t(
                            context,
                            'The first snapshot will be saved after the next scan.',
                            '次回のスキャン後に最初のスナップショットを保存します。',
                          ),
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

    final latestDate = _dateTimeFormat(context).format(latest.capturedAt);
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
                    Text(
                      _t(context, 'Daily snapshots', '日次スナップショット'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _t(
                        context,
                        'Last scan $latestDate - ${_snapshotSourceLabel(context, latest.source)}',
                        '最終スキャン $latestDate ・ ${_snapshotSourceLabel(context, latest.source)}',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: _dayCountLabel(context, history.snapshotCount),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _SnapshotMetric(
                  label: _t(context, 'Window', '期間'),
                  value: observedDays <= 0
                      ? _t(context, 'Baseline', '基準値')
                      : _dayCountLabel(context, observedDays),
                ),
                _SnapshotMetric(
                  label: _t(context, 'New plays', '増加再生'),
                  value: number.format(delta?.totalPlayDelta ?? 0),
                ),
                _SnapshotMetric(
                  label: _t(context, 'New skips', '増加スキップ'),
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
          const SizedBox(height: 14),
          _SnapshotTrendChart(history: history),
          if (topDeltas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _t(context, 'Top gains since previous scan', '前回スキャンからの増加上位'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...topDeltas.map(
              (track) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _SnapshotDeltaRow(
                  delta: track,
                  track: overview.trackById(track.id),
                ),
              ),
            ),
          ] else if (delta != null) ...[
            const SizedBox(height: 12),
            Text(
              _t(
                context,
                'No play count changes were observed between the last two scans.',
                '直近2回のスキャン間で再生回数の変化はありませんでした。',
              ),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.78,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
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

class _SnapshotTrendChart extends StatelessWidget {
  const _SnapshotTrendChart({required this.history});

  final SnapshotHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = _numberFormat(context);
    final values = _snapshotTrendValues(context, history);
    final maxPlayDelta = values.fold<int>(
      0,
      (current, value) => value.playDelta > current ? value.playDelta : current,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.38,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stacked_bar_chart_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t(context, 'Snapshot trend', '日次スナップショット推移'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              Text(
                _t(
                  context,
                  'Trend bars appear after two or more snapshots.',
                  '2件以上のスナップショットが保存されると推移を表示します。',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              ...values.map(
                (value) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SnapshotTrendBar(
                    value: value,
                    maxPlayDelta: maxPlayDelta,
                    trailing: '+${number.format(value.playDelta)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotTrendBar extends StatelessWidget {
  const _SnapshotTrendBar({
    required this.value,
    required this.maxPlayDelta,
    required this.trailing,
  });

  final _SnapshotTrendValue value;
  final int maxPlayDelta;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxPlayDelta <= 0 ? 0.0 : value.playDelta / maxPlayDelta;

    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            value.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: ColoredBox(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio.clamp(0.0, 1.0),
                  child: SizedBox(
                    height: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          child: Text(
            trailing,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SnapshotDeltaRow extends StatelessWidget {
  const _SnapshotDeltaRow({required this.delta, required this.track});

  final TrackCounterDelta delta;
  final LibraryTrack? track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = _numberFormat(context);
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                delta.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                delta.artist,
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
          '+${number.format(delta.playDelta)}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (track != null)
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );

    if (track == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTrackDetailSheet(context, track!),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: content,
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
    final number = _numberFormat(context);
    final values = [
      _SummaryValue(
        icon: Icons.person,
        label: _t(context, 'Artists', 'アーティスト'),
        value: number.format(overview.totalArtists),
        onTap: overview.tracks.isEmpty
            ? null
            : () => _showLibraryGroupListSheet(
                context,
                title: _t(context, 'Artists', 'アーティスト'),
                subtitle: _t(
                  context,
                  'All artist groups in this scan',
                  'このスキャン内のアーティスト一覧',
                ),
                icon: Icons.person_rounded,
                groups: _libraryGroupsForMode(
                  context,
                  _LibraryBrowseMode.artists,
                  overview.tracks,
                  _LibrarySortMode.plays,
                ),
              ),
      ),
      _SummaryValue(
        icon: Icons.album,
        label: _t(context, 'Albums', 'アルバム'),
        value: number.format(overview.totalAlbums),
        onTap: overview.tracks.isEmpty
            ? null
            : () => _showLibraryGroupListSheet(
                context,
                title: _t(context, 'Albums', 'アルバム'),
                subtitle: _t(
                  context,
                  'All album groups in this scan',
                  'このスキャン内のアルバム一覧',
                ),
                icon: Icons.album_rounded,
                groups: _libraryGroupsForMode(
                  context,
                  _LibraryBrowseMode.albums,
                  overview.tracks,
                  _LibrarySortMode.plays,
                ),
              ),
      ),
      _SummaryValue(
        icon: Icons.music_note,
        label: _t(context, 'Tracks', '曲'),
        value: number.format(overview.totalTracks),
        onTap: overview.tracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: _t(context, 'All songs', 'すべての曲'),
                subtitle: _t(context, 'Library tracks', 'ライブラリ内の曲'),
                icon: Icons.music_note_rounded,
                tracks: _sortLibraryTracks(
                  overview.tracks,
                  _LibrarySortMode.plays,
                ),
              ),
      ),
      _SummaryValue(
        icon: Icons.schedule,
        label: _t(context, 'Hours', '時間'),
        value: _hoursLabel(overview.totalListeningSeconds),
        onTap: overview.tracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: _t(context, 'Listening time', '再生時間'),
                subtitle: _t(
                  context,
                  'Songs sorted by total listening time',
                  '総再生時間が長い曲',
                ),
                icon: Icons.schedule_rounded,
                tracks: _tracksByListeningTime(overview.tracks),
              ),
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
    final radius = BorderRadius.circular(18);
    final content = GlassSurface(
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
          if (value.onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (value.onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: value.onTap, child: content),
    );
  }
}

void _showListeningMapsDetailSheet(
  BuildContext context, {
  required LibraryOverview overview,
  required SnapshotHistory history,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _ListeningMapsDetailSheet(overview: overview, history: history),
  );
}

class _ListeningMapsDetailSheet extends StatelessWidget {
  const _ListeningMapsDetailSheet({
    required this.overview,
    required this.history,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.scatter_plot_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, 'Listening maps', 'リスニングマップ'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _t(
                            context,
                            'Inspect playback patterns by year, day, and genre',
                            '発売年・日別・ジャンル別に再生傾向を確認',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ReleaseYearPlayMapCard(overview: overview, expanded: true),
              const SizedBox(height: 14),
              _GenreStackedReleaseBarsCard(overview: overview),
              const SizedBox(height: 14),
              _ActivityHeatmapCard(
                overview: overview,
                history: history,
                expanded: true,
              ),
              const SizedBox(height: 14),
              _DecadeMixCard(overview: overview),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewAnalyticsPanel extends StatelessWidget {
  const _OverviewAnalyticsPanel({
    required this.overview,
    required this.history,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;

  @override
  Widget build(BuildContext context) {
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
            icon: Icons.scatter_plot_rounded,
            title: _t(context, 'Listening maps', 'リスニングマップ'),
            subtitle: _t(
              context,
              'Release-year concentration and daily play activity',
              '発売年ごとの集中度と日別の再生活動',
            ),
            trailing: IconButton.filledTonal(
              onPressed: () => _showListeningMapsDetailSheet(
                context,
                overview: overview,
                history: history,
              ),
              icon: const Icon(Icons.open_in_full_rounded),
              tooltip: _t(context, 'Expand listening maps', 'リスニングマップを拡大'),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final releaseCard = _ReleaseYearPlayMapCard(overview: overview);
              final heatmapCard = _ActivityHeatmapCard(
                overview: overview,
                history: history,
              );

              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: releaseCard),
                    const SizedBox(width: 14),
                    Expanded(child: heatmapCard),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  releaseCard,
                  const SizedBox(height: 12),
                  heatmapCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReleaseYearPlayMapCard extends StatelessWidget {
  const _ReleaseYearPlayMapCard({
    required this.overview,
    this.expanded = false,
  });

  final LibraryOverview overview;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final number = _numberFormat(context);
    final buckets = _releaseYearBuckets(overview.tracks);
    final topBucket = buckets.isEmpty
        ? null
        : buckets.reduce(
            (current, next) =>
                next.playCount > current.playCount ? next : current,
          );

    return _OverviewAnalysisCard(
      icon: Icons.timeline_rounded,
      title: _t(context, 'Release year x plays', '発売年 x 再生数'),
      subtitle: topBucket == null
          ? _t(
              context,
              'Release dates are not available yet.',
              '発売日の情報がまだありません。',
            )
          : _t(
              context,
              '${topBucket.year} has the highest concentration',
              '${topBucket.year}年の集中度が最も高いです',
            ),
      child: buckets.isEmpty
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'Songs without release dates are excluded.',
                '発売日がない曲は集計対象外です。',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InteractiveReleaseYearChart(
                  buckets: buckets,
                  height: expanded ? 250 : 190,
                  onOpenBucket: expanded
                      ? (bucket) {
                          final tracks = _tracksByReleaseYear(
                            overview,
                            bucket.year,
                          );
                          if (tracks.isEmpty) {
                            return;
                          }
                          _showTrackGroupSheet(
                            context,
                            title: bucket.year.toString(),
                            subtitle: _t(
                              context,
                              'Release-year songs',
                              '発売年の曲',
                            ),
                            icon: Icons.event_rounded,
                            tracks: tracks,
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AnalysisPill(
                      label: _t(context, 'Years', '年数'),
                      value: number.format(buckets.length),
                    ),
                    if (topBucket != null)
                      _AnalysisPill(
                        label: _t(context, 'Top year', '最多年'),
                        value:
                            '${topBucket.year} / ${number.format(topBucket.playCount)}',
                      ),
                    _AnalysisPill(
                      label: _t(context, 'Avg / song', '曲平均'),
                      value: topBucket == null
                          ? '0'
                          : topBucket.averagePlays.toStringAsFixed(1),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _InteractiveReleaseYearChart extends StatefulWidget {
  const _InteractiveReleaseYearChart({
    required this.buckets,
    required this.height,
    this.onOpenBucket,
  });

  final List<_ReleaseYearBucket> buckets;
  final double height;
  final ValueChanged<_ReleaseYearBucket>? onOpenBucket;

  @override
  State<_InteractiveReleaseYearChart> createState() =>
      _InteractiveReleaseYearChartState();
}

class _InteractiveReleaseYearChartState
    extends State<_InteractiveReleaseYearChart> {
  _ReleaseYearBucket? _selectedBucket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = widget.buckets;
    final selectedBucket = _selectedBucket;
    final selectedIndex = selectedBucket == null
        ? -1
        : buckets.indexWhere((bucket) => bucket.year == selectedBucket.year);
    final maxAverage = buckets.fold<double>(
      1,
      (current, bucket) => math.max(current, bucket.averagePlays),
    );
    final maxY = maxAverage <= 1 ? 1.0 : maxAverage * 1.18;
    final minYear = buckets.first.year;
    final maxYear = buckets.last.year;
    final yearSpan = maxYear - minYear;
    final minX = (yearSpan == 0 ? minYear - 1 : minYear).toDouble();
    final maxX = (yearSpan == 0 ? maxYear + 1 : maxYear).toDouble();
    final spots = buckets
        .map((bucket) => FlSpot(bucket.year.toDouble(), bucket.averagePlays))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: yearSpan <= 16,
                verticalInterval: 1,
                getDrawingVerticalLine: (value) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
                  strokeWidth: 1,
                ),
                horizontalInterval: maxY / 3,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.42,
                  ),
                  strokeWidth: 1,
                ),
              ),
              titlesData: _releaseYearTitlesData(
                context: context,
                buckets: buckets,
                selectedIndex: selectedIndex,
                minYear: minYear,
                maxYear: maxYear,
              ),
              lineTouchData: LineTouchData(
                touchSpotThreshold: 18,
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) {
                    return;
                  }
                  final spots = response?.lineBarSpots;
                  if (spots == null || spots.isEmpty) {
                    return;
                  }
                  final spot = spots.first;
                  if (spot.spotIndex >= buckets.length) {
                    return;
                  }
                  setState(() {
                    _selectedBucket = buckets[spot.spotIndex];
                  });
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(10),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tooltipMargin: 12,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (spot) => theme.colorScheme.inverseSurface,
                  getTooltipItems: (spots) => spots
                      .map((spot) {
                        final bucket = buckets[spot.spotIndex];
                        return LineTooltipItem(
                          '${bucket.year}\n'
                          '${_playCountLabel(context, bucket.playCount)} / '
                          '${_trackCountLabel(context, bucket.trackCount)}',
                          theme.textTheme.labelSmall!.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                getTouchedSpotIndicator: (barData, indicators) => indicators
                    .map(
                      (index) => TouchedSpotIndicatorData(
                        FlLine(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.42,
                          ),
                          strokeWidth: 2,
                        ),
                        FlDotData(
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 7,
                                color: theme.colorScheme.primary,
                                strokeWidth: 3,
                                strokeColor: theme.colorScheme.surface,
                              ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: theme.colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  showingIndicators: selectedIndex < 0
                      ? const []
                      : [selectedIndex],
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  ),
                  dotData: FlDotData(
                    getDotPainter: (spot, percent, barData, index) {
                      final bucket = buckets[index];
                      return FlDotCirclePainter(
                        radius: 4.8 + math.min(bucket.trackCount, 6) * 0.42,
                        color: theme.colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: theme.colorScheme.surface,
                      );
                    },
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: selectedBucket == null
              ? _AnalysisInlineTooltip(
                  key: const ValueKey('release-year-hint'),
                  icon: Icons.touch_app_rounded,
                  label: _t(context, 'Tap a year point', '年の点をタップ'),
                  value: _t(context, 'Show plays and song count', '再生数と曲数を表示'),
                )
              : _AnalysisInlineTooltip(
                  key: ValueKey(selectedBucket.year),
                  icon: Icons.info_outline_rounded,
                  label: selectedBucket.year.toString(),
                  value: _t(
                    context,
                    '${_trackCountLabel(context, selectedBucket.trackCount)} / '
                        '${_playCountLabel(context, selectedBucket.playCount)} / '
                        '${selectedBucket.averagePlays.toStringAsFixed(1)} avg',
                    '${_trackCountLabel(context, selectedBucket.trackCount)} / '
                        '${_playCountLabel(context, selectedBucket.playCount)} / '
                        '平均${selectedBucket.averagePlays.toStringAsFixed(1)}',
                  ),
                  onTap: widget.onOpenBucket == null
                      ? null
                      : () => widget.onOpenBucket!(selectedBucket),
                ),
        ),
      ],
    );
  }
}

FlTitlesData _releaseYearTitlesData({
  required BuildContext context,
  required List<_ReleaseYearBucket> buckets,
  required int selectedIndex,
  required int minYear,
  required int maxYear,
}) {
  final theme = Theme.of(context);
  final labelStyle = theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w800,
  );
  final selectedYear = selectedIndex < 0 ? null : buckets[selectedIndex].year;
  final yearSpan = maxYear - minYear;
  final yearStep = yearSpan <= 16 ? 1 : math.max(1, (yearSpan / 8).ceil());

  Widget bottomTitle(double value, TitleMeta meta) {
    final year = value.round();
    if ((value - year).abs() > 0.01 || year < minYear || year > maxYear) {
      return const SizedBox.shrink();
    }
    final shouldShow =
        yearSpan <= 16 ||
        year == minYear ||
        year == maxYear ||
        year == selectedYear ||
        (year - minYear) % yearStep == 0;
    if (!shouldShow) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      meta: meta,
      space: 7,
      child: Text(year.toString(), style: labelStyle),
    );
  }

  Widget leftTitle(double value, TitleMeta meta) {
    if (value < 0) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      meta: meta,
      space: 7,
      child: Text(_compactNumber(value.round()), style: labelStyle),
    );
  }

  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles()),
    rightTitles: const AxisTitles(sideTitles: SideTitles()),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: 1,
        getTitlesWidget: bottomTitle,
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 38,
        maxIncluded: false,
        getTitlesWidget: leftTitle,
      ),
    ),
  );
}

class _ActivityHeatmapCard extends StatelessWidget {
  const _ActivityHeatmapCard({
    required this.overview,
    required this.history,
    this.expanded = false,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _activityHeatmapDays(overview: overview, history: history);
    final maxValue = days.fold<int>(
      0,
      (current, day) => math.max(current, day.playCount),
    );
    final activeDays = days.where((day) => day.playCount > 0).length;
    final weeks = _activityHeatmapWeeks(days);
    final sourceLabel = history.snapshotCount >= 2
        ? _t(context, 'Snapshot deltas', 'スナップショット差分')
        : _t(context, 'Recent-track estimate', '最近再生からの推定');

    return _OverviewAnalysisCard(
      icon: Icons.grid_on_rounded,
      title: _t(context, 'Activity heatmap', '再生ヒートマップ'),
      subtitle: sourceLabel,
      child: maxValue == 0
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'Activity appears after daily snapshots are recorded.',
                '日次スナップショットが記録されると活動量を表示します。',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellSize = expanded
                        ? constraints.maxWidth >= 520
                              ? 16.0
                              : 13.0
                        : constraints.maxWidth >= 360
                        ? 13.0
                        : 11.0;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: weeks
                            .map(
                              (week) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Column(
                                  children: week
                                      .map(
                                        (day) => _ActivityHeatmapCell(
                                          day: day,
                                          maxValue: maxValue,
                                          size: cellSize,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _AnalysisPill(
                      label: _t(context, 'Active days', '再生日'),
                      value: _numberFormat(context).format(activeDays),
                    ),
                    const Spacer(),
                    Text(
                      _t(context, 'Less', '少'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (var index = 0; index < 4; index++)
                      Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: _activityHeatmapColor(theme, index + 1, 4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    const SizedBox(width: 3),
                    Text(
                      _t(context, 'More', '多'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _GenreStackedReleaseBarsCard extends StatelessWidget {
  const _GenreStackedReleaseBarsCard({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stacks = _genreYearStacks(overview.tracks);
    final colors = _analysisPalette(theme);
    final legendItems = _genreLegendItems(stacks);

    return _OverviewAnalysisCard(
      icon: Icons.stacked_bar_chart_rounded,
      title: _t(context, 'Genre stack by release year', '発売年別ジャンル積み上げ'),
      subtitle: _t(
        context,
        'Play counts split by the strongest genres',
        '再生数を主要ジャンル別に分解',
      ),
      child: stacks.isEmpty
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'Genre and release date metadata are required.',
                'ジャンルと発売日のメタデータが必要です。',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: legendItems.indexed
                      .map(
                        (item) => _LegendChip(
                          label: item.$2,
                          color: colors[item.$1 % colors.length],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = math.max(
                      constraints.maxWidth,
                      stacks.length * 46.0,
                    );
                    return SizedBox(
                      height: 260,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          child: _GenreStackedReleaseBarChart(
                            overview: overview,
                            stacks: stacks,
                            colors: colors,
                            legendItems: legendItems,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _GenreStackedReleaseBarChart extends StatelessWidget {
  const _GenreStackedReleaseBarChart({
    required this.overview,
    required this.stacks,
    required this.colors,
    required this.legendItems,
  });

  final LibraryOverview overview;
  final List<_GenreYearStack> stacks;
  final List<Color> colors;
  final List<String> legendItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxPlays = stacks.fold<int>(
      1,
      (current, stack) => math.max(current, stack.playCount),
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxPlays * 1.15,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: math.max(1, maxPlays / 3),
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.36),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles()),
          rightTitles: const AxisTitles(sideTitles: SideTitles()),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 0.01 ||
                    index < 0 ||
                    index >= stacks.length) {
                  return const SizedBox.shrink();
                }
                final step = math.max(1, (stacks.length / 6).ceil());
                if (index != 0 &&
                    index != stacks.length - 1 &&
                    index % step != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(stacks[index].year.toString(), style: labelStyle),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 7,
                child: Text(_compactNumber(value.round()), style: labelStyle),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) {
              return;
            }
            final spot = response?.spot;
            if (spot == null ||
                spot.touchedBarGroupIndex < 0 ||
                spot.touchedBarGroupIndex >= stacks.length) {
              return;
            }
            final stack = stacks[spot.touchedBarGroupIndex];
            final segmentIndex = spot.touchedStackItemIndex;
            final segment =
                segmentIndex >= 0 && segmentIndex < stack.segments.length
                ? stack.segments[segmentIndex]
                : null;
            _showGenreYearTracks(
              context: context,
              overview: overview,
              stack: stack,
              segment: segment,
              legendItems: legendItems,
            );
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            tooltipMargin: 12,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (group) => theme.colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stack = stacks[group.x];
              return BarTooltipItem(
                '${stack.year}\n${_playCountLabel(context, stack.playCount)}',
                theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
        ),
        barGroups: stacks.indexed
            .map((entry) {
              final stack = entry.$2;
              var start = 0.0;
              final segments = stack.segments
                  .map((segment) {
                    final end = start + segment.playCount;
                    final color =
                        colors[math.max(0, legendItems.indexOf(segment.genre)) %
                            colors.length];
                    final item = BarChartRodStackItem(start, end, color);
                    start = end;
                    return item;
                  })
                  .toList(growable: false);

              return BarChartGroupData(
                x: entry.$1,
                barRods: [
                  BarChartRodData(
                    toY: stack.playCount.toDouble(),
                    width: 22,
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surfaceContainerHighest,
                    rodStackItems: segments,
                  ),
                ],
              );
            })
            .toList(growable: false),
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

void _showGenreYearTracks({
  required BuildContext context,
  required LibraryOverview overview,
  required _GenreYearStack stack,
  required _GenreStackSegment? segment,
  required List<String> legendItems,
}) {
  final tracks = switch (segment?.genre) {
    null => _tracksByReleaseYear(overview, stack.year),
    'Other' => _tracksByReleaseYearExcludingGenres(
      overview,
      year: stack.year,
      excludedGenres: legendItems.where((genre) => genre != 'Other').toSet(),
    ),
    final genre => _tracksByReleaseYearAndGenre(
      overview,
      year: stack.year,
      genre: genre,
    ),
  };
  if (tracks.isEmpty) {
    return;
  }
  _showTrackGroupSheet(
    context,
    title: segment == null
        ? stack.year.toString()
        : '${stack.year} / ${segment.genre}',
    subtitle: _t(
      context,
      segment == null ? 'Release-year songs' : 'Release-year genre songs',
      segment == null ? '発売年の曲' : '発売年とジャンルの曲',
    ),
    icon: Icons.stacked_bar_chart_rounded,
    tracks: tracks,
  );
}

class _DecadeMixCard extends StatelessWidget {
  const _DecadeMixCard({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = _decadePlayBuckets(overview.tracks);
    final maxPlays = buckets.fold<int>(
      0,
      (current, bucket) => math.max(current, bucket.playCount),
    );

    return _OverviewAnalysisCard(
      icon: Icons.view_timeline_rounded,
      title: _t(context, 'Era mix', '年代ミックス'),
      subtitle: _t(
        context,
        'Which release decades dominate the library',
        'どの年代の曲がライブラリを占めているか',
      ),
      child: buckets.isEmpty
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'Release dates are not available yet.',
                '発売日の情報がまだありません。',
              ),
            )
          : Column(
              children: buckets
                  .map(
                    (bucket) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DecadeMixRow(
                        bucket: bucket,
                        maxPlays: maxPlays,
                        color: Color.lerp(
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                          buckets.length <= 1
                              ? 0
                              : buckets.indexOf(bucket) / (buckets.length - 1),
                        )!,
                        onTap: () {
                          final tracks = _tracksByDecade(
                            overview,
                            bucket.decade,
                          );
                          if (tracks.isEmpty) {
                            return;
                          }
                          _showTrackGroupSheet(
                            context,
                            title: bucket.label,
                            subtitle: _t(
                              context,
                              'Release decade songs',
                              '発売年代の曲',
                            ),
                            icon: Icons.view_timeline_rounded,
                            tracks: tracks,
                          );
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _DecadeMixRow extends StatelessWidget {
  const _DecadeMixRow({
    required this.bucket,
    required this.maxPlays,
    required this.color,
    this.onTap,
  });

  final _DecadePlayBucket bucket;
  final int maxPlays;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxPlays == 0 ? 0.0 : bucket.playCount / maxPlays;
    final content = Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            bucket.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: ColoredBox(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio.clamp(0.04, 1.0),
                  child: SizedBox(
                    height: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: color),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            _compactNumber(bucket.playCount),
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );

    final wrapped = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: content,
              ),
            ),
          );

    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message:
          '${bucket.label}: ${_trackCountLabel(context, bucket.trackCount)} / '
          '${_playCountLabel(context, bucket.playCount)}',
      child: wrapped,
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityHeatmapCell extends StatelessWidget {
  const _ActivityHeatmapCell({
    required this.day,
    required this.maxValue,
    required this.size,
  });

  final _ActivityHeatmapDay day;
  final int maxValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _t(
      context,
      '${DateFormat.MMMd(_localeName(context)).format(day.date)}: '
          '${_playCountLabel(context, day.playCount)}',
      '${DateFormat.MMMd(_localeName(context)).format(day.date)}: '
          '${_playCountLabel(context, day.playCount)}',
    );

    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _activityHeatmapColor(theme, day.playCount, maxValue),
          borderRadius: BorderRadius.circular(3.5),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }
}

class _OverviewAnalysisCard extends StatelessWidget {
  const _OverviewAnalysisCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.36,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
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
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _AnalysisInlineTooltip extends StatelessWidget {
  const _AnalysisInlineTooltip({
    super.key,
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
    final radius = BorderRadius.circular(14);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: radius,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
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

    final wrapped = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(borderRadius: radius, onTap: onTap, child: content),
          );

    return Padding(padding: const EdgeInsets.only(top: 8), child: wrapped);
  }
}

class _AnalysisPill extends StatelessWidget {
  const _AnalysisPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label  $value',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OverviewInsightPanel extends StatelessWidget {
  const _OverviewInsightPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final number = _numberFormat(context);
    final topArtist = overview.topArtists.isEmpty
        ? null
        : overview.topArtists.first;
    final topAlbum = overview.topAlbums.isEmpty
        ? null
        : overview.topAlbums.first;
    final topArtistTracks = topArtist == null
        ? const <LibraryTrack>[]
        : _tracksByArtist(overview, topArtist.title);
    final topAlbumTrack = overview.trackById(topAlbum?.representativeTrackId);
    final topAlbumTracks = topAlbumTrack == null
        ? const <LibraryTrack>[]
        : _tracksByAlbum(overview, topAlbumTrack);
    final recentTracks = _recentlyPlayedTracks(
      overview.tracks,
      const Duration(days: 30),
    );
    final recentTrackCount = recentTracks.length;
    final unplayedTracks = _unplayedTracks(overview.tracks);
    final unplayedTrackCount = unplayedTracks.length;
    final cloudTracks = _tracksByCloudStatus(overview.tracks, isCloud: true);
    final cloudTrackCount = cloudTracks.length;
    final averagePlays = overview.totalTracks == 0
        ? 0.0
        : overview.totalPlayCount / overview.totalTracks;
    final aboveAverageTracks = _aboveAveragePlayTracks(
      overview.tracks,
      averagePlays,
    );

    final insights = [
      _OverviewInsightValue(
        icon: Icons.person_pin_rounded,
        label: _t(context, 'Favorite artist', 'よく聴くアーティスト'),
        value: topArtist?.title ?? _t(context, 'None', 'なし'),
        detail: topArtist == null
            ? _t(context, 'No plays yet', 'まだ再生がありません')
            : _playCountLabel(context, topArtist.playCount),
        onTap: topArtist == null || topArtistTracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: topArtist.title,
                subtitle: _t(context, 'Artist songs', 'アーティストの曲'),
                icon: Icons.person_pin_rounded,
                tracks: topArtistTracks,
                rankingScope: RankingScope.artists,
                rankingTitle: topArtist.title,
              ),
      ),
      _OverviewInsightValue(
        icon: Icons.album_rounded,
        label: _t(context, 'Favorite album', 'よく聴くアルバム'),
        value:
            topAlbumTrack?.albumTitle ??
            topAlbum?.title ??
            _t(context, 'None', 'なし'),
        detail: topAlbum == null
            ? _t(context, 'No plays yet', 'まだ再生がありません')
            : _playCountLabel(context, topAlbum.playCount),
        onTap:
            topAlbum == null || topAlbumTrack == null || topAlbumTracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: topAlbumTrack.albumTitle,
                subtitle: topAlbumTrack.albumArtist ?? topAlbumTrack.artist,
                icon: Icons.album_rounded,
                tracks: topAlbumTracks,
                rankingScope: RankingScope.albums,
                rankingTitle: _albumRankingTitle(topAlbumTrack),
              ),
      ),
      _OverviewInsightValue(
        icon: Icons.history_rounded,
        label: _t(context, 'Recent 30d', '直近30日'),
        value: number.format(recentTrackCount),
        detail: _percentageDetail(
          context,
          recentTrackCount,
          overview.totalTracks,
        ),
        onTap: recentTracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: _t(context, 'Recent 30 days', '直近30日'),
                subtitle: _t(
                  context,
                  'Songs played in the last 30 days',
                  '30日以内に再生した曲',
                ),
                icon: Icons.history_rounded,
                tracks: recentTracks,
              ),
      ),
      _OverviewInsightValue(
        icon: Icons.radio_button_unchecked_rounded,
        label: _t(context, 'Unplayed', '未再生'),
        value: number.format(unplayedTrackCount),
        detail: _percentageDetail(
          context,
          unplayedTrackCount,
          overview.totalTracks,
        ),
        onTap: unplayedTracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: _t(context, 'Unplayed songs', '未再生の曲'),
                subtitle: _t(context, 'Songs with zero plays', '再生回数が0回の曲'),
                icon: Icons.radio_button_unchecked_rounded,
                tracks: unplayedTracks,
              ),
      ),
      _OverviewInsightValue(
        icon: Icons.repeat_rounded,
        label: _t(context, 'Avg plays', '平均再生'),
        value: averagePlays.toStringAsFixed(1),
        detail: _t(context, 'per track', '1曲あたり'),
        onTap: aboveAverageTracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: _t(context, 'Above average plays', '平均以上の再生曲'),
                subtitle: _t(
                  context,
                  'Songs at or above the library average',
                  'ライブラリ平均以上に再生された曲',
                ),
                icon: Icons.repeat_rounded,
                tracks: aboveAverageTracks,
              ),
      ),
      _OverviewInsightValue(
        icon: Icons.cloud_rounded,
        label: _t(context, 'Cloud items', 'クラウド項目'),
        value: number.format(cloudTrackCount),
        detail: _percentageDetail(
          context,
          cloudTrackCount,
          overview.totalTracks,
        ),
        onTap: cloudTracks.isEmpty
            ? null
            : () => _showTrackGroupSheet(
                context,
                title: _t(context, 'Cloud items', 'クラウド項目'),
                subtitle: _t(
                  context,
                  'Songs marked as cloud library items',
                  'クラウド項目として返された曲',
                ),
                icon: Icons.cloud_rounded,
                tracks: cloudTracks,
              ),
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
            title: _t(context, 'Listening insights', 'リスニング洞察'),
            subtitle: _t(
              context,
              'Different cuts of the current library scan',
              '現在のライブラリスキャンを複数の視点で表示',
            ),
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
      context,
      overview,
      overview.topArtists,
      theme.colorScheme.primary,
    );
    final genreRows = _genreBreakdownRows(context, overview.tracks, theme);
    final sourceRows = _sourceBreakdownRows(context, overview, theme);

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
            title: _t(context, 'Library distribution', 'ライブラリ分布'),
            subtitle: _t(
              context,
              'Where plays and tracks are concentrated',
              '再生と曲数がどこに集中しているか',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final sections = [
                _BreakdownSection(
                  title: _t(context, 'Top artists', '上位アーティスト'),
                  emptyLabel: _t(
                    context,
                    'No artist play data yet.',
                    'アーティスト別の再生データはまだありません。',
                  ),
                  rows: artistRows,
                ),
                _BreakdownSection(
                  title: _t(context, 'Genres', 'ジャンル'),
                  emptyLabel: _t(
                    context,
                    'No genre metadata was returned.',
                    'ジャンル情報は取得されていません。',
                  ),
                  rows: genreRows,
                ),
                _BreakdownSection(
                  title: _t(context, 'Source', 'ソース'),
                  emptyLabel: _t(
                    context,
                    'No source data yet.',
                    'ソース情報はまだありません。',
                  ),
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
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

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
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
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
    final radius = BorderRadius.circular(16);
    final content = DecoratedBox(
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
            if (value.onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );

    if (value.onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: value.onTap, child: content),
    );
  }
}

class _SmartListsPanel extends StatelessWidget {
  const _SmartListsPanel({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    final lists = _smartListsFor(context, overview);
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
            icon: Icons.auto_awesome_motion_rounded,
            title: _t(context, 'Smart lists', 'スマートリスト'),
            subtitle: _t(
              context,
              'Auto-generated views from play counts and metadata',
              '再生回数とメタデータから自動で作る切り口',
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 4
                  : constraints.maxWidth >= 460
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lists.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: columns == 1 ? 3.0 : 1.55,
                ),
                itemBuilder: (context, index) => _SmartListCard(
                  list: lists[index],
                  onTap: lists[index].tracks.isEmpty
                      ? null
                      : () => _showTrackGroupSheet(
                          context,
                          title: lists[index].title,
                          subtitle: lists[index].subtitle,
                          icon: lists[index].icon,
                          tracks: lists[index].tracks,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SmartListCard extends StatelessWidget {
  const _SmartListCard({required this.list, required this.onTap});

  final _SmartListDefinition list;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = list.tracks.take(2).map((track) => track.title).join(', ');
    final radius = BorderRadius.circular(16);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.44,
        ),
        borderRadius: radius,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(list.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    list.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _numberFormat(context).format(list.tracks.length),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              list.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              preview.isEmpty ? list.emptyLabel : preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: preview.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
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
    final content = Column(
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
            if (value.onTap != null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
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

    if (value.onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: value.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: content,
        ),
      ),
    );
  }
}
