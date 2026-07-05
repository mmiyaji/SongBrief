part of '../home_screen.dart';

void _showListeningMapsDetailSheet(
  BuildContext context, {
  required LibraryOverview overview,
  required SnapshotHistory history,
  required bool snapshotRecordingEnabled,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ListeningMapsDetailSheet(
      overview: overview,
      history: history,
      snapshotRecordingEnabled: snapshotRecordingEnabled,
    ),
  );
}

class _ListeningMapsDetailSheet extends StatelessWidget {
  const _ListeningMapsDetailSheet({
    required this.overview,
    required this.history,
    required this.snapshotRecordingEnabled,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;
  final bool snapshotRecordingEnabled;

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
                          snapshotRecordingEnabled
                              ? _t(
                                  context,
                                  'Inspect playback patterns by year, day, and genre',
                                  '発売年・日別・ジャンル別に再生傾向を確認',
                                )
                              : _t(
                                  context,
                                  'Inspect playback patterns by year and genre',
                                  '発売年・ジャンル別に再生傾向を確認',
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
              if (snapshotRecordingEnabled) ...[
                const SizedBox(height: 14),
                _ActivityHeatmapCard(
                  overview: overview,
                  history: history,
                  expanded: true,
                ),
              ],
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
    required this.snapshotRecordingEnabled,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;
  final bool snapshotRecordingEnabled;

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
            subtitle: snapshotRecordingEnabled
                ? _t(
                    context,
                    'Release-year concentration and daily play activity',
                    '発売年ごとの集中度と日別の再生活動',
                  )
                : _t(
                    context,
                    'Release-year concentration from the current library',
                    '現在のライブラリから発売年ごとの集中度を表示',
                  ),
            trailing: IconButton.filledTonal(
              onPressed: () => _showListeningMapsDetailSheet(
                context,
                overview: overview,
                history: history,
                snapshotRecordingEnabled: snapshotRecordingEnabled,
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

              if (!snapshotRecordingEnabled) {
                return releaseCard;
              }

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

enum _ReleaseYearMetric {
  plays,
  tracks;

  double valueFor(_ReleaseYearBucket bucket) {
    return switch (this) {
      _ReleaseYearMetric.plays => bucket.playCount.toDouble(),
      _ReleaseYearMetric.tracks => bucket.trackCount.toDouble(),
    };
  }
}

class _ReleaseYearPlayMapCard extends StatefulWidget {
  const _ReleaseYearPlayMapCard({
    required this.overview,
    this.expanded = false,
  });

  final LibraryOverview overview;
  final bool expanded;

  @override
  State<_ReleaseYearPlayMapCard> createState() =>
      _ReleaseYearPlayMapCardState();
}

class _ReleaseYearPlayMapCardState extends State<_ReleaseYearPlayMapCard> {
  var _metric = _ReleaseYearMetric.plays;

  @override
  Widget build(BuildContext context) {
    final number = _numberFormat(context);
    final metric = widget.expanded ? _metric : _ReleaseYearMetric.plays;
    final buckets = _releaseYearBuckets(widget.overview.tracks);
    final topBucket = buckets.isEmpty
        ? null
        : buckets.reduce(
            (current, next) => metric.valueFor(next) > metric.valueFor(current)
                ? next
                : current,
          );

    return _OverviewAnalysisCard(
      icon: Icons.timeline_rounded,
      title: _releaseYearMetricTitle(context, metric),
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
              zh: '${topBucket.year} 年的集中度最高',
              ko: '${topBucket.year}년의 집중도가 가장 높습니다',
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
                  metric: metric,
                  height: widget.expanded ? 250 : 190,
                  onOpenBucket: widget.expanded
                      ? (bucket) {
                          final tracks = _tracksByReleaseYear(
                            widget.overview,
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
                if (widget.expanded) ...[
                  const SizedBox(height: 10),
                  _ReleaseYearMetricSelector(
                    metric: metric,
                    onChanged: (value) => setState(() {
                      _metric = value;
                    }),
                  ),
                ],
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
                            '${topBucket.year} / '
                            '${_releaseYearMetricValueLabel(context, metric, topBucket)}',
                      ),
                    _AnalysisPill(
                      label: metric == _ReleaseYearMetric.plays
                          ? _t(context, 'Avg / song', '曲平均')
                          : _t(context, 'Plays', '再生回数'),
                      value: topBucket == null
                          ? '0'
                          : metric == _ReleaseYearMetric.plays
                          ? topBucket.averagePlays.toStringAsFixed(1)
                          : number.format(topBucket.playCount),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ReleaseYearMetricSelector extends StatelessWidget {
  const _ReleaseYearMetricSelector({
    required this.metric,
    required this.onChanged,
  });

  final _ReleaseYearMetric metric;
  final ValueChanged<_ReleaseYearMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<_ReleaseYearMetric>(
        showSelectedIcon: false,
        selected: {metric},
        onSelectionChanged: (values) => onChanged(values.first),
        segments: [
          ButtonSegment(
            value: _ReleaseYearMetric.plays,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_t(context, 'Plays', '再生回数')),
          ),
          ButtonSegment(
            value: _ReleaseYearMetric.tracks,
            icon: const Icon(Icons.music_note_rounded),
            label: Text(_t(context, 'Tracks', '曲')),
          ),
        ],
      ),
    );
  }
}

String _releaseYearMetricTitle(
  BuildContext context,
  _ReleaseYearMetric metric,
) {
  return switch (metric) {
    _ReleaseYearMetric.plays => _t(
      context,
      'Release year x plays',
      '発売年 × 再生数',
    ),
    _ReleaseYearMetric.tracks => _t(
      context,
      'Release year x songs',
      '発売年 × 曲数',
    ),
  };
}

String _releaseYearMetricValueLabel(
  BuildContext context,
  _ReleaseYearMetric metric,
  _ReleaseYearBucket bucket,
) {
  return switch (metric) {
    _ReleaseYearMetric.plays => _playCountLabel(context, bucket.playCount),
    _ReleaseYearMetric.tracks => _trackCountLabel(context, bucket.trackCount),
  };
}

String _releaseYearMetricTooltip(
  BuildContext context,
  _ReleaseYearMetric metric,
  _ReleaseYearBucket bucket,
) {
  return switch (metric) {
    _ReleaseYearMetric.plays =>
      '${_playCountLabel(context, bucket.playCount)} / '
          '${_trackCountLabel(context, bucket.trackCount)}',
    _ReleaseYearMetric.tracks =>
      '${_trackCountLabel(context, bucket.trackCount)} / '
          '${_playCountLabel(context, bucket.playCount)}',
  };
}

String _releaseYearMetricDetail(
  BuildContext context,
  _ReleaseYearMetric metric,
  _ReleaseYearBucket bucket,
) {
  final base = _releaseYearMetricTooltip(context, metric, bucket);
  if (metric == _ReleaseYearMetric.tracks) {
    return base;
  }
  final averageLabel = _t(context, 'avg', '平均', zh: '平均', ko: '평균');
  return '$base / $averageLabel ${bucket.averagePlays.toStringAsFixed(1)}';
}

class _InteractiveReleaseYearChart extends StatefulWidget {
  const _InteractiveReleaseYearChart({
    required this.buckets,
    required this.metric,
    required this.height,
    this.onOpenBucket,
  });

  final List<_ReleaseYearBucket> buckets;
  final _ReleaseYearMetric metric;
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
    final maxMetricValue = buckets.fold<double>(
      1,
      (current, bucket) => math.max(current, widget.metric.valueFor(bucket)),
    );
    final maxY = maxMetricValue <= 1 ? 1.0 : maxMetricValue * 1.18;
    final minYear = buckets.first.year;
    final maxYear = buckets.last.year;
    final yearSpan = maxYear - minYear;
    final minX = (yearSpan == 0 ? minYear - 1 : minYear).toDouble();
    final maxX = (yearSpan == 0 ? maxYear + 1 : maxYear).toDouble();
    final spots = buckets
        .map(
          (bucket) =>
              FlSpot(bucket.year.toDouble(), widget.metric.valueFor(bucket)),
        )
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
                          '${_releaseYearMetricTooltip(context, widget.metric, bucket)}',
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
                  value: _releaseYearMetricDetail(
                    context,
                    widget.metric,
                    selectedBucket,
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

enum _ActivityHeatmapView { calendar, weekdays, highlights }

class _ActivityHeatmapCard extends StatefulWidget {
  const _ActivityHeatmapCard({
    required this.overview,
    required this.history,
    this.expanded = false,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;
  final bool expanded;

  @override
  State<_ActivityHeatmapCard> createState() => _ActivityHeatmapCardState();
}

class _ActivityHeatmapCardState extends State<_ActivityHeatmapCard> {
  _ActivityHeatmapDay? _selectedDay;
  _ActivityHeatmapView _view = _ActivityHeatmapView.calendar;

  @override
  Widget build(BuildContext context) {
    final days = _activityHeatmapDays(
      overview: widget.overview,
      history: widget.history,
    );
    final maxValue = days.fold<int>(
      0,
      (current, day) => math.max(current, day.playCount),
    );
    final summary = _activityHeatmapSummary(days);
    final sourceLabel = widget.history.snapshotCount >= 2
        ? _t(context, 'Listening record changes', '聴取記録の変化')
        : _t(context, 'Recent-track estimate', '最近再生からの推定');
    final selectedDay =
        _validSelectedActivityDay(days, _selectedDay) ??
        summary.peakDay ??
        (days.isEmpty ? null : days.last);

    return _OverviewAnalysisCard(
      icon: Icons.grid_on_rounded,
      title: _t(context, 'Activity heatmap', '再生ヒートマップ'),
      subtitle: sourceLabel,
      child: maxValue == 0
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'Activity appears after daily listening records are available.',
                '日々の聴取記録がたまると活動量を表示します。',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.expanded) ...[
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_ActivityHeatmapView>(
                      showSelectedIcon: false,
                      segments: _ActivityHeatmapView.values
                          .map(
                            (view) => ButtonSegment<_ActivityHeatmapView>(
                              value: view,
                              label: Text(
                                _activityHeatmapViewLabel(context, view),
                              ),
                            ),
                          )
                          .toList(),
                      selected: {_view},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _view = selection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (widget.expanded
                      ? _view
                      : _ActivityHeatmapView.calendar) {
                    _ActivityHeatmapView.calendar => _ActivityHeatmapCalendar(
                      key: const ValueKey('activity-calendar'),
                      days: days,
                      maxValue: maxValue,
                      selectedDay: selectedDay,
                      expanded: widget.expanded,
                      onSelectDay: (day) {
                        setState(() {
                          _selectedDay = day;
                        });
                      },
                    ),
                    _ActivityHeatmapView.weekdays => _ActivityWeekdayRhythm(
                      key: const ValueKey('activity-weekdays'),
                      days: days,
                    ),
                    _ActivityHeatmapView.highlights => _ActivityHighlights(
                      key: const ValueKey('activity-highlights'),
                      summary: summary,
                      days: days,
                    ),
                  },
                ),
                const SizedBox(height: 12),
                if (selectedDay != null)
                  _ActivityDayDetail(
                    day: selectedDay,
                    sourceLabel: sourceLabel,
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _AnalysisPill(
                      label: _t(context, 'Active days', '再生日'),
                      value: _numberFormat(context).format(summary.activeDays),
                    ),
                    _AnalysisPill(
                      label: _t(context, 'Longest streak', '最長連続'),
                      value: _dayCountLabel(context, summary.longestStreak),
                    ),
                    if (summary.bestWeekday != null)
                      _AnalysisPill(
                        label: _t(context, 'Best weekday', 'よく聴く曜日'),
                        value: _weekdayLabel(context, summary.bestWeekday!),
                      ),
                    const _ActivityHeatmapLegend(),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ActivityHeatmapCalendar extends StatelessWidget {
  const _ActivityHeatmapCalendar({
    super.key,
    required this.days,
    required this.maxValue,
    required this.selectedDay,
    required this.expanded,
    required this.onSelectDay,
  });

  final List<_ActivityHeatmapDay> days;
  final int maxValue;
  final _ActivityHeatmapDay? selectedDay;
  final bool expanded;
  final ValueChanged<_ActivityHeatmapDay> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeks = _activityHeatmapWeeks(days);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = expanded
            ? constraints.maxWidth >= 520
                  ? 18.0
                  : 14.0
            : constraints.maxWidth >= 360
            ? 14.0
            : 12.0;
        final rowHeight = cellSize + 4;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  for (final weekday in _calendarWeekdayOrder)
                    SizedBox(
                      height: rowHeight,
                      width: expanded ? 28 : 22,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _weekdayShortLabel(context, weekday),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _isWeekend(weekday)
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
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
                                    selected: _sameActivityDate(
                                      day,
                                      selectedDay,
                                    ),
                                    onTap: () => onSelectDay(day),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityWeekdayHeader extends StatelessWidget {
  const _ActivityWeekdayHeader({required this.weekday});

  final int weekday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _isWeekend(weekday)
              ? Icons.weekend_rounded
              : Icons.calendar_today_rounded,
          color: _isWeekend(weekday)
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          _weekdayLabel(context, weekday),
          style: theme.textTheme.labelMedium?.copyWith(
            color: _isWeekend(weekday)
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ActivityWeekdayRhythm extends StatelessWidget {
  const _ActivityWeekdayRhythm({super.key, required this.days});

  final List<_ActivityHeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = _weekdayActivityValues(days);
    final maxValue = values.fold<int>(
      1,
      (current, value) => math.max(current, value.playCount),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: _ActivityWeekdayHeader(weekday: value.weekday),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value: value.playCount / maxValue,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.52),
                      color: Color.lerp(
                        theme.colorScheme.secondary,
                        theme.colorScheme.primary,
                        value.playCount / maxValue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: Text(
                    _playCountLabel(context, value.playCount),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityDayDetail extends StatelessWidget {
  const _ActivityDayDetail({required this.day, required this.sourceLabel});

  final _ActivityHeatmapDay day;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topTracks = day.trackDeltas.take(3).toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t(context, 'Selected day', '選択中の日'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _playCountLabel(context, day.playCount),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat.yMMMd(_localeName(context)).format(day.date)}'
              ' (${_weekdayLabel(context, day.date.weekday)}) / $sourceLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (topTracks.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final track in topTracks)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${track.title} - ${track.artist}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${_numberFormat(context).format(track.playDelta)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                _t(
                  context,
                  'Song detail is unavailable for this day.',
                  'この日の曲別詳細はありません。',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityHighlights extends StatelessWidget {
  const _ActivityHighlights({
    super.key,
    required this.summary,
    required this.days,
  });

  final _ActivityHeatmapSummary summary;
  final List<_ActivityHeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    final peakDay = summary.peakDay;
    final calmDays = days.where((day) => day.playCount == 0).length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActivityMetricTile(
          icon: Icons.local_fire_department_rounded,
          label: _t(context, 'Peak day', 'ピーク日'),
          value: peakDay == null
              ? '-'
              : DateFormat.MMMd(_localeName(context)).format(peakDay.date),
          detail: peakDay == null
              ? _t(context, 'No activity yet', 'まだ記録がありません')
              : _playCountLabel(context, peakDay.playCount),
        ),
        _ActivityMetricTile(
          icon: Icons.show_chart_rounded,
          label: _t(context, 'Current streak', '現在の連続'),
          value: _dayCountLabel(context, summary.currentStreak),
          detail: _t(
            context,
            'Consecutive active days ending today',
            '今日まで続いている再生日数',
          ),
        ),
        _ActivityMetricTile(
          icon: Icons.timeline_rounded,
          label: _t(context, 'Longest streak', '最長連続'),
          value: _dayCountLabel(context, summary.longestStreak),
          detail: _t(context, 'Best run in this range', 'この期間で最長の流れ'),
        ),
        _ActivityMetricTile(
          icon: Icons.nights_stay_rounded,
          label: _t(context, 'Quiet days', '静かな日'),
          value: _dayCountLabel(context, calmDays),
          detail: _t(context, 'Days without detected plays', '再生増加がない日'),
        ),
      ],
    );
  }
}

class _ActivityMetricTile extends StatelessWidget {
  const _ActivityMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.34,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
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
      ),
    );
  }
}

class _ActivityHeatmapLegend extends StatelessWidget {
  const _ActivityHeatmapLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    required this.selected,
    required this.onTap,
  });

  final _ActivityHeatmapDay day;
  final int maxValue;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _activityHeatmapColor(theme, day.playCount, maxValue);
    final ratio = maxValue <= 0 ? 0.0 : (day.playCount / maxValue).clamp(0, 1);
    final label = _t(
      context,
      '${DateFormat.MMMd(_localeName(context)).format(day.date)}: '
          '${_playCountLabel(context, day.playCount)}',
      '${DateFormat.MMMd(_localeName(context)).format(day.date)}: '
          '${_playCountLabel(context, day.playCount)}',
      zh:
          '${DateFormat.MMMd(_localeName(context)).format(day.date)}：'
          '${_playCountLabel(context, day.playCount)}',
      ko:
          '${DateFormat.MMMd(_localeName(context)).format(day.date)}: '
          '${_playCountLabel(context, day.playCount)}',
    );

    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          margin: const EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.all(selected ? 2 : 1.5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.42,
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              height: day.playCount <= 0 ? 0 : math.max(3, (size - 4) * ratio),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
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
