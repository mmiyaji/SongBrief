part of '../home_screen.dart';

class _RankingPanel extends ConsumerWidget {
  const _RankingPanel({
    required this.overview,
    required this.snapshotOverview,
    required this.history,
    required this.snapshotRecordingEnabled,
  });

  final LibraryOverview overview;
  final LibraryOverview snapshotOverview;
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
            snapshotOverview: snapshotOverview,
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
    required this.snapshotOverview,
    required this.history,
    required this.snapshotRecordingEnabled,
  });

  final LibraryOverview overview;
  final LibraryOverview snapshotOverview;
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
          _PeriodRankingSection(overview: snapshotOverview, history: history),
          const SizedBox(height: 18),
          _RisingRankingSection(overview: snapshotOverview, history: history),
          const SizedBox(height: 18),
          _RankMovementSection(overview: snapshotOverview, history: history),
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

    final nativeTrack = ref
        .watch(musicStatsControllerProvider)
        .asData
        ?.value
        .overview
        .trackById(item.trackId);
    if (nativeTrack == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTrackDetailSheet(context, nativeTrack),
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
  final current = history.latest;
  if (current == null) {
    return null;
  }
  final windowStart = _localDateOnly(
    current.capturedAt,
  ).subtract(_rankingRangeDuration(range));
  return history.latestDeltaSince(windowStart, includePeriodDate: true);
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
