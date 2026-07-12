part of '../home_screen.dart';

final _cacheUsageRevisionProvider =
    NotifierProvider<_CacheUsageRevisionController, int>(
      _CacheUsageRevisionController.new,
    );

class _CacheUsageRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() {
    state += 1;
  }
}

class _RankingPanel extends ConsumerWidget {
  const _RankingPanel({
    required this.overview,
    required this.history,
    required this.snapshotRecordingEnabled,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;
  final bool snapshotRecordingEnabled;

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
    final useCompactScopeLabels = MediaQuery.sizeOf(context).width < 480;
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
                tooltip: _t(context, 'Refresh', '更新'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<RankingScope>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const WidgetStatePropertyAll(Size.zero),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              ),
              side: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return BorderSide(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.55)
                      : theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.48,
                        ),
                );
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return theme.colorScheme.primary.withValues(alpha: 0.18);
                }
                return theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.72,
                );
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return theme.colorScheme.primary;
                }
                return theme.colorScheme.onSurfaceVariant;
              }),
            ),
            segments: RankingScope.values
                .map(
                  (value) => ButtonSegment<RankingScope>(
                    value: value,
                    label: Text(
                      useCompactScopeLabels
                          ? _rankingScopeCompactLabel(context, value)
                          : _rankingScopeLabel(context, value),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                )
                .toList(),
            selected: {scope},
            onSelectionChanged: (selection) {
              ref.read(rankingFocusProvider.notifier).clear();
              ref.read(rankingScopeProvider.notifier).setScope(selection.first);
            },
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
          const SizedBox(height: 22),
          _RankingExtensions(
            overview: overview,
            history: history,
            snapshotRecordingEnabled: snapshotRecordingEnabled,
          ),
          const SizedBox(height: 14),
          AdBannerSlot(placement: _t(context, 'Rankings', 'ランキング')),
        ],
      ),
    );
  }
}

class _RankingExtensions extends StatelessWidget {
  const _RankingExtensions({
    required this.overview,
    required this.history,
    required this.snapshotRecordingEnabled,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;
  final bool snapshotRecordingEnabled;

  @override
  Widget build(BuildContext context) {
    final rediscoveryItems = _rediscoveryRankingItems(overview);
    final showSnapshotSections =
        snapshotRecordingEnabled && history.snapshots.length >= 2;
    final showSnapshotHint =
        snapshotRecordingEnabled && history.snapshots.length < 2;

    if (!showSnapshotSections &&
        !showSnapshotHint &&
        rediscoveryItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_graph_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _t(context, 'More rankings', 'ランキングを深掘り'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            context,
            'The main ranking stays above. These views add period, momentum, rediscovery, and movement context.',
            '上のメインランキングはそのままに、期間・勢い・再発見・順位変動の視点を追加します。',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showSnapshotSections) ...[
          const SizedBox(height: 16),
          _PeriodRankingSection(overview: overview, history: history),
          const SizedBox(height: 18),
          _RisingRankingSection(overview: overview, history: history),
          const SizedBox(height: 18),
          _RankMovementSection(overview: overview, history: history),
        ] else if (showSnapshotHint) ...[
          const SizedBox(height: 16),
          _RankingInsightEmpty(
            text: _t(
              context,
              'Period, rising, and rank-change rankings appear after records from two different days are available.',
              '期間別・急上昇・順位変動ランキングは、別の日の記録がもう1回分たまると表示できます。',
            ),
          ),
        ],
        if (rediscoveryItems.isNotEmpty) ...[
          const SizedBox(height: 18),
          _RediscoveryRankingSection(
            overview: overview,
            items: rediscoveryItems,
          ),
        ],
      ],
    );
  }
}

class _PeriodRankingSection extends StatefulWidget {
  const _PeriodRankingSection({required this.overview, required this.history});

  final LibraryOverview overview;
  final SnapshotHistory history;

  @override
  State<_PeriodRankingSection> createState() => _PeriodRankingSectionState();
}

class _PeriodRankingSectionState extends State<_PeriodRankingSection> {
  TrendRange _range = TrendRange.week;

  @override
  Widget build(BuildContext context) {
    final items = _periodRankingItems(
      overview: widget.overview,
      history: widget.history,
      range: _range,
    );
    return _RankingInsightSection(
      icon: Icons.date_range_rounded,
      title: _t(context, 'Period movers', '期間別ランキング'),
      subtitle: _t(
        context,
        'Tracks ranked by play-count increases within the selected record range.',
        '選択した期間の聴取記録で増えた再生数順です。',
      ),
      trailing: SegmentedButton<TrendRange>(
        showSelectedIcon: false,
        style: _compactSegmentedStyle(context),
        segments: TrendRange.values
            .map(
              (range) => ButtonSegment<TrendRange>(
                value: range,
                label: Text(_trendRangeLabel(context, range)),
              ),
            )
            .toList(),
        selected: {_range},
        onSelectionChanged: (selection) {
          setState(() => _range = selection.first);
        },
      ),
      child: _RankingInsightList(
        overview: widget.overview,
        items: items,
        emptyText: _t(
          context,
          'No play-count increases were found in this range yet.',
          'この期間の再生数増加はまだ見つかりません。',
        ),
        metricBuilder: (context, item) =>
            '+${_numberFormat(context).format(item.value)}',
        detailBuilder: (context, item) => _t(context, 'period gain', '期間増加'),
      ),
    );
  }
}

class _RisingRankingSection extends StatelessWidget {
  const _RisingRankingSection({required this.overview, required this.history});

  final LibraryOverview overview;
  final SnapshotHistory history;

  @override
  Widget build(BuildContext context) {
    final items = _risingRankingItems(overview: overview, history: history);
    return _RankingInsightSection(
      icon: Icons.trending_up_rounded,
      title: _t(context, 'Rising now', '急上昇'),
      subtitle: _t(
        context,
        'Biggest increases since the previous daily record.',
        '前回の聴取記録から伸びた曲です。',
      ),
      child: _RankingInsightList(
        overview: overview,
        items: items,
        emptyText: _t(
          context,
          'No recent increases were found yet.',
          '直近の増加はまだ見つかりません。',
        ),
        metricBuilder: (context, item) =>
            '+${_numberFormat(context).format(item.value)}',
        detailBuilder: (context, item) =>
            _t(context, 'since previous record', '前回比'),
      ),
    );
  }
}

class _RediscoveryRankingSection extends StatelessWidget {
  const _RediscoveryRankingSection({
    required this.overview,
    required this.items,
  });

  final LibraryOverview overview;
  final List<_RankingInsightItem> items;

  @override
  Widget build(BuildContext context) {
    return _RankingInsightSection(
      icon: Icons.history_toggle_off_rounded,
      title: _t(context, 'Rediscovery', '再発見'),
      subtitle: _t(
        context,
        'High-play favorites that have been quiet for 90 days or more.',
        '再生回数は多いのに90日以上聴いていない曲です。',
      ),
      child: _RankingInsightList(
        overview: overview,
        items: items,
        emptyText: _t(
          context,
          'No rediscovery candidates right now.',
          '今は再発見候補がありません。',
        ),
        metricBuilder: (context, item) => _t(
          context,
          '${_numberFormat(context).format(item.value)}d',
          '${_numberFormat(context).format(item.value)}日',
          zh: '${_numberFormat(context).format(item.value)}天',
          ko: '${_numberFormat(context).format(item.value)}일',
        ),
        detailBuilder: (context, item) => _t(context, 'not played', '未再生'),
      ),
    );
  }
}

class _RankMovementSection extends StatelessWidget {
  const _RankMovementSection({required this.overview, required this.history});

  final LibraryOverview overview;
  final SnapshotHistory history;

  @override
  Widget build(BuildContext context) {
    final items = _rankMovementItems(overview: overview, history: history);
    return _RankingInsightSection(
      icon: Icons.swap_vert_rounded,
      title: _t(context, 'Rank changes', '順位変動'),
      subtitle: _t(
        context,
        'Largest ranking movements compared with the previous record.',
        '前回の記録時点の順位から大きく動いた曲です。',
      ),
      child: _RankingInsightList(
        overview: overview,
        items: items,
        emptyText: _t(
          context,
          'No ranking movement was found yet.',
          '順位変動はまだ見つかりません。',
        ),
        metricBuilder: (context, item) {
          final movement = item.value;
          if (movement > 0) {
            return '+$movement';
          }
          return movement.toString();
        },
        detailBuilder: (context, item) {
          final previousRank = item.previousRank;
          final currentRank = item.currentRank;
          if (previousRank == null || currentRank == null) {
            return _t(context, 'rank movement', '順位変動');
          }
          return _t(
            context,
            '#$previousRank to #$currentRank',
            '#$previousRank → #$currentRank',
            zh: '#$previousRank → #$currentRank',
            ko: '#$previousRank → #$currentRank',
          );
        },
      ),
    );
  }
}

class _RankingInsightSection extends StatelessWidget {
  const _RankingInsightSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
        if (trailing != null) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: trailing!),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _RankingInsightList extends ConsumerWidget {
  const _RankingInsightList({
    required this.overview,
    required this.items,
    required this.emptyText,
    required this.metricBuilder,
    required this.detailBuilder,
  });

  final LibraryOverview overview;
  final List<_RankingInsightItem> items;
  final String emptyText;
  final String Function(BuildContext context, _RankingInsightItem item)
  metricBuilder;
  final String Function(BuildContext context, _RankingInsightItem item)
  detailBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return _RankingInsightEmpty(text: emptyText);
    }

    return Column(
      children: items.indexed
          .map(
            (indexed) => _RankingInsightRow(
              rank: indexed.$1 + 1,
              overview: overview,
              item: indexed.$2,
              metric: metricBuilder(context, indexed.$2),
              detail: detailBuilder(context, indexed.$2),
            ),
          )
          .toList(),
    );
  }
}

class _RankingInsightRow extends ConsumerWidget {
  const _RankingInsightRow({
    required this.rank,
    required this.overview,
    required this.item,
    required this.metric,
    required this.detail,
  });

