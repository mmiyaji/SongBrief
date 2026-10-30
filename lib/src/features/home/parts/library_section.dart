part of '../home_screen.dart';

class _LibrarySection extends StatefulWidget {
  const _LibrarySection({
    required this.overview,
    this.songsOverview,
    this.supplementalTrackIds = const <String>{},
  });

  final LibraryOverview overview;
  final LibraryOverview? songsOverview;
  final Set<String> supplementalTrackIds;

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
    if (oldWidget.overview != widget.overview ||
        oldWidget.songsOverview != widget.songsOverview ||
        oldWidget.supplementalTrackIds != widget.supplementalTrackIds) {
      final totalCount = _currentResultCount(_activeOverview);
      _visibleCount = _clampInt(
        _visibleCount,
        _initialVisibleCount,
        totalCount,
      );
    }
  }

  LibraryOverview get _activeOverview => _mode == _LibraryBrowseMode.songs
      ? widget.songsOverview ?? widget.overview
      : widget.overview;

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
        _currentResultCount(_activeOverview),
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
    final songsOverview = widget.songsOverview ?? overview;
    if (!overview.hasTracks && !songsOverview.hasTracks) {
      return const _EmptyLibraryPanel();
    }

    final songTracks = songsOverview.filteredTracks(_query);
    final sortedTracks = _libraryTracksForSort(
      songsOverview,
      songTracks,
      _sort,
    );
    final filteredTracks = overview.filteredTracks(_query);
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
        if (widget.supplementalTrackIds.isNotEmpty) ...[
          Text(
            _t(
              context,
              '${overview.totalTracks} library tracks · ${widget.supplementalTrackIds.length} supplemental history tracks. Songs include supplemental history; categories use library tracks.',
              '登録曲${overview.totalTracks}曲・補完履歴${widget.supplementalTrackIds.length}曲。曲一覧には補完履歴も表示します。分類は登録曲が対象です。',
              zh: '${overview.totalTracks} 首曲库歌曲 · ${widget.supplementalTrackIds.length} 首补充历史歌曲。歌曲列表包含补充历史；分类仅使用曲库歌曲。',
              ko: '보관함 곡 ${overview.totalTracks}개 · 보완 기록 곡 ${widget.supplementalTrackIds.length}개. 곡 목록에는 보완 기록이 포함되며 분류는 보관함 곡을 기준으로 합니다.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
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
            supplementalTrackIds: widget.supplementalTrackIds,
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
    required this.supplementalTrackIds,
    required this.totalCount,
    required this.nextCount,
    required this.onLoadMore,
  });

  final List<LibraryTrack> tracks;
  final Set<String> supplementalTrackIds;
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
            ...tracks.map(
              (track) => _LibraryTrackRow(
                track: track,
                isSupplemental: supplementalTrackIds.contains(track.id),
              ),
            ),
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
  const _LibraryTrackRow({required this.track, this.isSupplemental = false});

  final LibraryTrack track;
  final bool isSupplemental;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = _numberFormat(context);
    final artwork = ref.watch(trackArtworkProvider(track.id));
    final playback = ref.watch(playbackControllerProvider);
    final busy = playback.isBusy;
    final isPlaying = playback.isTrackPlaying(track.id, track: track);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => isSupplemental
            ? _openAppleMusicTrack(context, track)
            : _showTrackDetailSheet(context, track),
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
                        if (isSupplemental)
                          _MiniStatLabel(
                            icon: Icons.info_outline_rounded,
                            value: _t(
                              context,
                              'Supplemental · ${_playCountLabel(context, track.playCount)} (minimum)',
                              '補完 · ${_playCountLabel(context, track.playCount)}（最低）',
                              zh: '补充 · ${_playCountLabel(context, track.playCount)}（最低）',
                              ko: '보완 · ${_playCountLabel(context, track.playCount)} (최소)',
                            ),
                          )
                        else ...[
                          _MiniStatLabel(
                            icon: Icons.play_arrow_rounded,
                            value: number.format(track.playCount),
                          ),
                          _MiniStatLabel(
                            icon: Icons.fast_forward_rounded,
                            value: number.format(track.skipCount),
                          ),
                        ],
                        _MiniStatLabel(
                          icon: Icons.schedule_rounded,
                          value: isSupplemental && track.lastPlayedAt == null
                              ? _t(
                                  context,
                                  'Time unavailable',
                                  '再生日時不明',
                                  zh: '时间不可用',
                                  ko: '시간 정보 없음',
                                )
                              : _shortPlayedAtLabel(
                                  context,
                                  track.lastPlayedAt,
                                  isObservation:
                                      track.lastPlayedAtIsObservation,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSupplemental)
                IconButton.filledTonal(
                  onPressed: () => _openAppleMusicTrack(context, track),
                  tooltip: _t(
                    context,
                    'Open or search in Apple Music',
                    'Apple Musicで開く／検索',
                    zh: '在 Apple Music 中打开或搜索',
                    ko: 'Apple Music에서 열기 또는 검색',
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                )
              else
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
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
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
