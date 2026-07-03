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
          const SizedBox(height: 14),
          AdBannerSlot(placement: _t(context, 'Rankings', 'ランキング')),
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