  final int rank;
  final LibraryOverview overview;
  final _RankingInsightItem item;
  final String metric;
  final String detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final track = overview.trackById(item.trackId);
    final artwork = track == null
        ? const AsyncData<Uint8List?>(null)
        : ref.watch(trackArtworkProvider(track.id));
    final entry = RankingEntry(
      title: item.title,
      subtitle: item.subtitle,
      playCount: item.value.abs(),
      skipCount: 0,
      listeningSeconds: 0,
      kind: RankingEntryKind.track,
      representativeTrackId: item.trackId,
    );
    final metricColor = item.value < 0
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _RankingArtwork(
            entry: entry,
            track: track,
            artwork: artwork,
            scope: RankingScope.tracks,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
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
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: metricColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: metricColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: Text(
                      metric,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: metricColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
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

    if (track == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTrackDetailSheet(context, track),
      child: content,
    );
  }
}

class _RankingInsightEmpty extends StatelessWidget {
  const _RankingInsightEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingInsightItem {
  const _RankingInsightItem({
    required this.trackId,
    required this.title,
    required this.subtitle,
    required this.value,
    this.previousRank,
    this.currentRank,
  });

  final String trackId;
  final String title;
  final String subtitle;
  final int value;
  final int? previousRank;
  final int? currentRank;
}

ButtonStyle _compactSegmentedStyle(BuildContext context) {
  final theme = Theme.of(context);
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    side: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return BorderSide(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.55)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      );
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return theme.colorScheme.primary.withValues(alpha: 0.18);
      }
      return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return theme.colorScheme.primary;
      }
      return theme.colorScheme.onSurfaceVariant;
    }),
  );
}

List<_RankingInsightItem> _periodRankingItems({
  required LibraryOverview overview,
  required SnapshotHistory history,
  required TrendRange range,
}) {
  final delta = _snapshotDeltaForRange(history, range);
  if (delta == null) {
    return const [];
  }
  return _rankingItemsFromDeltas(overview, delta.trackDeltas).take(5).toList();
}

List<_RankingInsightItem> _risingRankingItems({
  required LibraryOverview overview,
  required SnapshotHistory history,
}) {
  final delta = history.latestDelta;
  if (delta == null) {
    return const [];
  }
  return _rankingItemsFromDeltas(overview, delta.trackDeltas).take(5).toList();
}

List<_RankingInsightItem> _rediscoveryRankingItems(LibraryOverview overview) {
  final now = DateTime.now();
  final ranked = overview.tracksByPlayCount;
  final thresholdIndex = ranked.isEmpty
      ? 0
      : math.min(ranked.length - 1, (ranked.length * 0.65).floor());
  final minimumPlays = ranked.isEmpty
      ? 5
      : math.max(5, ranked[thresholdIndex].playCount);
  final items = <_RankingInsightItem>[];
  for (final track in ranked) {
    final playedAt = track.lastPlayedAt;
    if (playedAt == null) {
      continue;
    }
    final daysSincePlayed = now.difference(playedAt).inDays;
    if (track.playCount < minimumPlays || daysSincePlayed < 90) {
      continue;
    }
    items.add(
      _RankingInsightItem(
        trackId: track.id,
        title: track.title,
        subtitle: '${track.artist} - ${track.albumTitle}',
        value: daysSincePlayed,
      ),
    );
    if (items.length >= 5) {
      break;
    }
  }
  return List.unmodifiable(items);
}

List<_RankingInsightItem> _rankMovementItems({
  required LibraryOverview overview,
  required SnapshotHistory history,
}) {
  final previous = history.previous;
  if (previous == null) {
    return const [];
  }

  final previousRanks = _snapshotTrackRanks(previous);
  final items = <_RankingInsightItem>[];
  for (final indexed in overview.tracksByPlayCount.indexed) {
    final track = indexed.$2;
    final currentRank = indexed.$1 + 1;
    final previousRank = previousRanks[track.id];
    if (previousRank == null) {
      continue;
    }
    final movement = previousRank - currentRank;
    if (movement == 0) {
      continue;
    }
    items.add(
      _RankingInsightItem(
        trackId: track.id,
        title: track.title,
        subtitle: '${track.artist} - ${track.albumTitle}',
        value: movement,
        previousRank: previousRank,
        currentRank: currentRank,
      ),
    );
  }
  items.sort((a, b) {
    final byMagnitude = b.value.abs().compareTo(a.value.abs());
    if (byMagnitude != 0) {
      return byMagnitude;
    }
    final byDirection = b.value.compareTo(a.value);
    if (byDirection != 0) {
      return byDirection;
    }
    return (a.currentRank ?? 999999).compareTo(b.currentRank ?? 999999);
  });
  return List.unmodifiable(items.take(5));
}

SnapshotDelta? _snapshotDeltaForRange(
  SnapshotHistory history,
  TrendRange range,
) {
  if (history.snapshots.length < 2) {
    return null;
  }
  final snapshots = history.snapshots.toList(growable: false)
    ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  final current = snapshots.last;
  final windowStart = _localDateOnly(
    current.capturedAt,
  ).subtract(_rankingRangeDuration(range));
  DailyLibrarySnapshot? baseline;
  for (final snapshot in snapshots) {
    if (!_localDateOnly(snapshot.capturedAt).isAfter(windowStart)) {
      baseline = snapshot;
    }
  }
  baseline ??= snapshots.first;
  if (baseline.dateKey == current.dateKey) {
    return null;
  }
  return SnapshotDelta.compare(previous: baseline, current: current);
}

Duration _rankingRangeDuration(TrendRange range) {
  return switch (range) {
    TrendRange.week => const Duration(days: 7),
    TrendRange.month => const Duration(days: 28),
    TrendRange.year => const Duration(days: 365),
  };
}

List<_RankingInsightItem> _rankingItemsFromDeltas(
  LibraryOverview overview,
  Iterable<TrackCounterDelta> deltas,
) {
  final items = <_RankingInsightItem>[];
  for (final delta in deltas) {
    if (delta.playDelta <= 0 || overview.trackById(delta.id) == null) {
      continue;
    }
    items.add(
      _RankingInsightItem(
        trackId: delta.id,
        title: delta.title,
        subtitle: '${delta.artist} - ${delta.albumTitle}',
        value: delta.playDelta,
      ),
    );
  }
  return List.unmodifiable(items);
}

Map<String, int> _snapshotTrackRanks(DailyLibrarySnapshot snapshot) {
  final tracks = snapshot.tracks.toList(growable: false)
    ..sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      if (byPlays != 0) {
        return byPlays;
      }
      final bySeconds = b.listeningSeconds.compareTo(a.listeningSeconds);
      if (bySeconds != 0) {
        return bySeconds;
      }
      return a.title.compareTo(b.title);
    });
  return {for (final indexed in tracks.indexed) indexed.$2.id: indexed.$1 + 1};
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
    final tracks = overview.filteredTracks(_query);
    if (_mode == _LibraryBrowseMode.songs) {
      return tracks.length;
    }
    return _libraryGroupsForMode(context, _mode, tracks, _sort).length;
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    if (!overview.hasTracks) {
      return const _EmptyLibraryPanel();
    }

    final filteredTracks = overview.filteredTracks(_query);
    final sortedTracks = _libraryTracksForSort(overview, filteredTracks, _sort);
    final groups = _mode == _LibraryBrowseMode.songs
        ? const <_LibraryGroupEntry>[]
        : _libraryGroupsForMode(context, _mode, filteredTracks, _sort);
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
        const SizedBox(height: 14),
        AdBannerSlot(placement: _t(context, 'Library', 'ライブラリ')),
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
    final number = _numberFormat(context);
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
              zh: '${number.format(resultCount)} 个${_libraryBrowseModeLabel(context, mode)}匹配',
              ko: '${number.format(resultCount)}개 ${_libraryBrowseModeLabel(context, mode)} 일치',
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
                'Search songs, artists, albums, genres, or playlists',
                '曲、アーティスト、アルバム、ジャンル、プレイリストを検索',
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
              Widget modeControl({required double minWidth}) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minWidth),
                    child: SegmentedButton<_LibraryBrowseMode>(
                      showSelectedIcon: false,
                      segments: _LibraryBrowseMode.values
                          .map(
                            (value) => ButtonSegment<_LibraryBrowseMode>(
                              value: value,
                              icon: Icon(value.icon, size: 18),
                              label: Text(
                                _libraryBrowseModeLabel(context, value),
                              ),
                            ),
                          )
                          .toList(),
                      selected: {mode},
                      onSelectionChanged: (selection) {
                        onModeChanged(selection.first);
                      },
                    ),
                  ),
                );
              }

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

              final shouldStackControls = constraints.maxWidth < 940;
              if (shouldStackControls) {
                final sortWidth = constraints.maxWidth < 620
                    ? constraints.maxWidth
                    : 260.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    modeControl(minWidth: constraints.maxWidth),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(width: sortWidth, child: sortControl),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: modeControl(minWidth: constraints.maxWidth - 234),
                  ),
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
            title: _t(context, 'Songs', '曲'),
            subtitle: _t(
              context,
              'Searchable track details with play controls',
              '検索可能な曲詳細と再生コントロール',
            ),
          ),
          const SizedBox(height: 12),
          if (totalCount == 0)
            Text(
              _t(
                context,
                'No songs matched the current search.',
                '現在の検索に一致する曲はありません。',
              ),
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
    final number = _numberFormat(context);
    final artwork = ref.watch(trackArtworkProvider(track.id));
    final playback = ref.watch(playbackControllerProvider);
    final busy = playback.isBusy;
    final isPlaying = playback.isTrackPlaying(track.id);

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
                          value: _shortPlayedAtLabel(
                            context,
                            track.lastPlayedAt,
                          ),
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
                            .toggleTrack(track.id);
                      },
                tooltip: isPlaying
                    ? _t(context, 'Pause', '一時停止')
                    : _t(context, 'Play', '再生'),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
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
                zh: '当前搜索没有匹配的${_libraryBrowseModeLabel(context, mode)}。',
                ko: '현재 검색과 일치하는 ${_libraryBrowseModeLabel(context, mode)} 항목이 없습니다.',
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
    final number = _numberFormat(context);
    final representative = group.representativeTrack;
    final artwork = representative == null
        ? const AsyncData<Uint8List?>(null)
        : ref.watch(trackArtworkProvider(representative.id));
    final webSearchQuery = _webSearchQueryForLibraryGroup(group);

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
          webSearchQuery: webSearchQuery,
          webSearchSubject: group.title,
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
                    _trackCountLabel(context, group.trackCount),
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
    final number = _numberFormat(context);
    final metrics = [
      _InlineMetricData(
        label: _t(context, 'Artists', 'アーティスト'),
        value: number.format(overview.totalArtists),
        icon: Icons.person,
      ),
      _InlineMetricData(
        label: _t(context, 'Albums', 'アルバム'),
        value: number.format(overview.totalAlbums),
        icon: Icons.album,
      ),
      _InlineMetricData(
        label: _t(context, 'Tracks', '曲'),
        value: number.format(overview.totalTracks),
        icon: Icons.music_note,
      ),
      _InlineMetricData(
        label: _t(context, 'Playlists', 'プレイリスト'),
        value: number.format(_playlistCountForTracks(overview.tracks)),
        icon: Icons.playlist_play,
      ),
    ];

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x62FFFFFF),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 18,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: itemWidth,
                    child: _InlineMetric.fromData(metric),
                  ),
              ],
            );
          }

          return Row(
            children: [
              for (final metric in metrics)
                Expanded(child: _InlineMetric.fromData(metric)),
            ],
          );
        },
      ),
    );
  }
}

