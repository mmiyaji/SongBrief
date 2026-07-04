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
              'Period, rising, and rank-change rankings appear after two saved daily snapshots.',
              '期間別・急上昇・順位変動ランキングは、日次スナップショットが2件以上保存されると表示されます。',
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
        'Tracks ranked by play-count increases within the selected snapshot range.',
        '選択した期間のスナップショット差分で増えた再生数順です。',
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
        'Biggest increases since the previous saved snapshot.',
        '前回の保存スナップショットから伸びた曲です。',
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
            _t(context, 'since previous snapshot', '前回比'),
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
        'Largest ranking movements compared with the previous snapshot.',
        '前回スナップショットの順位から大きく動いた曲です。',
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
    final premium = ref.watch(premiumControllerProvider);
    final libraryFilters = ref.watch(libraryFilterPreferencesProvider);
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
                    : _authorizationLabel(context, stats.authorizationStatus),
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
                value: stats.snapshotRecordingEnabled
                    ? _dateTimeFormat(context).format(overview.generatedAt)
                    : _t(context, 'Off', 'オフ'),
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
                          label: Text(_themeStyleLabel(context, style)),
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
                _themeStyleDescription(context, selectedTheme),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<SongBriefThemeBrightness>(
                  showSelectedIcon: false,
                  segments: SongBriefThemeBrightness.values
                      .map(
                        (brightness) => ButtonSegment<SongBriefThemeBrightness>(
                          value: brightness,
                          label: Text(
                            _themeBrightnessLabel(context, brightness),
                          ),
                        ),
                      )
                      .toList(),
                  selected: {selectedBrightness},
                  onSelectionChanged: (selection) {
                    ref
                        .read(themeBrightnessProvider.notifier)
                        .setBrightness(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _themeBrightnessDescription(context, selectedBrightness),
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
                          label: Text(_languageLabel(context, language)),
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
                _t(context, 'Security', 'セキュリティ'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _AppLockSetting(lockState: appLock),
              const SizedBox(height: 18),
              Text(
                _t(context, 'Export', 'エクスポート'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _ExportSetting(stats: stats),
              const SizedBox(height: 18),
              Text(
                _t(context, 'Display & Exclusions', '表示と除外'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _LibraryFilterSetting(stats: stats, filters: libraryFilters),
              const SizedBox(height: 18),
              Text(
                _t(context, 'Data Management', 'データ管理'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _DataManagementSetting(stats: stats),
              const SizedBox(height: 18),
              Text(
                _t(context, 'Premium', 'プレミアム'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _PremiumSetting(premiumState: premium),
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
              AdBannerSlot(placement: _t(context, 'Settings', '設定')),
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
          label: _t(context, 'Snapshots', 'スナップショット'),
          value: _dayCountLabel(context, stats.snapshotHistory.snapshotCount),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            context,
            'CSV is suited for spreadsheets. JSON includes snapshot summaries for backup or analysis.',
            'CSVは表計算向け、JSONはスナップショット概要も含む分析・バックアップ向けです。',
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
    final controller = ref.read(libraryFilterPreferencesProvider.notifier);
    final overview = stats.overview;

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
            'Matching songs are hidden from SongBrief rankings, library, exports, and future snapshots. Your Apple Music library is not changed.',
            '一致する曲をSongBriefのランキング、ライブラリ、エクスポート、今後のスナップショットから除外します。Apple Musicの内容は変更しません。',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _RuleGroup(
          icon: Icons.playlist_remove_rounded,
          title: _t(context, 'Hidden playlists', '非表示プレイリスト'),
          description: _t(
            context,
            'Hide songs that belong to selected playlists.',
            '選択したプレイリストに含まれる曲を非表示にします。',
          ),
          rules: filters.excludedPlaylists,
          suggestions: _playlistSuggestions(overview, filters),
          emptyLabel: _t(context, 'No hidden playlists', '非表示プレイリストはありません'),
          addLabel: _t(context, 'Add playlist', 'プレイリストを追加'),
          onAdd: () => _addPlaylistExclusion(context, ref),
          onAddSuggestion: controller.addExcludedPlaylist,
          onRemove: controller.removeExcludedPlaylist,
        ),
        const SizedBox(height: 10),
        _RuleGroup(
          icon: Icons.category_outlined,
          title: _t(context, 'Hidden genres', '非表示ジャンル'),
          description: _t(
            context,
            'Hide songs with selected genre names.',
            '選択したジャンル名の曲を非表示にします。',
          ),
          rules: filters.excludedGenres,
          suggestions: _genreSuggestions(overview, filters),
          emptyLabel: _t(context, 'No hidden genres', '非表示ジャンルはありません'),
          addLabel: _t(context, 'Add genre', 'ジャンルを追加'),
          onAdd: () => _addGenreExclusion(context, ref),
          onAddSuggestion: controller.addExcludedGenre,
          onRemove: controller.removeExcludedGenre,
        ),
        const SizedBox(height: 10),
        _RuleGroup(
          icon: Icons.manage_search_rounded,
          title: _t(context, 'Hidden keywords', '非表示キーワード'),
          description: _t(
            context,
            'Hide songs whose title, artist, album, genre, or playlist contains a keyword.',
            '曲名、アーティスト、アルバム、ジャンル、プレイリストにキーワードを含む曲を非表示にします。',
          ),
          rules: filters.excludedKeywords,
          suggestions: const <String>[],
          emptyLabel: _t(context, 'No hidden keywords', '非表示キーワードはありません'),
          addLabel: _t(context, 'Add keyword', 'キーワードを追加'),
          onAdd: () => _addKeywordExclusion(context, ref),
          onAddSuggestion: controller.addExcludedKeyword,
          onRemove: controller.removeExcludedKeyword,
        ),
        if (!filters.isEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: controller.clearAll,
              icon: const Icon(Icons.clear_all_rounded),
              label: Text(_t(context, 'Clear exclusions', '除外をすべて解除')),
            ),
          ),
        ],
      ],
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
  return _t(context, '$count rules', '$count件');
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
    final theme = Theme.of(context);
    ref.watch(_cacheUsageRevisionProvider);
    final cacheUsage = _currentCacheUsage();
    final snapshotRecordingEnabled = ref.watch(snapshotRecordingProvider);
    final history = stats.snapshotHistory;
    final oldestSnapshot = history.snapshots.isEmpty
        ? null
        : history.snapshots.first;
    final latestSnapshot = history.latest;
    final rangeLabel = oldestSnapshot == null || latestSnapshot == null
        ? _t(context, 'No history', '履歴なし')
        : '${DateFormat.Md(_localeName(context)).format(oldestSnapshot.capturedAt)} - '
              '${DateFormat.Md(_localeName(context)).format(latestSnapshot.capturedAt)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SnapshotRecordingSetting(enabled: snapshotRecordingEnabled),
        const SizedBox(height: 10),
        _SettingsRow(
          icon: Icons.cleaning_services_outlined,
          label: _t(context, 'Temporary caches', '一時キャッシュ'),
          value: _cacheUsageLabel(context, cacheUsage),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _confirmAndClearTemporaryCaches(
              context,
              ref,
              cacheUsage: cacheUsage,
            ),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(_t(context, 'Clear caches', 'キャッシュを削除')),
          ),
        ),
        const SizedBox(height: 10),
        _SettingsRow(
          icon: Icons.calendar_month_outlined,
          label: _t(context, 'Snapshot history', 'スナップショット履歴'),
          value:
              '${_dayCountLabel(context, history.snapshotCount)} / $rangeLabel',
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            context,
            'Snapshot deletion requires confirmation. App settings and purchase status are kept.',
            '履歴の削除には確認が必要です。設定と購入状態は保持します。',
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
            for (final retention in _SnapshotRetentionOption.values)
              OutlinedButton.icon(
                onPressed: history.snapshotCount == 0
                    ? null
                    : () => _deleteOldSnapshots(context, ref, stats, retention),
                icon: const Icon(Icons.auto_delete_outlined),
                label: Text(_snapshotRetentionLabel(context, retention)),
              ),
            OutlinedButton.icon(
              onPressed: history.snapshotCount == 0
                  ? null
                  : () => _clearSnapshotHistory(context, ref, stats),
              icon: const Icon(Icons.history_toggle_off_outlined),
              label: Text(_t(context, 'Delete history', '履歴を削除')),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _cleanGeneratedData(context, ref, stats),
              icon: const Icon(Icons.cleaning_services_rounded),
              label: Text(_t(context, 'Clean generated data', '生成データを全削除')),
            ),
          ],
        ),
      ],
    );
  }
}

class _SnapshotRecordingSetting extends ConsumerWidget {
  const _SnapshotRecordingSetting({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.auto_graph_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(context, 'Save daily snapshots', '日次スナップショットを保存'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enabled
                        ? _t(
                            context,
                            'Snapshot-based trends and recaps are visible.',
                            '履歴ベースの傾向・リキャップを表示します。',
                          )
                        : _t(
                            context,
                            'Snapshot-based trends and recaps are hidden.',
                            '履歴ベースの傾向・リキャップは非表示です。',
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (value) {
                ref.read(snapshotRecordingProvider.notifier).setEnabled(value);
              },
            ),
          ],
        ),
      ),
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
  );
}

String _cacheUsageDetailLabel(BuildContext context, _CacheUsage usage) {
  final number = _numberFormat(context);
  return _t(
    context,
    'Memory image cache: ${_byteSizeLabel(usage.bytes)}. Cached ${number.format(usage.imageCount)}, live ${number.format(usage.liveImageCount)}, pending ${number.format(usage.pendingImageCount)}.',
    'メモリ画像キャッシュ: ${_byteSizeLabel(usage.bytes)}。保持 ${number.format(usage.imageCount)}件、表示中 ${number.format(usage.liveImageCount)}件、読込中 ${number.format(usage.pendingImageCount)}件。',
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

Future<void> _confirmAndClearTemporaryCaches(
  BuildContext context,
  WidgetRef ref, {
  required _CacheUsage cacheUsage,
}) async {
  final confirmed = await _confirmDataDeletion(
    context,
    title: _t(context, 'Clear temporary caches?', '一時キャッシュを削除しますか？'),
    message: _t(
      context,
      '${_cacheUsageDetailLabel(context, cacheUsage)} This does not delete snapshot history or settings.',
      '${_cacheUsageDetailLabel(context, cacheUsage)} スナップショット履歴や設定は削除しません。',
    ),
    consentLabel: _t(
      context,
      'I understand this clears temporary caches.',
      '一時キャッシュが削除されることに同意します。',
    ),
    confirmLabel: _t(context, 'Clear caches', 'キャッシュを削除'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  _clearTemporaryCaches(context, ref);
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
  final now = _localDateOnly(DateTime.now());
  final cutoff = now.subtract(Duration(days: retention.days));
  final cutoffLabel = DateFormat.yMMMd(_localeName(context)).format(cutoff);
  final confirmed = await _confirmSnapshotDeletion(
    context,
    title: _t(context, 'Delete old snapshots?', '古いスナップショットを削除しますか？'),
    message: _t(
      context,
      'Snapshots before $cutoffLabel will be deleted. This cannot be undone.',
      '$cutoffLabel より前のスナップショットを削除します。この操作は元に戻せません。',
    ),
    confirmLabel: _t(context, 'Delete old snapshots', '古い履歴を削除'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }

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
          ? _t(context, 'No matching snapshots were deleted.', '削除対象の履歴はありません。')
          : _t(
              context,
              'Deleted $removed snapshots.',
              '$removed件のスナップショットを削除しました。',
            ),
    );
  } on Object {
    if (context.mounted) {
      _showDataManagementResult(
        context,
        _t(context, 'Could not delete snapshots.', 'スナップショットを削除できませんでした。'),
      );
    }
  }
}

Future<void> _clearSnapshotHistory(
  BuildContext context,
  WidgetRef ref,
  MusicStatsState stats,
) async {
  final confirmed = await _confirmSnapshotDeletion(
    context,
    title: _t(context, 'Delete all snapshot history?', '履歴をすべて削除しますか？'),
    message: _t(
      context,
      'All saved snapshots will be deleted. This cannot be undone.',
      '保存済みスナップショットをすべて削除します。この操作は元に戻せません。',
    ),
    confirmLabel: _t(context, 'Delete all history', 'すべての履歴を削除'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }

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
      _t(context, 'Deleted $before snapshots.', '$before件のスナップショットを削除しました。'),
    );
  } on Object {
    if (context.mounted) {
      _showDataManagementResult(
        context,
        _t(context, 'Could not delete snapshots.', 'スナップショットを削除できませんでした。'),
      );
    }
  }
}

Future<void> _cleanGeneratedData(
  BuildContext context,
  WidgetRef ref,
  MusicStatsState stats,
) async {
  final confirmed = await _confirmSnapshotDeletion(
    context,
    title: _t(context, 'Clean generated data?', '生成データを全削除しますか？'),
    message: _t(
      context,
      'Artwork caches and all snapshot history will be cleared. App settings and purchase status are kept.',
      'アートワークキャッシュとすべてのスナップショット履歴を削除します。設定と購入状態は保持します。',
    ),
    confirmLabel: _t(context, 'Clean data', '削除する'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final before = stats.snapshotHistory.snapshotCount;
    _clearTemporaryCaches(context, ref, showMessage: false);
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
        'Caches cleared and $before snapshots deleted.',
        'キャッシュを削除し、$before件のスナップショットを削除しました。',
      ),
    );
  } on Object {
    if (context.mounted) {
      _showDataManagementResult(
        context,
        _t(context, 'Could not clean generated data.', '生成データを削除できませんでした。'),
      );
    }
  }
}

Future<bool> _confirmSnapshotDeletion(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) {
  return _confirmDataDeletion(
    context,
    title: title,
    message: message,
    consentLabel: _t(
      context,
      'I understand this deletes snapshot history.',
      'スナップショット履歴が削除されることに同意します。',
    ),
    confirmLabel: confirmLabel,
  );
}

Future<bool> _confirmDataDeletion(
  BuildContext context, {
  required String title,
  required String message,
  required String consentLabel,
  required String confirmLabel,
}) async {
  var agreed = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: agreed,
                  onChanged: (value) {
                    setState(() {
                      agreed = value ?? false;
                    });
                  },
                  title: Text(
                    consentLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_t(context, 'Cancel', 'キャンセル')),
              ),
              FilledButton(
                onPressed: agreed
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
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

class _PremiumSetting extends ConsumerWidget {
  const _PremiumSetting({required this.premiumState});

  final AsyncValue<PremiumState> premiumState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return premiumState.when(
      loading: () => _SettingsRow(
        icon: Icons.workspace_premium_outlined,
        label: _t(context, 'Premium', 'プレミアム'),
        value: _t(context, 'Checking...', '確認中...'),
      ),
      error: (_, _) => _SettingsRow(
        icon: Icons.workspace_premium_outlined,
        label: _t(context, 'Premium', 'プレミアム'),
        value: _t(context, 'Unavailable', '利用不可'),
      ),
      data: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsRow(
              icon: Icons.ads_click_outlined,
              label: _t(context, 'Ad mode', '広告モード'),
              value: _adLaunchModeLabel(context, MonetizationConfig.adMode),
            ),
            _SettingsRow(
              icon: state.entitled
                  ? Icons.workspace_premium_rounded
                  : Icons.remove_circle_outline,
              label: _t(context, 'Remove ads', '広告を非表示'),
              value: _premiumStatusLabel(context, state),
            ),
            if (!state.entitled)
              _SettingsRow(
                icon: Icons.shopping_bag_outlined,
                label: _t(context, 'Product ID', '商品ID'),
                value: state.productId,
              ),
            if (!state.entitled && state.productTitle != null)
              _SettingsRow(
                icon: Icons.local_offer_outlined,
                label: _t(context, 'Store product', 'ストア商品'),
                value: state.productTitle!,
              ),
            if (!state.entitled && state.productDescription != null) ...[
              const SizedBox(height: 6),
              Text(
                state.productDescription!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (state.message != null || state.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _premiumMessageLabel(
                  context,
                  state.message ?? state.errorMessage!,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: state.errorMessage == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (!state.entitled) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: state.canPurchase
                        ? () {
                            ref
                                .read(premiumControllerProvider.notifier)
                                .purchaseRemoveAds();
                          }
                        : null,
                    icon: state.busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.workspace_premium_outlined),
                    label: Text(
                      state.price == null
                          ? _t(context, 'Buy premium', 'プレミアムを購入')
                          : _t(
                              context,
                              'Buy premium ${state.price}',
                              'プレミアムを購入 ${state.price}',
                            ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.busy
                        ? null
                        : () {
                            ref
                                .read(premiumControllerProvider.notifier)
                                .reloadProduct();
                          },
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(_t(context, 'Reload product', '商品を再取得')),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.canRestore
                        ? () {
                            ref
                                .read(premiumControllerProvider.notifier)
                                .restorePurchases();
                          }
                        : null,
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(_t(context, 'Restore', '復元')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  context,
                  'Premium purchase is not available yet. Once enabled, you can buy ad removal here.',
                  'プレミアム購入は現在準備中です。利用可能になると、ここから広告非表示を購入できます。',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _adLaunchModeLabel(BuildContext context, AdLaunchMode mode) {
  return switch (mode) {
    AdLaunchMode.off => _t(context, 'Off', 'オフ'),
    AdLaunchMode.admobTest => _t(context, 'AdMob test', 'AdMobテスト'),
    AdLaunchMode.admobLive => _t(context, 'AdMob live', 'AdMob本番'),
  };
}

String _premiumStatusLabel(BuildContext context, PremiumState state) {
  if (state.entitled) {
    return _t(context, 'Ads removed', '広告なし');
  }
  if (!state.storeSupported) {
    return _t(context, 'Store unavailable', 'ストア利用不可');
  }
  if (state.productLoaded) {
    return state.price ?? _t(context, 'Available', '利用可能');
  }
  return _t(context, 'Not configured', '未設定');
}

String _premiumMessageLabel(BuildContext context, String message) {
  return switch (message) {
    'Premium is unlocked by launch mode.' => _t(
      context,
      'Premium is unlocked by launch mode.',
      '起動モードでプレミアムが有効です。',
    ),
    'Configure the premium product in App Store Connect.' => _t(
      context,
      'Premium purchase is not available yet.',
      'プレミアム購入は現在準備中です。',
    ),
    'Store is not available.' => _t(
      context,
      'Store is not available.',
      'ストアを利用できません。',
    ),
    'Purchase is waiting for store confirmation.' => _t(
      context,
      'Purchase is waiting for store confirmation.',
      'ストアの購入確認を待っています。',
    ),
    'Restore request sent to the store.' => _t(
      context,
      'Restore request sent to the store.',
      '購入の復元リクエストを送信しました。',
    ),
    'Premium is active. Ads are removed.' => _t(
      context,
      'Premium is active. Ads are removed.',
      'プレミアムが有効です。広告は表示されません。',
    ),
    'Purchase is pending.' => _t(
      context,
      'Purchase is pending.',
      '購入処理が保留中です。',
    ),
    'Purchase failed.' => _t(context, 'Purchase failed.', '購入に失敗しました。'),
    _ => message,
  };
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

  messenger?.showSnackBar(
    SnackBar(
      content: Text(_t(context, 'Could not open $url', '$url を開けませんでした')),
    ),
  );
}
