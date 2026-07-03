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
        if (stats.snapshotRecordingEnabled) ...[
          const SizedBox(height: 14),
          _SnapshotStatusPanel(
            history: stats.snapshotHistory,
            overview: overview,
            isDemo: overview.isDemo,
          ),
        ],
        const SizedBox(height: 14),
        _SummaryGrid(overview: overview),
        const SizedBox(height: 14),
        _OverviewAnalyticsPanel(
          overview: overview,
          history: stats.snapshotHistory,
          snapshotRecordingEnabled: stats.snapshotRecordingEnabled,
        ),
        if (stats.snapshotRecordingEnabled) ...[
          const SizedBox(height: 14),
          _RecapHighlightsPanel(
            overview: overview,
            history: stats.snapshotHistory,
          ),
        ],
        const SizedBox(height: 14),
        _TasteAndCollectionPanel(
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