class _InlineMetricData {
  const _InlineMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  factory _InlineMetric.fromData(_InlineMetricData data) {
    return _InlineMetric(label: data.label, value: data.value, icon: data.icon);
  }

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
              _t(context, 'No entries yet.', 'まだ項目がありません。'),
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
    final number = _numberFormat(context);
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
    final number = _numberFormat(context);
    final remainingCount = totalCount - shownCount;
    final actualNextCount = _clampInt(nextCount, 0, remainingCount);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: remainingCount <= 0 ? null : onPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _t(
            context,
            'Show ${number.format(actualNextCount)} more',
            'さらに${number.format(actualNextCount)}件表示',
            zh: '再显示 ${number.format(actualNextCount)} 项',
            ko: '${number.format(actualNextCount)}개 더 보기',
          ),
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
    final selectedBrightness = ref.watch(themeBrightnessProvider);
    final selectedLanguage = ref.watch(appLanguageProvider);
    final appLock = ref.watch(appLockControllerProvider);
    final crashReporting = ref.watch(crashReportingControllerProvider);
    final libraryFilters = ref.watch(libraryFilterPreferencesProvider);
    final temporaryDemoLibraryEnabled = ref.watch(temporaryDemoLibraryProvider);
    final appVersion = ref
        .watch(_appVersionLabelProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => _fallbackAppVersionLabel,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo) ...[
          _AuthorizationPanel(status: stats.authorizationStatus),
          const SizedBox(height: 14),
        ],
        _SettingsGroup(
          title: _t(context, 'Music Access', 'ミュージックアクセス'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsRow(
                icon: Icons.privacy_tip,
                label: _t(context, 'Authorization', '認証状態'),
                value: overview.isDemo
                    ? _t(context, 'Demo mode', 'デモモード')
                    : _authorizationLabel(context, stats.authorizationStatus),
              ),
              _SettingsRow(
                icon: Icons.storage,
                label: _t(context, 'Data source', 'データソース'),
                value: overview.isDemo
                    ? _t(context, 'Sample library', 'サンプルライブラリ')
                    : _t(context, 'iOS Music library', 'iOSミュージックライブラリ'),
              ),
              const SizedBox(height: 10),
              _TemporaryDemoLibrarySetting(
                enabled: temporaryDemoLibraryEnabled,
                stats: stats,
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.update,
                label: _t(context, 'Last record', '最終記録'),
                value: stats.snapshotRecordingEnabled
                    ? _dateTimeFormat(context).format(overview.generatedAt)
                    : _t(context, 'Off', 'オフ'),
              ),
              const SizedBox(height: 12),
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
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'Display & Operation', '表示と操作'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreferenceSelectorTile<SongBriefThemeStyle>(
                icon: Icons.palette_outlined,
                label: _t(context, 'Theme', 'テーマ'),
                valueLabel: _themeStyleLabel(context, selectedTheme),
                valueLeading: _ThemeStyleSwatch(style: selectedTheme),
                description: _themeStyleDescription(context, selectedTheme),
                selected: selectedTheme,
                options: [
                  for (final style in SongBriefThemeStyle.values)
                    _PreferenceOption(
                      value: style,
                      label: _themeStyleLabel(context, style),
                      description: _themeStyleDescription(context, style),
                      leading: _ThemeStyleSwatch(style: style),
                    ),
                ],
                onChanged: (style) {
                  ref.read(themeStyleProvider.notifier).setStyle(style);
                },
              ),
              const SizedBox(height: 10),
              _PreferenceSelectorTile<SongBriefThemeBrightness>(
                icon: Icons.contrast_rounded,
                label: _t(context, 'Appearance', '外観'),
                valueLabel: _themeBrightnessLabel(context, selectedBrightness),
                description: _themeBrightnessDescription(
                  context,
                  selectedBrightness,
                ),
                selected: selectedBrightness,
                options: [
                  for (final brightness in SongBriefThemeBrightness.values)
                    _PreferenceOption(
                      value: brightness,
                      label: _themeBrightnessLabel(context, brightness),
                      description: _themeBrightnessDescription(
                        context,
                        brightness,
                      ),
                    ),
                ],
                onChanged: (brightness) {
                  ref
                      .read(themeBrightnessProvider.notifier)
                      .setBrightness(brightness);
                },
              ),
              const SizedBox(height: 10),
              _PreferenceSelectorTile<AppLanguage>(
                icon: Icons.language_rounded,
                label: _t(context, 'Language', '言語'),
                valueLabel: _languageLabel(context, selectedLanguage),
                description: _languageDescription(context, selectedLanguage),
                selected: selectedLanguage,
                options: [
                  for (final language in AppLanguage.values)
                    _PreferenceOption(
                      value: language,
                      label: _languageLabel(context, language),
                      description: _languageDescription(context, language),
                    ),
                ],
                onChanged: (language) {
                  ref.read(appLanguageProvider.notifier).setLanguage(language);
                },
              ),
              const SizedBox(height: 18),
              Text(
                _t(context, 'Security', 'セキュリティ'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _AppLockSetting(lockState: appLock),
              const SizedBox(height: 10),
              _CrashReportingSetting(state: crashReporting),
              _AdPrivacySetting(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'Export & Exclusions', 'エクスポートと除外'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExportSetting(stats: stats),
              const SizedBox(height: 16),
              Divider(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                height: 1,
              ),
              const SizedBox(height: 16),
              Text(
                _t(context, 'Display & Exclusions', '表示と除外'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _LibraryFilterSetting(stats: stats, filters: libraryFilters),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'Data Management', 'データ管理'),
          child: _DataManagementSetting(stats: stats),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'App Info', 'アプリ情報'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsRow(
                icon: Icons.info_outline,
                label: _t(context, 'Application', 'アプリケーション'),
                value: 'SongBrief',
                onTap: () => _openExternalUrl(
                  context,
                  _officialWebsiteUrl,
                  requireConfirmation: true,
                ),
              ),
              _SettingsRow(
                icon: Icons.sell_outlined,
                label: _t(context, 'Version', 'バージョン'),
                value: appVersion,
              ),
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                label: _t(context, 'Author', '作者', zh: '作者', ko: '작성자'),
                value: 'mmiyaji',
                onTap: () => _openExternalUrl(
                  context,
                  _authorUrl,
                  requireConfirmation: true,
                ),
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: _t(context, 'Privacy Policy', 'プライバシーポリシー'),
                value: _t(context, 'Open', '開く'),
                onTap: () => _openExternalUrl(
                  context,
                  _privacyPolicyUrl,
                  requireConfirmation: true,
                ),
              ),
              _SettingsRow(
                icon: Icons.gavel_outlined,
                label: _t(context, 'Terms of Use', '利用規約'),
                value: _t(context, 'Open', '開く'),
                onTap: () => _openExternalUrl(
                  context,
                  _termsOfUseUrl,
                  requireConfirmation: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'SongBrief',
                        applicationVersion: appVersion,
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
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdBannerSlot(placement: _t(context, 'Settings', '設定')),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x62FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TemporaryDemoLibrarySetting extends ConsumerWidget {
  const _TemporaryDemoLibrarySetting({
    required this.enabled,
    required this.stats,
  });

  final bool enabled;
  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realLibraryAvailable =
        stats.authorizationStatus.canReadLibrary && stats.overview.hasTracks;
    final active = enabled && stats.overview.isDemo;
    final description = active
        ? _t(
            context,
            'Temporary demo data is visible. It is not saved or synced.',
            '一時的なデモデータを表示中です。保存や同期の対象にはなりません。',
            zh: '正在显示临时演示数据。它不会被保存或同步。',
            ko: '임시 데모 데이터를 표시 중입니다. 저장되거나 동기화되지 않습니다.',
          )
        : realLibraryAvailable
        ? _t(
            context,
            'Your Music library is available, so real data is shown first.',
            'ミュージックライブラリを利用できるため、実データを優先して表示しています。',
            zh: '可以使用你的音乐资料库，因此优先显示真实数据。',
            ko: '음악 보관함을 사용할 수 있으므로 실제 데이터를 우선 표시합니다.',
          )
        : _t(
            context,
            'When Music access is unavailable or no songs are found, show sample data so you can try the app.',
            'ミュージックにアクセスできない場合や曲が見つからない場合に、アプリを試せるサンプルデータを表示します。',
            zh: '当无法访问音乐或找不到歌曲时，显示示例数据以便试用应用。',
            ko: '음악 접근이 불가능하거나 곡을 찾을 수 없을 때 앱을 시험해 볼 수 있는 샘플 데이터를 표시합니다.',
          );

    return _SettingsSwitchCard(
      icon: Icons.preview_rounded,
      title: _t(
        context,
        'Temporary demo data',
        '一時的なデモデータ',
        zh: '临时演示数据',
        ko: '임시 데모 데이터',
      ),
      description: description,
      value: enabled,
      surfaceAlpha: 0.22,
      onChanged: (value) async {
        if (value) {
          await _enableTemporaryDemoLibrary(context, ref);
          return;
        }
        ref.read(temporaryDemoLibraryProvider.notifier).setEnabled(false);
        await ref.read(musicStatsControllerProvider.notifier).refreshStats();
      },
    );
  }
}

class _SettingsSwitchCard extends StatelessWidget {
  const _SettingsSwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.surfaceAlpha = 0.28,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double surfaceAlpha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: surfaceAlpha,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        secondary: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PreferenceOption<T> {
  const _PreferenceOption({
    required this.value,
    required this.label,
    required this.description,
    this.leading,
  });

  final T value;
  final String label;
  final String description;
  final Widget? leading;
}

class _PreferenceSelectorTile<T> extends StatelessWidget {
  const _PreferenceSelectorTile({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.description,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.valueLeading,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final String description;
  final T selected;
  final List<_PreferenceOption<T>> options;
  final ValueChanged<T> onChanged;
  final Widget? valueLeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showPreferenceSheet<T>(
          context: context,
          title: label,
          selected: selected,
          options: options,
          onChanged: onChanged,
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.22,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final valueWidth = math.min(
                        260.0,
                        math.max(156.0, constraints.maxWidth * 0.38),
                      );
                      final labelColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                      final value = _PreferenceSelectorValue(
                        leading: valueLeading,
                        label: valueLabel,
                      );

                      if (constraints.maxWidth < 430) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            labelColumn,
                            const SizedBox(height: 8),
                            value,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: labelColumn),
                          const SizedBox(width: 16),
                          SizedBox(width: valueWidth, child: value),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSelectorValue extends StatelessWidget {
  const _PreferenceSelectorValue({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showPreferenceSheet<T>({
  required BuildContext context,
  required String title,
  required T selected,
  required List<_PreferenceOption<T>> options,
  required ValueChanged<T> onChanged,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height;
      final maxSheetHeight = height * 0.86;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxSheetHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option.value == selected;
                      return _PreferenceOptionRow<T>(
                        option: option,
                        selected: isSelected,
                        onTap: () {
                          onChanged(option.value);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PreferenceOptionRow<T> extends StatelessWidget {
  const _PreferenceOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PreferenceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: option.label,
      hint: option.description,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.22,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.38)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (option.leading != null) ...[
                              option.leading!,
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                option.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          option.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeStyleSwatch extends StatelessWidget {
  const _ThemeStyleSwatch({required this.style});

  final SongBriefThemeStyle style;

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final colors = _themeStyleSwatchColors(style);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: currentTheme.colorScheme.outlineVariant.withValues(
            alpha: 0.58,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 44,
          height: 20,
          child: CustomPaint(painter: _ThemeStyleSwatchPainter(colors)),
        ),
      ),
    );
  }
}

List<Color> _themeStyleSwatchColors(SongBriefThemeStyle style) {
  return switch (style) {
    SongBriefThemeStyle.prism => const [
      Color(0xFF4DECC7),
      Color(0xFFE0FF67),
      Color(0xFF7B8CFF),
    ],
    SongBriefThemeStyle.flux => const [
      Color(0xFF55DDF7),
      Color(0xFF7EC8FF),
      Color(0xFF8EE7B9),
    ],
    SongBriefThemeStyle.ember => const [
      Color(0xFFFF3D78),
      Color(0xFFFF9B52),
      Color(0xFF6FE5C4),
    ],
    SongBriefThemeStyle.mono => const [
      Color(0xFFEDEDED),
      Color(0xFFA6A6A6),
      Color(0xFF303030),
    ],
    SongBriefThemeStyle.aurora => const [
      Color(0xFFFF8BD8),
      Color(0xFF75D8FF),
      Color(0xFFFFC15A),
    ],
    SongBriefThemeStyle.grove => const [
      Color(0xFFB6EC67),
      Color(0xFF65E6D2),
      Color(0xFFFF9A9C),
    ],
    SongBriefThemeStyle.pulse => const [
      Color(0xFF8CB7FF),
      Color(0xFF60E7D6),
      Color(0xFFFF9AC2),
    ],
    SongBriefThemeStyle.muse => const [
      Color(0xFFDDA8FF),
      Color(0xFF71E4D8),
      Color(0xFFFFB568),
    ],
  };
}

class _ThemeStyleSwatchPainter extends CustomPainter {
  const _ThemeStyleSwatchPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final segmentWidth = size.width / colors.length;
    for (var index = 0; index < colors.length; index += 1) {
      paint.color = colors[index];
      final left = index * segmentWidth;
      final right = index == colors.length - 1
          ? size.width
          : (index + 1) * segmentWidth;
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeStyleSwatchPainter oldDelegate) {
    if (oldDelegate.colors.length != colors.length) {
      return true;
    }
    for (var index = 0; index < colors.length; index += 1) {
      if (oldDelegate.colors[index] != colors[index]) {
        return true;
      }
    }
    return false;
  }
}

class _ExportSetting extends StatelessWidget {
  const _ExportSetting({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          icon: Icons.table_chart_outlined,
          label: _t(context, 'Library rows', 'ライブラリ行'),
          value: _trackCountLabel(context, stats.overview.totalTracks),
        ),
        _SettingsRow(
          icon: Icons.calendar_month_outlined,
          label: _t(context, 'Listening records', '聴取記録'),
          value: _dayCountLabel(context, stats.snapshotHistory.snapshotCount),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            context,
            'CSV is suited for spreadsheets. JSON includes listening record summaries for backup or analysis.',
            'CSVは表計算向け、JSONは聴取記録の概要も含む分析・バックアップ向けです。',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  _saveLibraryExport(context, stats, LibraryExportFormat.csv),
              icon: const Icon(Icons.grid_on_rounded),
              label: Text(_t(context, 'Save CSV', 'CSVを保存')),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _saveLibraryExport(context, stats, LibraryExportFormat.json),
              icon: const Icon(Icons.data_object_rounded),
              label: Text(_t(context, 'Save JSON', 'JSONを保存')),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryFilterSetting extends ConsumerWidget {
  const _LibraryFilterSetting({required this.stats, required this.filters});

  final MusicStatsState stats;
  final LibraryFilterPreferences filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          icon: Icons.visibility_off_outlined,
          label: _t(context, 'Active exclusions', '除外ルール'),
          value: _filterRuleCountLabel(context, filters.ruleCount),
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            context,
            'Matching songs are hidden from SongBrief rankings, library, exports, and future records. Your Apple Music library is not changed.',
            '一致する曲をSongBriefのランキング、ライブラリ、エクスポート、今後の聴取記録から除外します。Apple Musicの内容は変更しません。',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.24,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final summaryItems = [
                  _FilterSummaryItem(
                    icon: Icons.playlist_remove_rounded,
                    label: _t(context, 'Playlists', 'プレイリスト'),
                    count: filters.excludedPlaylists.length,
                  ),
                  _FilterSummaryItem(
                    icon: Icons.category_outlined,
                    label: _t(context, 'Genres', 'ジャンル'),
                    count: filters.excludedGenres.length,
                  ),
                  _FilterSummaryItem(
                    icon: Icons.manage_search_rounded,
                    label: _t(context, 'Keywords', 'キーワード'),
                    count: filters.excludedKeywords.length,
                  ),
                ];

                final action = OutlinedButton.icon(
                  onPressed: () =>
                      _showLibraryFilterManagerSheet(context, stats: stats),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(_t(context, 'Manage', '管理')),
                );

                if (constraints.maxWidth >= 620) {
                  return Row(
                    children: [
                      for (final item in summaryItems)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: item,
                          ),
                        ),
                      action,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in summaryItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: item,
                      ),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSummaryItem extends StatelessWidget {
  const _FilterSummaryItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: theme.colorScheme.primary, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          _numberFormat(context).format(count),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

Future<void> _showLibraryFilterManagerSheet(
  BuildContext context, {
  required MusicStatsState stats,
}) {
  final size = MediaQuery.sizeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxWidth: math.min(size.width - 32, 760)),
    builder: (context) => _LibraryFilterManagerSheet(stats: stats),
  );
}

class _LibraryFilterManagerSheet extends ConsumerWidget {
  const _LibraryFilterManagerSheet({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filters = ref.watch(libraryFilterPreferencesProvider);
    final controller = ref.read(libraryFilterPreferencesProvider.notifier);
    final height = MediaQuery.sizeOf(context).height;
    final overview = stats.overview;

    return SafeArea(
      top: false,
      child: DefaultTabController(
        length: 3,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height * 0.86),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(context, 'Manage hidden items', '非表示項目を管理'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _t(
                              context,
                              'Edit exclusion rules without changing your Apple Music library.',
                              'Apple Musicの内容は変更せず、SongBrief上の除外ルールだけを編集します。',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!filters.isEmpty)
                      TextButton.icon(
                        onPressed: controller.clearAll,
                        icon: const Icon(Icons.clear_all_rounded),
                        label: Text(_t(context, 'Clear all', 'すべて解除')),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.playlist_remove_rounded),
                      text:
                          '${_t(context, 'Playlists', 'プレイリスト')} (${filters.excludedPlaylists.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.category_outlined),
                      text:
                          '${_t(context, 'Genres', 'ジャンル')} (${filters.excludedGenres.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.manage_search_rounded),
                      text:
                          '${_t(context, 'Keywords', 'キーワード')} (${filters.excludedKeywords.length})',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: _RuleGroup(
                          icon: Icons.playlist_remove_rounded,
                          title: _t(context, 'Hidden playlists', '非表示プレイリスト'),
                          description: _t(
                            context,
                            'Hide songs that belong to selected playlists.',
                            '選択したプレイリストに含まれる曲を非表示にします。',
                          ),
                          rules: filters.excludedPlaylists,
                          suggestions: _playlistSuggestions(overview, filters),
                          emptyLabel: _t(
                            context,
                            'No hidden playlists',
                            '非表示プレイリストはありません',
                          ),
                          addLabel: _t(context, 'Add playlist', 'プレイリストを追加'),
                          onAdd: () => _addPlaylistExclusion(context, ref),
                          onAddSuggestion: controller.addExcludedPlaylist,
                          onRemove: controller.removeExcludedPlaylist,
                        ),
                      ),
                      SingleChildScrollView(
                        child: _RuleGroup(
                          icon: Icons.category_outlined,
                          title: _t(context, 'Hidden genres', '非表示ジャンル'),
                          description: _t(
                            context,
                            'Hide songs with selected genre names.',
                            '選択したジャンル名の曲を非表示にします。',
                          ),
                          rules: filters.excludedGenres,
                          suggestions: _genreSuggestions(overview, filters),
                          emptyLabel: _t(
                            context,
                            'No hidden genres',
                            '非表示ジャンルはありません',
                          ),
                          addLabel: _t(context, 'Add genre', 'ジャンルを追加'),
                          onAdd: () => _addGenreExclusion(context, ref),
                          onAddSuggestion: controller.addExcludedGenre,
                          onRemove: controller.removeExcludedGenre,
                        ),
                      ),
                      SingleChildScrollView(
                        child: _RuleGroup(
                          icon: Icons.manage_search_rounded,
                          title: _t(context, 'Hidden keywords', '非表示キーワード'),
                          description: _t(
                            context,
                            'Hide songs whose title, artist, album, genre, or playlist contains a keyword.',
                            '曲名、アーティスト、アルバム、ジャンル、プレイリストにキーワードを含む曲を非表示にします。',
                          ),
                          rules: filters.excludedKeywords,
                          suggestions: const <String>[],
                          emptyLabel: _t(
                            context,
                            'No hidden keywords',
                            '非表示キーワードはありません',
                          ),
                          addLabel: _t(context, 'Add keyword', 'キーワードを追加'),
                          onAdd: () => _addKeywordExclusion(context, ref),
                          onAddSuggestion: controller.addExcludedKeyword,
                          onRemove: controller.removeExcludedKeyword,
                        ),
                      ),
                    ],
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

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({
    required this.icon,
    required this.title,
    required this.description,
    required this.rules,
    required this.suggestions,
    required this.emptyLabel,
    required this.addLabel,
    required this.onAdd,
    required this.onAddSuggestion,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> rules;
  final List<String> suggestions;
  final String emptyLabel;
  final String addLabel;
  final VoidCallback onAdd;
  final ValueChanged<String> onAddSuggestion;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.24,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(addLabel),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (rules.isEmpty)
              Text(
                emptyLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rule in rules)
                    InputChip(
                      label: Text(rule),
                      onDeleted: () => onRemove(rule),
                      deleteIcon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _t(context, 'Suggestions', '候補'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in suggestions.take(16))
                    ActionChip(
                      label: Text(suggestion),
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () => onAddSuggestion(suggestion),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _filterRuleCountLabel(BuildContext context, int count) {
  if (count == 0) {
    return _t(context, 'None', 'なし');
  }
  return _t(
    context,
    '$count rules',
    '$count件',
    zh: '$count 条规则',
    ko: '$count개 규칙',
  );
}

Future<void> _addPlaylistExclusion(BuildContext context, WidgetRef ref) async {
  final value = await _showRuleTextDialog(
    context,
    title: _t(context, 'Add hidden playlist', '非表示プレイリストを追加'),
    label: _t(context, 'Playlist name', 'プレイリスト名'),
    helperText: _t(
      context,
      'Songs in matching playlists will be hidden.',
      '一致するプレイリストに含まれる曲を非表示にします。',
    ),
  );
  if (value == null || value.isEmpty) {
    return;
  }
  ref
      .read(libraryFilterPreferencesProvider.notifier)
      .addExcludedPlaylist(value);
}

Future<void> _addGenreExclusion(BuildContext context, WidgetRef ref) async {
  final value = await _showRuleTextDialog(
    context,
    title: _t(context, 'Add hidden genre', '非表示ジャンルを追加'),
    label: _t(context, 'Genre name', 'ジャンル名'),
    helperText: _t(
      context,
      'Songs with a matching genre will be hidden.',
      '一致するジャンルの曲を非表示にします。',
    ),
  );
  if (value == null || value.isEmpty) {
    return;
  }
  ref.read(libraryFilterPreferencesProvider.notifier).addExcludedGenre(value);
}

Future<void> _addKeywordExclusion(BuildContext context, WidgetRef ref) async {
  final value = await _showRuleTextDialog(
    context,
    title: _t(context, 'Add hidden keyword', '非表示キーワードを追加'),
    label: _t(context, 'Keyword', 'キーワード'),
    helperText: _t(
      context,
      'Title, artist, album, genre, and playlist names are checked.',
      '曲名、アーティスト、アルバム、ジャンル、プレイリスト名を対象にします。',
    ),
  );
  if (value == null || value.isEmpty) {
    return;
  }
  ref.read(libraryFilterPreferencesProvider.notifier).addExcludedKeyword(value);
}

Future<String?> _showRuleTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String helperText,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        final value = controller.text.trim();
        if (value.isEmpty) {
          return;
        }
        Navigator.of(dialogContext).pop(value);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(labelText: label, helperText: helperText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t(context, 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: submit,
            child: Text(_t(context, 'Add', '追加')),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result?.trim();
}

List<String> _playlistSuggestions(
  LibraryOverview overview,
  LibraryFilterPreferences filters,
) {
  return _sortedSuggestions(
    overview.tracks.expand((track) => track.playlistNames),
    filters.excludedPlaylists,
  );
}

List<String> _genreSuggestions(
  LibraryOverview overview,
  LibraryFilterPreferences filters,
) {
  return _sortedSuggestions(
    overview.tracks.map((track) => track.genre).whereType<String>(),
    filters.excludedGenres,
  );
}

List<String> _sortedSuggestions(
  Iterable<String> values,
  List<String> excludedRules,
) {
  final excludedKeys = excludedRules.map(_ruleSuggestionKey).toSet();
  final byKey = <String, String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final key = _ruleSuggestionKey(trimmed);
    if (excludedKeys.contains(key)) {
      continue;
    }
    byKey.putIfAbsent(key, () => trimmed);
  }
  final suggestions = byKey.values.toList(growable: false)
    ..sort((a, b) => _ruleSuggestionKey(a).compareTo(_ruleSuggestionKey(b)));
  return suggestions;
}

String _ruleSuggestionKey(String value) => value.trim().toLowerCase();

class _DataManagementSetting extends ConsumerWidget {
  const _DataManagementSetting({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_cacheUsageRevisionProvider);
    final cacheUsage = _currentCacheUsage();
    final snapshotRecordingEnabled = ref.watch(snapshotRecordingProvider);
    final history = stats.snapshotHistory;
    final oldestSnapshot = history.snapshots.isEmpty
        ? null
        : history.snapshots.first;
    final latestSnapshot = history.latest;
    final rangeLabel = oldestSnapshot == null || latestSnapshot == null
        ? _t(context, 'No records', '記録なし')
        : '${DateFormat.Md(_localeName(context)).format(oldestSnapshot.capturedAt)} - '
              '${DateFormat.Md(_localeName(context)).format(latestSnapshot.capturedAt)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SnapshotRecordingSetting(enabled: snapshotRecordingEnabled),
        const SizedBox(height: 10),
        _SnapshotCloudSyncSetting(
          enabled: ref.watch(snapshotCloudSyncProvider),
          recordingEnabled: snapshotRecordingEnabled,
        ),
        const SizedBox(height: 10),
        _SettingsRow(
          icon: Icons.cleaning_services_outlined,
          label: _t(context, 'Temporary caches', '一時キャッシュ'),
          value: _cacheUsageLabel(context, cacheUsage),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () =>
                _showCacheManagementSheet(context, ref, cacheUsage: cacheUsage),
            icon: const Icon(Icons.tune_rounded),
            label: Text(
              _t(context, 'Manage caches', 'キャッシュを管理', zh: '管理缓存', ko: '캐시 관리'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SettingsRow(
          icon: Icons.calendar_month_outlined,
          label: stats.overview.isDemo
              ? _t(context, 'Sample records', 'サンプル記録', zh: '示例记录', ko: '샘플 기록')
              : _t(context, 'Listening record history', '聴取記録の履歴'),
          value:
              '${_dayCountLabel(context, history.snapshotCount)} / $rangeLabel',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: stats.overview.isDemo || history.snapshotCount == 0
                ? null
                : () =>
                      _showListeningRecordManagementSheet(context, ref, stats),
            icon: const Icon(Icons.tune_rounded),
            label: Text(
              _t(context, 'Manage records', '記録を管理', zh: '管理记录', ko: '기록 관리'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SnapshotCloudSyncSetting extends ConsumerWidget {
  const _SnapshotCloudSyncSetting({
    required this.enabled,
    required this.recordingEnabled,
  });

  final bool enabled;
  final bool recordingEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = enabled && recordingEnabled;
    return _SettingsSwitchCard(
      icon: Icons.cloud_sync_rounded,
      title: _t(
        context,
        'Sync records with iCloud',
        'iCloudで聴取記録を同期',
        zh: '通过iCloud同步收听记录',
        ko: 'iCloud로 청취 기록 동기화',
      ),
      description: active
          ? _t(
              context,
              'Daily records merge across devices on the same Apple ID.',
              '同じApple IDの端末間で日々の記録を統合します。',
              zh: '在使用同一Apple ID的设备之间合并每日记录。',
              ko: '동일한 Apple ID의 기기 간에 일일 기록을 병합합니다.',
            )
          : _t(
              context,
              'Records stay only on this device.',
              '記録はこの端末にのみ保存されます。',
              zh: '记录仅保存在此设备上。',
              ko: '기록은 이 기기에만 저장됩니다.',
            ),
      value: enabled,
      onChanged: recordingEnabled
          ? (value) {
              ref.read(snapshotCloudSyncProvider.notifier).setEnabled(value);
            }
          : null,
    );
  }
}

class _SnapshotRecordingSetting extends ConsumerWidget {
  const _SnapshotRecordingSetting({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsSwitchCard(
      icon: Icons.auto_graph_rounded,
      title: _t(context, 'Save daily listening records', '日々の聴取記録を保存'),
      description: enabled
          ? _t(
              context,
              'Record-based trends and recaps are visible.',
              '聴取記録を使った傾向・リキャップを表示します。',
            )
          : _t(
              context,
              'Record-based trends and recaps are hidden.',
              '聴取記録を使った傾向・リキャップは非表示です。',
            ),
      value: enabled,
      onChanged: (value) {
        ref.read(snapshotRecordingProvider.notifier).setEnabled(value);
      },
    );
  }
}

enum _SnapshotRetentionOption {
  days30(30),
  days90(90),
  days180(180);

  const _SnapshotRetentionOption(this.days);

  final int days;
}

String _snapshotRetentionLabel(
  BuildContext context,
  _SnapshotRetentionOption option,
) {
  return switch (option) {
    _SnapshotRetentionOption.days30 => _t(context, 'Keep 30 days', '30日分を保持'),
    _SnapshotRetentionOption.days90 => _t(context, 'Keep 90 days', '90日分を保持'),
    _SnapshotRetentionOption.days180 => _t(
      context,
      'Keep 180 days',
      '180日分を保持',
    ),
  };
}

class _CacheUsage {
  const _CacheUsage({
    required this.bytes,
    required this.imageCount,
    required this.liveImageCount,
    required this.pendingImageCount,
  });

  final int bytes;
  final int imageCount;
  final int liveImageCount;
  final int pendingImageCount;

  bool get hasImages =>
      bytes > 0 ||
      imageCount > 0 ||
      liveImageCount > 0 ||
      pendingImageCount > 0;
}

_CacheUsage _currentCacheUsage() {
  final cache = PaintingBinding.instance.imageCache;
  return _CacheUsage(
    bytes: cache.currentSizeBytes,
    imageCount: cache.currentSize,
    liveImageCount: cache.liveImageCount,
    pendingImageCount: cache.pendingImageCount,
  );
}

String _cacheUsageLabel(BuildContext context, _CacheUsage usage) {
  final imageCount = usage.imageCount + usage.liveImageCount;
  final suffix = imageCount == 1 ? 'image' : 'images';
  return _t(
    context,
    '${_byteSizeLabel(usage.bytes)} / $imageCount $suffix',
    '${_byteSizeLabel(usage.bytes)} / $imageCount件',
    zh: '${_byteSizeLabel(usage.bytes)} / $imageCount 张图片',
    ko: '${_byteSizeLabel(usage.bytes)} / 이미지 $imageCount개',
  );
}

String _cacheUsageDetailLabel(BuildContext context, _CacheUsage usage) {
  final number = _numberFormat(context);
  return _t(
    context,
    'Memory image cache: ${_byteSizeLabel(usage.bytes)}. Cached ${number.format(usage.imageCount)}, live ${number.format(usage.liveImageCount)}, pending ${number.format(usage.pendingImageCount)}.',
    'メモリ画像キャッシュ: ${_byteSizeLabel(usage.bytes)}。保持 ${number.format(usage.imageCount)}件、表示中 ${number.format(usage.liveImageCount)}件、読込中 ${number.format(usage.pendingImageCount)}件。',
    zh: '内存图片缓存：${_byteSizeLabel(usage.bytes)}。已缓存 ${number.format(usage.imageCount)} 张，显示中 ${number.format(usage.liveImageCount)} 张，等待中 ${number.format(usage.pendingImageCount)} 张。',
    ko: '메모리 이미지 캐시: ${_byteSizeLabel(usage.bytes)}. 보관 ${number.format(usage.imageCount)}개, 표시 중 ${number.format(usage.liveImageCount)}개, 대기 중 ${number.format(usage.pendingImageCount)}개.',
  );
}

String _byteSizeLabel(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unitIndex]}';
}

class _DataManagementSheetScaffold extends StatelessWidget {
  const _DataManagementSheetScaffold({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _DataManagementChoiceTile extends StatelessWidget {
  const _DataManagementChoiceTile({
    required this.value,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValue = enabled && value;
    final borderColor = effectiveValue
        ? theme.colorScheme.primary.withValues(alpha: 0.62)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.38);
    final foregroundColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.68);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: effectiveValue ? 0.34 : 0.18,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Checkbox(
                  value: effectiveValue,
                  onChanged: enabled
                      ? (value) => onChanged(value ?? false)
                      : null,
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.56,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enabled
                            ? subtitle
                            : _t(
                                context,
                                'Nothing is currently stored for this item.',
                                '現在、この項目に削除できるデータはありません。',
                                zh: '当前此项目没有可删除的数据。',
                                ko: '현재 이 항목에 삭제할 데이터가 없습니다.',
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
          ),
        ),
      ),
    );
  }
}

class _DataManagementConsentTile extends StatelessWidget {
  const _DataManagementConsentTile({
    required this.value,
    required this.title,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      value: value,
      onChanged: (value) => onChanged(value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _SnapshotDeletionAction {
  keep30(_SnapshotRetentionOption.days30),
  keep90(_SnapshotRetentionOption.days90),
  keep180(_SnapshotRetentionOption.days180),
  deleteAll(null);

  const _SnapshotDeletionAction(this.retention);

  final _SnapshotRetentionOption? retention;
}

class _SnapshotDeletionActionTile extends StatelessWidget {
  const _SnapshotDeletionActionTile({
    required this.action,
    required this.estimate,
    required this.selected,
    required this.onSelected,
  });

  final _SnapshotDeletionAction action;
  final _SnapshotDeletionEstimate estimate;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.62)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.38);
    final title = _snapshotDeletionActionTitle(context, action);
    final subtitle = _snapshotDeletionActionSubtitle(context, action, estimate);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: title,
      hint: subtitle,
      onTap: onSelected,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onSelected,
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: selected ? 0.34 : 0.18,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    action == _SnapshotDeletionAction.deleteAll
                        ? Icons.history_toggle_off_outlined
                        : Icons.auto_delete_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
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
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _snapshotDeletionActionTitle(
  BuildContext context,
  _SnapshotDeletionAction action,
) {
  if (action == _SnapshotDeletionAction.deleteAll) {
    return _t(context, 'Delete all records', 'すべての記録を削除');
  }
  return _snapshotRetentionLabel(context, action.retention!);
}

class _SnapshotDeletionEstimate {
  const _SnapshotDeletionEstimate({
    required this.deleteCount,
    required this.keepCount,
    required this.deletedBytes,
    required this.remainingBytes,
  });

  final int deleteCount;
  final int keepCount;
  final int deletedBytes;
  final int remainingBytes;
}

class _SnapshotStorageEstimate {
  const _SnapshotStorageEstimate({
    required this.totalBytes,
    required this.byAction,
  });

  final int totalBytes;
  final Map<_SnapshotDeletionAction, _SnapshotDeletionEstimate> byAction;
}

_SnapshotStorageEstimate _snapshotStorageEstimate(SnapshotHistory history) {
  final totalBytes = _snapshotHistoryStorageBytes(history);
  final byAction = <_SnapshotDeletionAction, _SnapshotDeletionEstimate>{};

  for (final action in _SnapshotDeletionAction.values) {
    if (action == _SnapshotDeletionAction.deleteAll) {
      byAction[action] = _SnapshotDeletionEstimate(
        deleteCount: history.snapshotCount,
        keepCount: 0,
        deletedBytes: totalBytes,
        remainingBytes: 0,
      );
      continue;
    }

    final cutoff = _snapshotRetentionCutoff(action.retention!);
    final keptSnapshots = history.snapshots
        .where((snapshot) => !snapshot.capturedAt.isBefore(cutoff))
        .toList(growable: false);
    final remainingBytes = _snapshotHistoryStorageBytes(
      SnapshotHistory(snapshots: List.unmodifiable(keptSnapshots)),
    );
    byAction[action] = _SnapshotDeletionEstimate(
      deleteCount: history.snapshotCount - keptSnapshots.length,
      keepCount: keptSnapshots.length,
      deletedBytes: math.max(0, totalBytes - remainingBytes),
      remainingBytes: remainingBytes,
    );
  }

  return _SnapshotStorageEstimate(totalBytes: totalBytes, byAction: byAction);
}

int _snapshotHistoryStorageBytes(SnapshotHistory history) {
  if (history.snapshotCount == 0) {
    return 0;
  }
  return utf8.encode(jsonEncode(history.toJson())).length;
}

class _SnapshotStorageSummary extends StatelessWidget {
  const _SnapshotStorageSummary({
    required this.history,
    required this.estimate,
  });

  final SnapshotHistory history;
  final _SnapshotStorageEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.storage_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t(
                  context,
                  'Stored records: ${_dayCountLabel(context, history.snapshotCount)}, about ${_byteSizeLabel(estimate.totalBytes)}.',
                  '保存済みの聴取記録: ${_dayCountLabel(context, history.snapshotCount)}、約${_byteSizeLabel(estimate.totalBytes)}。',
                  zh: '已保存记录：${_dayCountLabel(context, history.snapshotCount)}，约 ${_byteSizeLabel(estimate.totalBytes)}。',
                  ko: '저장된 청취 기록: ${_dayCountLabel(context, history.snapshotCount)}, 약 ${_byteSizeLabel(estimate.totalBytes)}.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _snapshotDeletionActionSubtitle(
  BuildContext context,
  _SnapshotDeletionAction action,
  _SnapshotDeletionEstimate estimate,
) {
  final number = _numberFormat(context);
  if (action == _SnapshotDeletionAction.deleteAll) {
    return _t(
      context,
      'Delete ${number.format(estimate.deleteCount)} saved records, about ${_byteSizeLabel(estimate.deletedBytes)}.',
      '${number.format(estimate.deleteCount)}件の保存済み記録（約${_byteSizeLabel(estimate.deletedBytes)}）を削除します。',
      zh: '删除 ${number.format(estimate.deleteCount)} 条已保存记录，约 ${_byteSizeLabel(estimate.deletedBytes)}。',
      ko: '저장된 기록 ${number.format(estimate.deleteCount)}개, 약 ${_byteSizeLabel(estimate.deletedBytes)}를 삭제합니다.',
    );
  }

  final cutoff = _snapshotRetentionCutoff(action.retention!);
  final cutoffLabel = DateFormat.yMMMd(_localeName(context)).format(cutoff);
  return _t(
    context,
    'Delete ${number.format(estimate.deleteCount)} records before $cutoffLabel, about ${_byteSizeLabel(estimate.deletedBytes)}. Keep ${number.format(estimate.keepCount)}, about ${_byteSizeLabel(estimate.remainingBytes)}.',
    '$cutoffLabel より前の ${number.format(estimate.deleteCount)}件（約${_byteSizeLabel(estimate.deletedBytes)}）を削除し、${number.format(estimate.keepCount)}件（約${_byteSizeLabel(estimate.remainingBytes)}）を保持します。',
    zh: '删除 $cutoffLabel 之前的 ${number.format(estimate.deleteCount)} 条，约 ${_byteSizeLabel(estimate.deletedBytes)}。保留 ${number.format(estimate.keepCount)} 条，约 ${_byteSizeLabel(estimate.remainingBytes)}。',
    ko: '$cutoffLabel 이전 기록 ${number.format(estimate.deleteCount)}개, 약 ${_byteSizeLabel(estimate.deletedBytes)}를 삭제하고 ${number.format(estimate.keepCount)}개, 약 ${_byteSizeLabel(estimate.remainingBytes)}를 유지합니다.',
  );
}

DateTime _snapshotRetentionCutoff(_SnapshotRetentionOption retention) {
  final now = _localDateOnly(DateTime.now());
  return now.subtract(Duration(days: retention.days));
}

Future<void> _showCacheManagementSheet(
  BuildContext context,
  WidgetRef ref, {
  required _CacheUsage cacheUsage,
}) async {
  var clearImageCache = cacheUsage.hasImages;
  var agreed = false;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return StatefulBuilder(
        builder: (context, setState) {
          final canDelete = clearImageCache && agreed;
          return _DataManagementSheetScaffold(
            title: _t(context, 'Temporary caches', '一時キャッシュ'),
            icon: Icons.cleaning_services_outlined,
            children: [
              Text(
                _t(
                  context,
                  'Choose the temporary data to clear. Listening records and settings are kept.',
                  '削除する一時データを選びます。聴取記録と設定は保持します。',
                  zh: '选择要清除的临时数据。收听记录和设置会保留。',
                  ko: '삭제할 임시 데이터를 선택합니다. 청취 기록과 설정은 유지됩니다.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _DataManagementChoiceTile(
                value: clearImageCache,
                enabled: cacheUsage.hasImages,
                icon: Icons.image_outlined,
                title: _t(
                  context,
                  'Artwork image cache',
                  'アートワーク画像キャッシュ',
                  zh: '封面图片缓存',
                  ko: '아트워크 이미지 캐시',
                ),
                subtitle: _cacheUsageDetailLabel(context, cacheUsage),
                onChanged: (value) {
                  setState(() {
                    clearImageCache = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              _DataManagementConsentTile(
                value: agreed,
                title: _t(
                  context,
                  'I understand the selected temporary caches will be cleared.',
                  '選択した一時キャッシュが削除されることに同意します。',
                  zh: '我了解所选临时缓存将被清除。',
                  ko: '선택한 임시 캐시가 삭제되는 것에 동의합니다.',
                ),
                onChanged: (value) {
                  setState(() {
                    agreed = value;
                  });
                },
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(_t(context, 'Cancel', 'キャンセル')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: canDelete
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: Text(_t(context, 'Clear caches', 'キャッシュを削除')),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  _clearTemporaryCaches(context, ref);
}

Future<void> _showListeningRecordManagementSheet(
  BuildContext context,
  WidgetRef ref,
  MusicStatsState stats,
) async {
  var selectedAction = _SnapshotDeletionAction.keep90;
  var agreed = false;
  final storageEstimate = _snapshotStorageEstimate(stats.snapshotHistory);
  final request = await showModalBottomSheet<_SnapshotDeletionAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return StatefulBuilder(
        builder: (context, setState) {
          return _DataManagementSheetScaffold(
            title: _t(context, 'Listening records', '聴取記録'),
            icon: Icons.calendar_month_outlined,
            children: [
              Text(
                _t(
                  context,
                  'Choose how much listening history to keep. App settings and purchase status are kept.',
                  '残す聴取記録の期間を選びます。設定と購入状態は保持します。',
                  zh: '选择要保留的收听记录范围。应用设置和购买状态会保留。',
                  ko: '보관할 청취 기록 기간을 선택합니다. 앱 설정과 구매 상태는 유지됩니다.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _SnapshotStorageSummary(
                history: stats.snapshotHistory,
                estimate: storageEstimate,
              ),
              const SizedBox(height: 14),
              for (final action in _SnapshotDeletionAction.values) ...[
                _SnapshotDeletionActionTile(
                  action: action,
                  estimate: storageEstimate.byAction[action]!,
                  selected: selectedAction == action,
                  onSelected: () {
                    setState(() {
                      selectedAction = action;
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
              _DataManagementConsentTile(
                value: agreed,
                title: _t(
                  context,
                  'I understand the selected listening records will be deleted.',
                  '選択した聴取記録が削除されることに同意します。',
                  zh: '我了解所选收听记录将被删除。',
                  ko: '선택한 청취 기록이 삭제되는 것에 동의합니다.',
                ),
                onChanged: (value) {
                  setState(() {
                    agreed = value;
                  });
                },
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_t(context, 'Cancel', 'キャンセル')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: agreed
                        ? () => Navigator.of(context).pop(selectedAction)
                        : null,
                    icon: const Icon(Icons.history_toggle_off_outlined),
                    label: Text(_t(context, 'Delete records', '記録を削除')),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
  if (request == null || !context.mounted) {
    return;
  }
  if (request == _SnapshotDeletionAction.deleteAll) {
    await _clearSnapshotHistory(context, ref, stats);
    return;
  }
  await _deleteOldSnapshots(context, ref, stats, request.retention!);
}

void _clearTemporaryCaches(
  BuildContext context,
  WidgetRef ref, {
  bool showMessage = true,
}) {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  ref.invalidate(trackArtworkProvider);
  ref.read(_cacheUsageRevisionProvider.notifier).refresh();
  if (showMessage) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          _t(context, 'Temporary caches were cleared.', '一時キャッシュを削除しました。'),
        ),
      ),
    );
  }
}

Future<void> _deleteOldSnapshots(
  BuildContext context,
  WidgetRef ref,
  MusicStatsState stats,
  _SnapshotRetentionOption retention,
) async {
  final cutoff = _snapshotRetentionCutoff(retention);

  try {
    final before = stats.snapshotHistory.snapshotCount;
    final history = await ref
        .read(musicStatsControllerProvider.notifier)
        .deleteSnapshotsOlderThan(cutoff);
    if (!context.mounted) {
      return;
    }
    final removed = before - (history?.snapshotCount ?? before);
    _showDataManagementResult(
      context,
      removed <= 0
          ? _t(
              context,
              'No matching listening records were deleted.',
              '削除対象の聴取記録はありません。',
            )
          : _t(
              context,
              'Deleted $removed listening records.',
              '$removed件の聴取記録を削除しました。',
              zh: '已删除 $removed 条收听记录。',
              ko: '청취 기록 $removed개를 삭제했습니다.',
            ),
    );
  } on Object {
    if (context.mounted) {
      _showDataManagementResult(
        context,
        _t(context, 'Could not delete listening records.', '聴取記録を削除できませんでした。'),
      );
    }
  }
}

Future<void> _clearSnapshotHistory(
  BuildContext context,
  WidgetRef ref,
  MusicStatsState stats,
) async {
  try {
    final before = stats.snapshotHistory.snapshotCount;
    await ref
        .read(musicStatsControllerProvider.notifier)
        .clearSnapshotHistory();
    if (!context.mounted) {
      return;
    }
    _showDataManagementResult(
      context,
      _t(
        context,
        'Deleted $before listening records.',
        '$before件の聴取記録を削除しました。',
        zh: '已删除 $before 条收听记录。',
        ko: '청취 기록 $before개를 삭제했습니다.',
      ),
    );
  } on Object {
    if (context.mounted) {
      _showDataManagementResult(
        context,
        _t(context, 'Could not delete listening records.', '聴取記録を削除できませんでした。'),
      );
    }
  }
}

void _showDataManagementResult(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

class _AppLockSetting extends ConsumerWidget {
  const _AppLockSetting({required this.lockState});

  final AsyncValue<AppLockState> lockState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return lockState.when(
      loading: () => _SettingsRow(
        icon: Icons.lock_outline,
        label: _t(context, 'App Lock', 'アプリロック'),
        value: _t(context, 'Checking...', '確認中...'),
      ),
      error: (_, _) => _SettingsRow(
        icon: Icons.lock_outline,
        label: _t(context, 'App Lock', 'アプリロック'),
        value: _t(context, 'Unavailable', '利用不可'),
      ),
      data: (state) {
        final enabled = state.enabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                _t(context, 'App Lock', 'アプリロック'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                state.supported
                    ? _t(
                        context,
                        'Require device authentication when opening SongBrief.',
                        'SongBriefを開くときに端末認証を要求します。',
                      )
                    : _t(
                        context,
                        'Available on devices with Face ID, Touch ID, or passcode authentication.',
                        'Face ID、Touch ID、またはパスコード認証に対応した端末で利用できます。',
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: enabled,
              onChanged: !state.supported || state.authenticating
                  ? null
                  : (value) {
                      ref
                          .read(appLockControllerProvider.notifier)
                          .setEnabled(
                            value,
                            localizedReason: _t(
                              context,
                              'Enable SongBrief app lock.',
                              'SongBriefのアプリロックを有効にします。',
                            ),
                          );
                    },
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                state.errorMessage == 'device_authentication_unavailable'
                    ? _t(
                        context,
                        'Device authentication is not available.',
                        '端末認証を利用できません。',
                      )
                    : _t(
                        context,
                        'Authentication was not completed.',
                        '認証が完了しませんでした。',
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (enabled) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: state.authenticating
                      ? null
                      : () {
                          ref.read(appLockControllerProvider.notifier).lock();
                        },
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(_t(context, 'Lock now', '今すぐロック')),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CrashReportingSetting extends ConsumerWidget {
  const _CrashReportingSetting({required this.state});

  final CrashReportingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = state.enabled;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        Icons.bug_report_outlined,
        color: state.available
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        _t(context, 'Crash reports', 'クラッシュレポート', zh: '崩溃报告', ko: '크래시 리포트'),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        _crashReportingDescription(context, state),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: enabled,
      onChanged: state.canToggle
          ? (value) {
              ref
                  .read(crashReportingControllerProvider.notifier)
                  .setEnabled(value);
            }
          : null,
    );
  }
}

String _crashReportingDescription(
  BuildContext context,
  CrashReportingState state,
) {
  if (!state.available) {
    return switch (state.unavailableReason) {
      CrashReportingUnavailableReason.unsupportedPlatform => _t(
        context,
        'Crash reports are available in the iOS app, not in this preview.',
        'クラッシュレポートはiOSアプリで利用できます。このプレビューでは利用できません。',
        zh: '崩溃报告可在 iOS 应用中使用，当前预览不可用。',
        ko: '크래시 리포트는 iOS 앱에서 사용할 수 있으며 이 미리보기에서는 사용할 수 없습니다.',
      ),
      CrashReportingUnavailableReason.initializationFailed => _t(
        context,
        'Crash reports could not be started. Check Firebase configuration.',
        'クラッシュレポートを開始できませんでした。Firebase設定を確認してください。',
        zh: '无法启动崩溃报告。请检查 Firebase 设置。',
        ko: '크래시 리포트를 시작할 수 없습니다. Firebase 설정을 확인하세요.',
      ),
      _ => _t(
        context,
        'Crash reports are disabled in this build.',
        'このビルドではクラッシュレポートを無効化しています。',
        zh: '此构建已禁用崩溃报告。',
        ko: '이 빌드에서는 크래시 리포트가 비활성화되어 있습니다.',
      ),
    };
  }
  if (state.updating) {
    return _t(
      context,
      'Updating crash report settings...',
      'クラッシュレポート設定を更新しています...',
      zh: '正在更新崩溃报告设置...',
      ko: '크래시 리포트 설정을 업데이트하는 중...',
    );
  }
  if (state.enabled) {
    return _t(
      context,
      'Sends stack traces, device/OS information, and app version to Firebase after crashes. Music library details are not sent.',
      'クラッシュ後にスタックトレース、端末/OS情報、アプリバージョンをFirebaseへ送信します。曲名などは送信しません。',
      zh: '崩溃后会向 Firebase 发送堆栈跟踪、设备/系统信息和应用版本。不会发送音乐库详情。',
      ko: '크래시 후 스택 트레이스, 기기/OS 정보, 앱 버전을 Firebase로 보냅니다. 음악 라이브러리 상세 정보는 보내지 않습니다.',
    );
  }
  return _t(
    context,
    'When enabled, SongBrief can receive crash diagnostics. Track names, lyrics, playlists, and listening history are not included.',
    '有効にすると、SongBriefがクラッシュ診断を受け取れます。曲名、歌詞、プレイリスト、聴取履歴は含めません。',
    zh: '启用后，SongBrief 可以接收崩溃诊断。不会包含曲名、歌词、播放列表或收听历史。',
    ko: '활성화하면 SongBrief가 크래시 진단을 받을 수 있습니다. 곡명, 가사, 플레이리스트, 청취 기록은 포함하지 않습니다.',
  );
}

class _AdPrivacySetting extends ConsumerWidget {
  const _AdPrivacySetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(adConsentControllerProvider);
    return consent.when(
      data: (state) {
        if (!state.privacyOptionsRequired) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsRow(
                icon: Icons.ads_click_outlined,
                label: _t(
                  context,
                  'Ad privacy choices',
                  '広告プライバシー設定',
                  zh: '广告隐私设置',
                  ko: '광고 개인정보 설정',
                ),
                value: state.updating
                    ? _t(
                        context,
                        'Opening...',
                        '表示中...',
                        zh: '正在打开...',
                        ko: '여는 중...',
                      )
                    : _t(context, 'Manage', '管理'),
                onTap: state.updating
                    ? null
                    : () => _showAdPrivacyOptions(context, ref),
              ),
              const SizedBox(height: 4),
              Text(
                _t(
                  context,
                  'Change consent choices for ads when required in your region.',
                  'お住まいの地域で必要な場合、広告に関する同意内容を変更できます。',
                  zh: '如果你所在地区需要，可以更改广告相关的同意选择。',
                  ko: '거주 지역에서 필요한 경우 광고 동의 선택을 변경할 수 있습니다.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

Future<void> _showAdPrivacyOptions(BuildContext context, WidgetRef ref) async {
  final result = await ref
      .read(adConsentControllerProvider.notifier)
      .showPrivacyOptions();
  if (!context.mounted || result.errorMessage == null) {
    return;
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        _t(
          context,
          'Could not open ad privacy settings.',
          '広告プライバシー設定を開けませんでした。',
          zh: '无法打开广告隐私设置。',
          ko: '광고 개인정보 설정을 열 수 없습니다.',
        ),
      ),
    ),
  );
}

Future<void> _saveLibraryExport(
  BuildContext context,
  MusicStatsState stats,
  LibraryExportFormat format,
) async {
  final payload = buildLibraryExportPayload(stats, format);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final extension = _libraryExportExtension(format);
  final fileName = payload.fileName;
  final baseName = fileName.endsWith('.$extension')
      ? fileName.substring(0, fileName.length - extension.length - 1)
      : fileName;

  try {
    final savedPath = await FileSaver.instance.saveAs(
      name: baseName,
      bytes: Uint8List.fromList(utf8.encode(payload.content)),
      fileExtension: extension,
      mimeType: _libraryExportMimeType(format),
    );

    if (!context.mounted) {
      return;
    }

    if (savedPath == null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _t(context, 'Export was cancelled.', 'エクスポートをキャンセルしました。'),
          ),
        ),
      );
      return;
    }
  } on Exception {
    if (!context.mounted) {
      return;
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          _t(
            context,
            'Could not save the export file.',
            'エクスポートファイルを保存できませんでした。',
          ),
        ),
      ),
    );
    return;
  }

  if (!context.mounted) {
    return;
  }
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        _t(
          context,
          'Saved ${payload.fileName}.',
          '${payload.fileName} を保存しました。',
          zh: '已保存 ${payload.fileName}。',
          ko: '${payload.fileName} 저장됨.',
        ),
      ),
    ),
  );
}

String _libraryExportExtension(LibraryExportFormat format) => switch (format) {
  LibraryExportFormat.csv => 'csv',
  LibraryExportFormat.json => 'json',
};

MimeType _libraryExportMimeType(LibraryExportFormat format) => switch (format) {
  LibraryExportFormat.csv => MimeType.csv,
  LibraryExportFormat.json => MimeType.json,
};

Future<void> _openAppleMusicTrack(
  BuildContext context,
  LibraryTrack track,
) async {
  await _openExternalUrl(context, appleMusicUrlForTrack(track).toString());
}

Future<void> _openWebSearch(
  BuildContext context,
  String query,
  String subject,
) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_t(context, 'Open web search?', 'Web検索を開きますか？')),
      content: Text(
        _t(
          context,
          'SongBrief will open an external browser and search for "$trimmedQuery" about "$subject". The search terms may include song, artist, or album names and will be sent to the search service.',
          '外部ブラウザで「$subject」について「$trimmedQuery」を検索します。検索語句には曲名、アーティスト名、アルバム名などが含まれ、検索サービスへ送信されます。',
          zh: 'SongBrief 将在外部浏览器中搜索与“$subject”相关的“$trimmedQuery”。搜索词可能包含歌曲、艺人或专辑名称，并会发送到搜索服务。',
          ko: 'SongBrief가 외부 브라우저에서 "$subject"에 대해 "$trimmedQuery"를 검색합니다. 검색어에는 곡명, 아티스트명, 앨범명이 포함될 수 있으며 검색 서비스로 전송됩니다.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_t(context, 'Cancel', 'キャンセル')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(_t(context, 'Open', '開く')),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  await _openExternalUrl(context, _webSearchUri(trimmedQuery).toString());
}

Future<void> _openExternalUrl(
  BuildContext context,
  String url, {
  bool requireConfirmation = false,
}) async {
  if (requireConfirmation) {
    final confirmed = await _confirmExternalNavigation(context, url);
    if (confirmed != true || !context.mounted) {
      return;
    }
  }

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

  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        _t(
          context,
          'Could not open $url',
          '$url を開けませんでした',
          zh: '无法打开 $url',
          ko: '$url을 열 수 없습니다',
        ),
      ),
    ),
  );
}

Future<bool> _confirmExternalNavigation(
  BuildContext context,
  String url,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        _t(
          context,
          'Open external site?',
          '外部サイトを開きますか？',
          zh: '打开外部网站？',
          ko: '외부 사이트를 열까요?',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              context,
              'SongBrief will open the following link in an external browser.',
              'SongBriefから外部ブラウザで次のリンクを開きます。',
              zh: 'SongBrief 将在外部浏览器中打开以下链接。',
              ko: 'SongBrief에서 외부 브라우저로 다음 링크를 엽니다.',
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            url,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_t(context, 'Cancel', 'キャンセル')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(_t(context, 'Open', '開く')),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
