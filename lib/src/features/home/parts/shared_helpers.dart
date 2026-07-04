part of '../home_screen.dart';

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
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
    final content = Padding(
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
                color: onTap == null ? null : theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: content,
    );
  }
}

class _RankingList extends StatefulWidget {
  const _RankingList({
    required this.overview,
    required this.scope,
    required this.entries,
    required this.showLastPlayedAt,
    required this.focus,
  });

  final LibraryOverview overview;
  final RankingScope scope;
  final List<RankingEntry> entries;
  final bool showLastPlayedAt;
  final RankingFocus? focus;

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList> {
  final _focusedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scheduleFocusedScroll();
  }

  @override
  void didUpdateWidget(covariant _RankingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus ||
        oldWidget.scope != widget.scope ||
        oldWidget.entries != widget.entries) {
      _scheduleFocusedScroll();
    }
  }

  void _scheduleFocusedScroll() {
    if (_focusedIndex() < 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _focusedRowKey.currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.34,
      );
    });
  }

  int _focusedIndex() {
    final focus = widget.focus;
    if (focus == null || focus.scope != widget.scope) {
      return -1;
    }
    return widget.entries.indexWhere(
      (entry) => _entryMatchesFocus(entry, focus),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final focusedIndex = _focusedIndex();
    final maxPlayCount = widget.entries
        .map((entry) => entry.playCount)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: widget.entries.indexed
          .map(
            (indexed) => _RankingRow(
              rank: indexed.$1 + 1,
              rowKey: indexed.$1 == focusedIndex ? _focusedRowKey : null,
              overview: widget.overview,
              scope: widget.scope,
              entry: indexed.$2,
              maxPlayCount: maxPlayCount,
              showLastPlayedAt: widget.showLastPlayedAt,
              isFocused: indexed.$1 == focusedIndex,
            ),
          )
          .toList(),
    );
  }
}

class _RankingRow extends ConsumerWidget {
  const _RankingRow({
    required this.rank,
    required this.rowKey,
    required this.overview,
    required this.scope,
    required this.entry,
    required this.maxPlayCount,
    required this.showLastPlayedAt,
    required this.isFocused,
  });

  final int rank;
  final Key? rowKey;
  final LibraryOverview overview;
  final RankingScope scope;
  final RankingEntry entry;
  final int maxPlayCount;
  final bool showLastPlayedAt;
  final bool isFocused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = _numberFormat(context);
    final ratio = maxPlayCount == 0 ? 0.0 : entry.playCount / maxPlayCount;
    final barColor = Color.lerp(
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      (rank - 1) / 12,
    )!;
    final isTopRank = rank <= 3;
    final rankBadgeFill = isTopRank
        ? theme.colorScheme.primary.withValues(alpha: 0.1)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32);
    final rankBadgeBorder = isTopRank
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.34);
    final rankBadgeTextColor = isTopRank
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final track = overview.trackById(entry.representativeTrackId);
    final artwork = track == null
        ? const AsyncData<Uint8List?>(null)
        : ref.watch(trackArtworkProvider(track.id));
    final onTap = _rankingEntryTapHandler(context, overview, entry, track);

    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: isFocused
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFocused
                ? theme.colorScheme.primary.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                        color: rankBadgeFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: rankBadgeBorder),
                      ),
                      child: Text(
                        '$rank',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: rankBadgeTextColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RankingArtwork(
                      entry: entry,
                      track: track,
                      artwork: artwork,
                      scope: scope,
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
                                ? _dateTimeFormat(
                                    context,
                                  ).format(entry.lastPlayedAt!)
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
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: ColoredBox(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.36,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio.clamp(0.04, 1.0),
                        child: SizedBox(
                          height: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: barColor),
                          ),
                        ),
                      ),
                    ),
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

VoidCallback? _rankingEntryTapHandler(
  BuildContext context,
  LibraryOverview overview,
  RankingEntry entry,
  LibraryTrack? representativeTrack,
) {
  return switch (entry.kind) {
    RankingEntryKind.track =>
      representativeTrack == null
          ? null
          : () => _showTrackDetailSheet(context, representativeTrack),
    RankingEntryKind.artist => () {
      final tracks = _tracksByArtist(overview, entry.title);
      if (tracks.isEmpty) {
        return;
      }
      _showTrackGroupSheet(
        context,
        title: entry.title,
        subtitle: _t(context, 'Artist songs', 'アーティストの曲'),
        icon: Icons.person_pin_rounded,
        tracks: tracks,
        rankingScope: RankingScope.artists,
        rankingTitle: entry.title,
      );
    },
    RankingEntryKind.album =>
      representativeTrack == null
          ? null
          : () {
              final tracks = _tracksByAlbum(overview, representativeTrack);
              if (tracks.isEmpty) {
                return;
              }
              _showTrackGroupSheet(
                context,
                title: representativeTrack.albumTitle,
                subtitle: _t(context, 'Album songs', 'アルバム内の曲'),
                icon: Icons.album_rounded,
                tracks: tracks,
                rankingScope: RankingScope.albums,
                rankingTitle: _albumRankingTitle(representativeTrack),
              );
            },
  };
}

class _RankingArtwork extends StatelessWidget {
  const _RankingArtwork({
    required this.entry,
    required this.track,
    required this.artwork,
    required this.scope,
  });

  final RankingEntry entry;
  final LibraryTrack? track;
  final AsyncValue<Uint8List?> artwork;
  final RankingScope scope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = artwork.asData?.value;
    final asset = track?.artworkAsset;
    final isArtist = scope == RankingScope.artists;
    final radius = BorderRadius.circular(isArtist ? 999 : 12);

    final Widget child;
    if (bytes != null) {
      child = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (asset != null) {
      child = Image.asset(asset, fit: BoxFit.cover);
    } else {
      child = ColoredBox(
        color: theme.colorScheme.primary.withValues(alpha: 0.14),
        child: Center(
          child: Text(
            entry.title.isEmpty ? '?' : entry.title.substring(0, 1),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(dimension: 46, child: child),
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
              _t(
                context,
                'No Music library songs were returned by iOS.',
                'iOSからミュージックライブラリの曲が返されませんでした。',
              ),
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
                _t(
                  context,
                  'Could not load the music library.',
                  'ミュージックライブラリを読み込めませんでした。',
                ),
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
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const SizedBox.expand(),
    );
  }
}

void _focusTrackInRanking(
  BuildContext context,
  WidgetRef ref,
  LibraryTrack track, {
  bool closeCurrentRoute = false,
}) {
  ref.read(rankingScopeProvider.notifier).setScope(RankingScope.tracks);
  ref.read(rankingFocusProvider.notifier).focus(RankingFocus.track(track.id));
  ref.read(homeSectionProvider.notifier).setSection(HomeSection.rankings);
  if (closeCurrentRoute) {
    Navigator.of(context).pop();
  }
}

void _focusRankingEntry(
  BuildContext context,
  WidgetRef ref, {
  required RankingScope scope,
  required String title,
  bool closeAllRoutes = false,
}) {
  ref.read(rankingScopeProvider.notifier).setScope(scope);
  ref
      .read(rankingFocusProvider.notifier)
      .focus(RankingFocus.entry(scope: scope, title: title));
  ref.read(homeSectionProvider.notifier).setSection(HomeSection.rankings);
  if (closeAllRoutes) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

List<RankingEntry> _visibleRankingEntries(
  List<RankingEntry> entries,
  RankingFocus? focus,
  int requestedCount,
) {
  final minimumVisibleEntries = RankingVisibleCountController.initialCount;
  final baseVisibleCount = _clampInt(
    requestedCount,
    minimumVisibleEntries,
    entries.length,
  );
  if (focus == null) {
    return entries.take(baseVisibleCount).toList(growable: false);
  }

  final focusIndex = entries.indexWhere(
    (entry) => _entryMatchesFocus(entry, focus),
  );
  final visibleCount = focusIndex < 0
      ? baseVisibleCount
      : _clampInt(focusIndex + 1, baseVisibleCount, entries.length);
  return entries.take(visibleCount).toList(growable: false);
}

int _clampInt(int value, int minimum, int maximum) {
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return value;
}

bool _entryMatchesFocus(RankingEntry entry, RankingFocus focus) {
  if (focus.scope != RankingScope.tracks &&
      focus.scope != RankingScope.recent) {
    return entry.title == focus.title;
  }
  final trackId = focus.trackId;
  return trackId != null && entry.representativeTrackId == trackId;
}

List<LibraryTrack> _tracksByArtist(LibraryOverview overview, String artist) {
  return overview.tracksForArtist(artist);
}

List<LibraryTrack> _tracksByAlbumArtist(
  LibraryOverview overview,
  String albumArtist,
) {
  return overview.tracksForAlbumArtist(albumArtist);
}

List<LibraryTrack> _tracksByAlbum(
  LibraryOverview overview,
  LibraryTrack album,
) {
  return overview.tracksForAlbum(album);
}

List<LibraryTrack> _tracksByGenre(LibraryOverview overview, String genre) {
  return overview.tracksForGenre(genre);
}

List<LibraryTrack> _tracksByPlaylist(
  LibraryOverview overview,
  String playlistName,
) {
  return overview.tracksForPlaylist(playlistName);
}

List<LibraryTrack> _tracksByReleaseYear(LibraryOverview overview, int year) {
  return _sortedDrilldownTracks(
    overview.tracks.where((track) => _releaseYearForTrack(track) == year),
  );
}

List<LibraryTrack> _tracksByReleaseYearAndGenre(
  LibraryOverview overview, {
  required int year,
  required String genre,
}) {
  return _sortedDrilldownTracks(
    overview.tracks.where(
      (track) =>
          _releaseYearForTrack(track) == year && _genreName(track) == genre,
    ),
  );
}

List<LibraryTrack> _tracksByReleaseYearExcludingGenres(
  LibraryOverview overview, {
  required int year,
  required Set<String> excludedGenres,
}) {
  return _sortedDrilldownTracks(
    overview.tracks.where((track) {
      return _releaseYearForTrack(track) == year &&
          !excludedGenres.contains(_genreName(track));
    }),
  );
}

List<LibraryTrack> _tracksByDecade(LibraryOverview overview, int decade) {
  return _sortedDrilldownTracks(
    overview.tracks.where((track) {
      final year = _releaseYearForTrack(track);
      return year != null && year ~/ 10 * 10 == decade;
    }),
  );
}

List<LibraryTrack> _tracksByCloudStatus(
  Iterable<LibraryTrack> tracks, {
  required bool isCloud,
}) {
  return _sortedDrilldownTracks(
    tracks.where((track) => track.isCloudItem == isCloud),
  );
}

List<LibraryTrack> _recentlyPlayedTracks(
  Iterable<LibraryTrack> tracks,
  Duration window,
) {
  final threshold = DateTime.now().subtract(window);
  final recent = tracks
      .where((track) {
        final playedAt = track.lastPlayedAt;
        return playedAt != null && !playedAt.isBefore(threshold);
      })
      .toList(growable: false);
  recent.sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
  return List.unmodifiable(recent);
}

List<LibraryTrack> _unplayedTracks(Iterable<LibraryTrack> tracks) {
  final unplayed = tracks.where((track) => track.playCount <= 0).toList();
  unplayed.sort(
    (a, b) =>
        _normalizeSearchText(a.title).compareTo(_normalizeSearchText(b.title)),
  );
  return List.unmodifiable(unplayed);
}

List<LibraryTrack> _aboveAveragePlayTracks(
  Iterable<LibraryTrack> tracks,
  double averagePlays,
) {
  if (averagePlays <= 0) {
    return const [];
  }
  return _sortedDrilldownTracks(
    tracks.where((track) => track.playCount >= averagePlays),
  );
}

List<LibraryTrack> _tracksByListeningTime(Iterable<LibraryTrack> tracks) {
  final sorted = tracks.toList(growable: false);
  sorted.sort((a, b) {
    final bySeconds = b.listeningSeconds.compareTo(a.listeningSeconds);
    if (bySeconds != 0) {
      return bySeconds;
    }
    final byPlays = b.playCount.compareTo(a.playCount);
    if (byPlays != 0) {
      return byPlays;
    }
    return _normalizeSearchText(
      a.title,
    ).compareTo(_normalizeSearchText(b.title));
  });
  return List.unmodifiable(sorted);
}

int _playlistCountForTracks(Iterable<LibraryTrack> tracks) {
  final names = <String>{};
  for (final track in tracks) {
    names.addAll(track.playlistNames);
  }
  return names.length;
}

List<LibraryTrack> _sortedDrilldownTracks(Iterable<LibraryTrack> tracks) {
  final sorted = tracks.toList()
    ..sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      if (byPlays != 0) {
        return byPlays;
      }
      return a.title.compareTo(b.title);
    });
  return List.unmodifiable(sorted);
}

String _albumRankingTitle(LibraryTrack track) {
  return '${track.albumArtist ?? track.artist} - ${track.albumTitle}';
}

String _percentageDetail(BuildContext context, int value, int total) {
  if (total <= 0) {
    return _t(context, '0% of tracks', '曲の0%', zh: '0% 的歌曲', ko: '곡의 0%');
  }
  final percentage = (value / total * 100).toStringAsFixed(1);
  return _t(
    context,
    '$percentage% of tracks',
    '曲の$percentage%',
    zh: '$percentage% 的歌曲',
    ko: '곡의 $percentage%',
  );
}

List<_BreakdownValue> _rankingBreakdownRows(
  BuildContext context,
  LibraryOverview overview,
  List<RankingEntry> entries,
  Color baseColor,
) {
  final visible = entries.take(5).toList(growable: false);
  if (visible.isEmpty) {
    return const [];
  }

  final maxValue = visible
      .map((entry) => entry.playCount)
      .reduce((a, b) => a > b ? a : b);
  return visible.indexed
      .map(
        (indexed) => _BreakdownValue(
          label: indexed.$2.title,
          trailing: _playCountLabel(context, indexed.$2.playCount),
          ratio: maxValue == 0 ? 0 : indexed.$2.playCount / maxValue,
          color: Color.lerp(baseColor, Colors.white, indexed.$1 * 0.08)!,
          onTap: () {
            final tracks = _tracksByArtist(overview, indexed.$2.title);
            if (tracks.isEmpty) {
              return;
            }
            _showTrackGroupSheet(
              context,
              title: indexed.$2.title,
              subtitle: _t(context, 'Artist songs', 'アーティストの曲'),
              icon: Icons.person_pin_rounded,
              tracks: tracks,
              rankingScope: RankingScope.artists,
              rankingTitle: indexed.$2.title,
            );
          },
        ),
      )
      .toList(growable: false);
}

List<_BreakdownValue> _genreBreakdownRows(
  BuildContext context,
  List<LibraryTrack> tracks,
  ThemeData theme,
) {
  final groups = <String, _LibraryGroupAccumulator>{};
  for (final track in tracks) {
    final genre = track.genre;
    if (genre == null || genre.trim().isEmpty) {
      continue;
    }
    groups
        .putIfAbsent(
          genre,
          () => _LibraryGroupAccumulator(
            key: genre,
            title: genre,
            subtitle: _t(context, 'Genre', 'ジャンル'),
            icon: Icons.category_rounded,
          ),
        )
        .add(track);
  }

  final values = groups.values.map((group) => group.toEntry()).toList()
    ..sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      if (byPlays != 0) {
        return byPlays;
      }
      return b.trackCount.compareTo(a.trackCount);
    });
  final visible = values.take(5).toList(growable: false);
  if (visible.isEmpty) {
    return const [];
  }

  final maxValue = visible
      .map((entry) => entry.playCount == 0 ? entry.trackCount : entry.playCount)
      .reduce((a, b) => a > b ? a : b);
  return visible.indexed
      .map((indexed) {
        final value = indexed.$2.playCount == 0
            ? indexed.$2.trackCount
            : indexed.$2.playCount;
        return _BreakdownValue(
          label: indexed.$2.title,
          trailing: indexed.$2.playCount == 0
              ? _trackCountLabel(context, indexed.$2.trackCount)
              : _playCountLabel(context, indexed.$2.playCount),
          ratio: maxValue == 0 ? 0 : value / maxValue,
          color: Color.lerp(
            theme.colorScheme.secondary,
            Colors.white,
            indexed.$1 * 0.08,
          )!,
          onTap: () => _showTrackGroupSheet(
            context,
            title: indexed.$2.title,
            subtitle: _t(context, 'Genre songs', 'ジャンルの曲'),
            icon: Icons.category_rounded,
            tracks: indexed.$2.tracks,
          ),
        );
      })
      .toList(growable: false);
}

List<_BreakdownValue> _sourceBreakdownRows(
  BuildContext context,
  LibraryOverview overview,
  ThemeData theme,
) {
  final tracks = overview.tracks;
  if (tracks.isEmpty) {
    return const [];
  }

  final cloudCount = tracks.where((track) => track.isCloudItem).length;
  final localCount = tracks.length - cloudCount;
  final rows = [
    (_t(context, 'Local', 'ローカル'), localCount, theme.colorScheme.tertiary),
    (_t(context, 'Cloud', 'クラウド'), cloudCount, theme.colorScheme.primary),
  ].where((row) => row.$2 > 0).toList(growable: false);

  return rows
      .map((row) {
        final isCloud = row.$1 == _t(context, 'Cloud', 'クラウド');
        final sourceTracks = _tracksByCloudStatus(
          overview.tracks,
          isCloud: isCloud,
        );
        return _BreakdownValue(
          label: row.$1,
          trailing: _trackCountLabel(context, row.$2),
          ratio: row.$2 / tracks.length,
          color: row.$3,
          onTap: sourceTracks.isEmpty
              ? null
              : () => _showTrackGroupSheet(
                  context,
                  title: row.$1,
                  subtitle: isCloud
                      ? _t(context, 'Cloud library items', 'クラウド項目')
                      : _t(context, 'Local library items', 'ローカル項目'),
                  icon: isCloud ? Icons.cloud_rounded : Icons.storage_rounded,
                  tracks: sourceTracks,
                ),
        );
      })
      .toList(growable: false);
}

List<LibraryTrack> _libraryTracksForSort(
  LibraryOverview overview,
  List<LibraryTrack> tracks,
  _LibrarySortMode sort,
) {
  if (identical(tracks, overview.tracks)) {
    return switch (sort) {
      _LibrarySortMode.recent => overview.tracksByRecent,
      _LibrarySortMode.plays => overview.tracksByPlayCount,
      _LibrarySortMode.skips => overview.tracksBySkipCount,
      _LibrarySortMode.title => overview.tracksByTitle,
    };
  }
  return _sortLibraryTracks(tracks, sort);
}

List<LibraryTrack> _sortLibraryTracks(
  Iterable<LibraryTrack> tracks,
  _LibrarySortMode sort,
) {
  final sorted = tracks.toList(growable: false);
  sorted.sort((a, b) {
    final primary = switch (sort) {
      _LibrarySortMode.recent => _compareDateDesc(
        a.lastPlayedAt,
        b.lastPlayedAt,
      ),
      _LibrarySortMode.plays => b.playCount.compareTo(a.playCount),
      _LibrarySortMode.skips => b.skipCount.compareTo(a.skipCount),
      _LibrarySortMode.title => _normalizeSearchText(
        a.title,
      ).compareTo(_normalizeSearchText(b.title)),
    };
    if (primary != 0) {
      return primary;
    }
    final byTitle = _normalizeSearchText(
      a.title,
    ).compareTo(_normalizeSearchText(b.title));
    if (byTitle != 0) {
      return byTitle;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
}

List<_LibraryGroupEntry> _libraryGroupsForMode(
  BuildContext context,
  _LibraryBrowseMode mode,
  List<LibraryTrack> tracks,
  _LibrarySortMode sort,
) {
  if (mode == _LibraryBrowseMode.songs) {
    return const [];
  }

  final groups = <String, _LibraryGroupAccumulator>{};
  for (final track in tracks) {
    switch (mode) {
      case _LibraryBrowseMode.songs:
        break;
      case _LibraryBrowseMode.artists:
        groups
            .putIfAbsent(
              track.artist,
              () => _LibraryGroupAccumulator(
                key: track.artist,
                title: track.artist,
                subtitle: _t(context, 'Artist', 'アーティスト'),
                icon: Icons.person_rounded,
                rankingScope: RankingScope.artists,
                rankingTitle: track.artist,
              ),
            )
            .add(track);
      case _LibraryBrowseMode.albums:
        final albumTitle = _albumRankingTitle(track);
        groups
            .putIfAbsent(
              albumTitle,
              () => _LibraryGroupAccumulator(
                key: albumTitle,
                title: track.albumTitle,
                subtitle: track.albumArtist ?? track.artist,
                icon: Icons.album_rounded,
                rankingScope: RankingScope.albums,
                rankingTitle: albumTitle,
              ),
            )
            .add(track);
      case _LibraryBrowseMode.genres:
        final genre = track.genre;
        if (genre == null || genre.trim().isEmpty) {
          break;
        }
        groups
            .putIfAbsent(
              genre,
              () => _LibraryGroupAccumulator(
                key: genre,
                title: genre,
                subtitle: _t(context, 'Genre', 'ジャンル'),
                icon: Icons.category_rounded,
              ),
            )
            .add(track);
      case _LibraryBrowseMode.playlists:
        for (final playlistName in track.playlistNames) {
          groups
              .putIfAbsent(
                playlistName,
                () => _LibraryGroupAccumulator(
                  key: playlistName,
                  title: playlistName,
                  subtitle: _t(context, 'Playlist', 'プレイリスト'),
                  icon: Icons.playlist_play_rounded,
                ),
              )
              .add(track);
        }
    }
  }

  final entries = groups.values.map((group) => group.toEntry()).toList();
  entries.sort((a, b) {
    final primary = switch (sort) {
      _LibrarySortMode.recent => _compareDateDesc(
        a.lastPlayedAt,
        b.lastPlayedAt,
      ),
      _LibrarySortMode.plays => b.playCount.compareTo(a.playCount),
      _LibrarySortMode.skips => b.skipCount.compareTo(a.skipCount),
      _LibrarySortMode.title => _normalizeSearchText(
        a.title,
      ).compareTo(_normalizeSearchText(b.title)),
    };
    if (primary != 0) {
      return primary;
    }
    return _normalizeSearchText(
      a.title,
    ).compareTo(_normalizeSearchText(b.title));
  });
  return entries;
}

int _compareDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return b.compareTo(a);
}

LibraryTrack? _latestPlayedTrack(List<LibraryTrack> tracks) {
  LibraryTrack? latest;
  for (final track in tracks) {
    final playedAt = track.lastPlayedAt;
    if (playedAt == null) {
      continue;
    }
    final current = latest?.lastPlayedAt;
    if (current == null || playedAt.isAfter(current)) {
      latest = track;
    }
  }
  return latest;
}

String _normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}

List<_SnapshotTrendValue> _snapshotTrendValues(
  BuildContext context,
  SnapshotHistory history,
) {
  final snapshots = history.snapshots;
  if (snapshots.length < 2) {
    return const [];
  }

  final start = _clampInt(snapshots.length - 8, 1, snapshots.length - 1);
  final dateFormat = DateFormat.Md(_localeName(context));
  return [
    for (var index = start; index < snapshots.length; index++)
      _SnapshotTrendValue.fromDelta(
        label: dateFormat.format(snapshots[index].capturedAt),
        delta: SnapshotDelta.compare(
          previous: snapshots[index - 1],
          current: snapshots[index],
        ),
      ),
  ];
}

class _SnapshotTrendValue {
  const _SnapshotTrendValue({
    required this.label,
    required this.playDelta,
    required this.skipDelta,
  });

  final String label;
  final int playDelta;
  final int skipDelta;

  factory _SnapshotTrendValue.fromDelta({
    required String label,
    required SnapshotDelta delta,
  }) {
    return _SnapshotTrendValue(
      label: label,
      playDelta: delta.totalPlayDelta,
      skipDelta: delta.totalSkipDelta,
    );
  }
}

List<_SmartListDefinition> _smartListsFor(
  BuildContext context,
  LibraryOverview overview,
) {
  final now = overview.generatedAt;
  final averagePlays = overview.totalTracks == 0
      ? 0
      : (overview.totalPlayCount / overview.totalTracks).ceil();
  final favoriteThreshold = averagePlays < 5 ? 5 : averagePlays;
  final sleepingFavorites =
      overview.tracks
          .where((track) {
            final lastPlayedAt = track.lastPlayedAt;
            if (lastPlayedAt == null) {
              return false;
            }
            return track.playCount >= favoriteThreshold &&
                now.difference(lastPlayedAt).inDays >= 30;
          })
          .toList(growable: false)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));

  final highSkipRate =
      overview.tracks
          .where((track) {
            final interactions = track.playCount + track.skipCount;
            if (interactions < 4) {
              return false;
            }
            return track.skipCount / interactions >= 0.2;
          })
          .toList(growable: false)
        ..sort(_compareSkipPressureDesc);

  final underplayed =
      overview.tracks
          .where((track) => track.playCount <= 1)
          .toList(growable: false)
        ..sort(
          (a, b) => _normalizeSearchText(
            a.title,
          ).compareTo(_normalizeSearchText(b.title)),
        );

  final notInPlaylists =
      overview.tracks
          .where((track) => track.playlistNames.isEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));

  return [
    _SmartListDefinition(
      icon: Icons.nights_stay_outlined,
      title: _t(context, 'Sleeping favorites', '眠っているお気に入り'),
      subtitle: _t(
        context,
        'Often played, not heard in 30+ days',
        'よく聴いたまま30日以上再生していない曲',
      ),
      emptyLabel: _t(context, 'No dormant favorites', '該当する曲はありません'),
      tracks: sleepingFavorites,
    ),
    _SmartListDefinition(
      icon: Icons.trending_down_rounded,
      title: _t(context, 'High skip rate', 'スキップ率が高い曲'),
      subtitle: _t(
        context,
        'Songs with repeated skips versus plays',
        '再生に対してスキップが目立つ曲',
      ),
      emptyLabel: _t(context, 'No high-skip songs', '該当する曲はありません'),
      tracks: highSkipRate,
    ),
    _SmartListDefinition(
      icon: Icons.radio_button_unchecked_rounded,
      title: _t(context, 'Underplayed', '未再生・低再生'),
      subtitle: _t(context, 'Songs with one play or less', '再生回数が1回以下の曲'),
      emptyLabel: _t(context, 'No underplayed songs', '該当する曲はありません'),
      tracks: underplayed,
    ),
    _SmartListDefinition(
      icon: Icons.playlist_remove_rounded,
      title: _t(context, 'Not in playlists', 'プレイリスト未所属'),
      subtitle: _t(
        context,
        'Songs without returned playlist membership',
        '取得できたプレイリストに含まれていない曲',
      ),
      emptyLabel: _t(context, 'All songs are in playlists', '該当する曲はありません'),
      tracks: notInPlaylists,
    ),
  ];
}

int _compareSkipPressureDesc(LibraryTrack a, LibraryTrack b) {
  final aInteractions = a.playCount + a.skipCount;
  final bInteractions = b.playCount + b.skipCount;
  final aRate = aInteractions == 0 ? 0.0 : a.skipCount / aInteractions;
  final bRate = bInteractions == 0 ? 0.0 : b.skipCount / bInteractions;
  final byRate = bRate.compareTo(aRate);
  if (byRate != 0) {
    return byRate;
  }
  final bySkips = b.skipCount.compareTo(a.skipCount);
  if (bySkips != 0) {
    return bySkips;
  }
  return _normalizeSearchText(a.title).compareTo(_normalizeSearchText(b.title));
}

class _SmartListDefinition {
  const _SmartListDefinition({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emptyLabel,
    required this.tracks,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String emptyLabel;
  final List<LibraryTrack> tracks;
}

class _OverviewInsightValue {
  const _OverviewInsightValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final VoidCallback? onTap;
}

class _BreakdownValue {
  const _BreakdownValue({
    required this.label,
    required this.trailing,
    required this.ratio,
    required this.color,
    this.onTap,
  });

  final String label;
  final String trailing;
  final double ratio;
  final Color color;
  final VoidCallback? onTap;
}

class _LibraryGroupEntry {
  const _LibraryGroupEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tracks,
    required this.playCount,
    required this.skipCount,
    required this.listeningSeconds,
    required this.lastPlayedAt,
    required this.representativeTrack,
    this.rankingScope,
    this.rankingTitle,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<LibraryTrack> tracks;
  final int playCount;
  final int skipCount;
  final int listeningSeconds;
  final DateTime? lastPlayedAt;
  final LibraryTrack? representativeTrack;
  final RankingScope? rankingScope;
  final String? rankingTitle;

  int get trackCount => tracks.length;
}

class _LibraryGroupAccumulator {
  _LibraryGroupAccumulator({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.rankingScope,
    this.rankingTitle,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final RankingScope? rankingScope;
  final String? rankingTitle;
  final List<LibraryTrack> tracks = [];

  void add(LibraryTrack track) {
    tracks.add(track);
  }

  _LibraryGroupEntry toEntry() {
    final sortedTracks = _sortLibraryTracks(tracks, _LibrarySortMode.plays);
    final playCount = tracks.fold<int>(
      0,
      (total, track) => total + track.playCount,
    );
    final skipCount = tracks.fold<int>(
      0,
      (total, track) => total + track.skipCount,
    );
    final listeningSeconds = tracks.fold<int>(
      0,
      (total, track) => total + track.listeningSeconds,
    );
    DateTime? lastPlayedAt;
    for (final track in tracks) {
      final playedAt = track.lastPlayedAt;
      if (playedAt != null &&
          (lastPlayedAt == null || playedAt.isAfter(lastPlayedAt))) {
        lastPlayedAt = playedAt;
      }
    }

    return _LibraryGroupEntry(
      title: title,
      subtitle: subtitle,
      icon: icon,
      tracks: List.unmodifiable(sortedTracks),
      playCount: playCount,
      skipCount: skipCount,
      listeningSeconds: listeningSeconds,
      lastPlayedAt: lastPlayedAt,
      representativeTrack: sortedTracks.isEmpty ? null : sortedTracks.first,
      rankingScope: rankingScope,
      rankingTitle: rankingTitle,
    );
  }
}

class _SummaryValue {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _ReleaseYearBucket {
  const _ReleaseYearBucket({
    required this.year,
    required this.trackCount,
    required this.playCount,
  });

  final int year;
  final int trackCount;
  final int playCount;

  double get averagePlays => trackCount == 0 ? 0 : playCount / trackCount;
}

class _ReleaseYearAccumulator {
  _ReleaseYearAccumulator(this.year);

  final int year;
  int trackCount = 0;
  int playCount = 0;

  void add(LibraryTrack track) {
    trackCount += 1;
    playCount += track.playCount;
  }

  _ReleaseYearBucket toBucket() {
    return _ReleaseYearBucket(
      year: year,
      trackCount: trackCount,
      playCount: playCount,
    );
  }
}

class _ActivityHeatmapDay {
  const _ActivityHeatmapDay({
    required this.date,
    required this.playCount,
    this.trackDeltas = const [],
  });

  final DateTime date;
  final int playCount;
  final List<TrackCounterDelta> trackDeltas;
}

class _ActivityHeatmapSummary {
  const _ActivityHeatmapSummary({
    required this.activeDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.peakDay,
    required this.bestWeekday,
  });

  final int activeDays;
  final int currentStreak;
  final int longestStreak;
  final _ActivityHeatmapDay? peakDay;
  final int? bestWeekday;
}

class _WeekdayActivityValue {
  const _WeekdayActivityValue({
    required this.weekday,
    required this.playCount,
    required this.activeDays,
  });

  final int weekday;
  final int playCount;
  final int activeDays;
}

class _GenreYearStack {
  const _GenreYearStack({
    required this.year,
    required this.segments,
    required this.playCount,
  });

  final int year;
  final List<_GenreStackSegment> segments;
  final int playCount;
}

class _GenreStackSegment {
  const _GenreStackSegment({required this.genre, required this.playCount});

  final String genre;
  final int playCount;
}

class _DecadePlayBucket {
  const _DecadePlayBucket({
    required this.decade,
    required this.label,
    required this.trackCount,
    required this.playCount,
  });

  final int decade;
  final String label;
  final int trackCount;
  final int playCount;
}

class _GroupSummaryValue {
  const _GroupSummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

const _appVersionLabel = '1.0.0+1';

String _hoursLabel(int listeningSeconds) {
  final hours = listeningSeconds / 3600;
  if (hours >= 100) {
    return NumberFormat.decimalPattern().format(hours.round());
  }
  return hours.toStringAsFixed(1);
}

String _snapshotSourceLabel(BuildContext context, String source) {
  return switch (source) {
    'background' => _t(context, 'background record', 'バックグラウンド記録'),
    _ => _t(context, 'app record', 'アプリ記録'),
  };
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString();
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String _playedAtLabel(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) {
    return _t(context, 'None', 'なし');
  }
  return _dateTimeFormat(context).format(dateTime);
}

String _shortPlayedAtLabel(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) {
    return _t(context, 'None', 'なし');
  }
  final now = DateTime.now();
  if (dateTime.year == now.year &&
      dateTime.month == now.month &&
      dateTime.day == now.day) {
    return _t(
      context,
      'Today ${DateFormat('HH:mm').format(dateTime)}',
      '今日 ${DateFormat('HH:mm').format(dateTime)}',
      zh: '今天 ${DateFormat('HH:mm').format(dateTime)}',
      ko: '오늘 ${DateFormat('HH:mm').format(dateTime)}',
    );
  }
  return DateFormat('M/d').format(dateTime);
}

List<_ReleaseYearBucket> _releaseYearBuckets(List<LibraryTrack> tracks) {
  final buckets = <int, _ReleaseYearAccumulator>{};
  for (final track in tracks) {
    final year = _releaseYearForTrack(track);
    if (year == null) {
      continue;
    }
    buckets.putIfAbsent(year, () => _ReleaseYearAccumulator(year)).add(track);
  }

  final values = buckets.values.map((bucket) => bucket.toBucket()).toList()
    ..sort((a, b) => a.year.compareTo(b.year));
  return List.unmodifiable(values);
}

List<_GenreYearStack> _genreYearStacks(List<LibraryTrack> tracks) {
  final genreTotals = <String, int>{};
  final yearGenreTotals = <int, Map<String, int>>{};
  for (final track in tracks) {
    final year = _releaseYearForTrack(track);
    if (year == null) {
      continue;
    }
    final genre = _genreName(track);
    genreTotals[genre] = (genreTotals[genre] ?? 0) + track.playCount;
    final byGenre = yearGenreTotals.putIfAbsent(year, () => <String, int>{});
    byGenre[genre] = (byGenre[genre] ?? 0) + track.playCount;
  }

  if (yearGenreTotals.isEmpty) {
    return const [];
  }

  final topGenres = genreTotals.entries.toList()
    ..sort((a, b) {
      final byPlays = b.value.compareTo(a.value);
      if (byPlays != 0) {
        return byPlays;
      }
      return a.key.compareTo(b.key);
    });
  final allowedGenres = topGenres.take(4).map((entry) => entry.key).toSet();
  const otherGenre = 'Other';

  final stacks = yearGenreTotals.entries.map((entry) {
    final segmentsByGenre = <String, int>{};
    for (final genreEntry in entry.value.entries) {
      final genre = allowedGenres.contains(genreEntry.key)
          ? genreEntry.key
          : otherGenre;
      segmentsByGenre[genre] = (segmentsByGenre[genre] ?? 0) + genreEntry.value;
    }
    final segments =
        segmentsByGenre.entries
            .map(
              (segment) => _GenreStackSegment(
                genre: segment.key,
                playCount: segment.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final aIndex = _genreSortIndex(a.genre, allowedGenres);
            final bIndex = _genreSortIndex(b.genre, allowedGenres);
            final byIndex = aIndex.compareTo(bIndex);
            if (byIndex != 0) {
              return byIndex;
            }
            return b.playCount.compareTo(a.playCount);
          });
    final total = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.playCount,
    );
    return _GenreYearStack(
      year: entry.key,
      segments: List.unmodifiable(segments),
      playCount: total,
    );
  }).toList()..sort((a, b) => a.year.compareTo(b.year));

  return List.unmodifiable(stacks);
}

List<String> _genreLegendItems(List<_GenreYearStack> stacks) {
  final genres = <String>[];
  for (final stack in stacks) {
    for (final segment in stack.segments) {
      if (!genres.contains(segment.genre)) {
        genres.add(segment.genre);
      }
    }
  }
  genres.sort((a, b) {
    if (a == 'Other') {
      return 1;
    }
    if (b == 'Other') {
      return -1;
    }
    return a.compareTo(b);
  });
  return List.unmodifiable(genres);
}

int _genreSortIndex(String genre, Set<String> allowedGenres) {
  final ordered = allowedGenres.toList()..sort();
  final index = ordered.indexOf(genre);
  return index < 0 ? ordered.length + 1 : index;
}

List<_DecadePlayBucket> _decadePlayBuckets(List<LibraryTrack> tracks) {
  final byDecade = <int, ({int trackCount, int playCount})>{};
  for (final track in tracks) {
    final year = _releaseYearForTrack(track);
    if (year == null) {
      continue;
    }
    final decade = year ~/ 10 * 10;
    final current = byDecade[decade] ?? (trackCount: 0, playCount: 0);
    byDecade[decade] = (
      trackCount: current.trackCount + 1,
      playCount: current.playCount + track.playCount,
    );
  }

  final buckets =
      byDecade.entries
          .map(
            (entry) => _DecadePlayBucket(
              decade: entry.key,
              label: '${entry.key}s',
              trackCount: entry.value.trackCount,
              playCount: entry.value.playCount,
            ),
          )
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));
  return List.unmodifiable(buckets);
}

int? _releaseYearForTrack(LibraryTrack track) {
  final year = track.releaseDate?.toLocal().year;
  final currentYear = DateTime.now().year + 1;
  if (year == null || year < 1900 || year > currentYear) {
    return null;
  }
  return year;
}

String _genreName(LibraryTrack track) {
  final genre = track.genre?.trim();
  return genre == null || genre.isEmpty ? 'Unknown' : genre;
}

List<Color> _analysisPalette(ThemeData theme) {
  return [
    theme.colorScheme.primary,
    theme.colorScheme.secondary,
    theme.colorScheme.tertiary,
    Color.lerp(theme.colorScheme.primary, theme.colorScheme.secondary, 0.5)!,
    Color.lerp(theme.colorScheme.secondary, theme.colorScheme.tertiary, 0.55)!,
  ];
}

List<_ActivityHeatmapDay> _activityHeatmapDays({
  required LibraryOverview overview,
  required SnapshotHistory history,
}) {
  final today = _localDateOnly(DateTime.now());
  final rawStart = today.subtract(const Duration(days: 83));
  final start = rawStart.subtract(Duration(days: rawStart.weekday % 7));
  final valuesByDay = <String, int>{};
  final trackDeltasByDay = <String, List<TrackCounterDelta>>{};

  if (history.snapshots.length >= 2) {
    for (var index = 1; index < history.snapshots.length; index++) {
      final delta = SnapshotDelta.compare(
        previous: history.snapshots[index - 1],
        current: history.snapshots[index],
      );
      final key = snapshotDateKey(delta.current.capturedAt);
      valuesByDay[key] = (valuesByDay[key] ?? 0) + delta.totalPlayDelta;
      if (delta.trackDeltas.isNotEmpty) {
        trackDeltasByDay
            .putIfAbsent(key, () => <TrackCounterDelta>[])
            .addAll(delta.trackDeltas);
      }
    }
  } else {
    for (final track in overview.tracks) {
      final playedAt = track.lastPlayedAt;
      if (playedAt == null) {
        continue;
      }
      final day = _localDateOnly(playedAt);
      if (day.isBefore(start) || day.isAfter(today)) {
        continue;
      }
      final estimatedPlays = math.max(1, (track.playCount / 16).round());
      final key = snapshotDateKey(day);
      valuesByDay[key] = (valuesByDay[key] ?? 0) + estimatedPlays;
      trackDeltasByDay
          .putIfAbsent(key, () => <TrackCounterDelta>[])
          .add(
            TrackCounterDelta(
              id: track.id,
              title: track.title,
              artist: track.artist,
              albumTitle: track.albumTitle,
              playDelta: estimatedPlays,
              skipDelta: 0,
              listeningSecondsDelta: track.duration.inSeconds * estimatedPlays,
            ),
          );
    }
  }

  final days = <_ActivityHeatmapDay>[];
  for (
    var day = start;
    !day.isAfter(today);
    day = day.add(const Duration(days: 1))
  ) {
    final key = snapshotDateKey(day);
    final trackDeltas = trackDeltasByDay[key] ?? const <TrackCounterDelta>[];
    days.add(
      _ActivityHeatmapDay(
        date: day,
        playCount: valuesByDay[key] ?? 0,
        trackDeltas: _topActivityTrackDeltas(trackDeltas),
      ),
    );
  }
  return List.unmodifiable(days);
}

List<TrackCounterDelta> _topActivityTrackDeltas(
  Iterable<TrackCounterDelta> deltas,
) {
  final sorted = deltas.toList(growable: false)
    ..sort((a, b) {
      final byPlays = b.playDelta.compareTo(a.playDelta);
      if (byPlays != 0) {
        return byPlays;
      }
      final bySeconds = b.listeningSecondsDelta.compareTo(
        a.listeningSecondsDelta,
      );
      if (bySeconds != 0) {
        return bySeconds;
      }
      return a.title.compareTo(b.title);
    });
  return List.unmodifiable(sorted.take(5));
}

List<List<_ActivityHeatmapDay>> _activityHeatmapWeeks(
  List<_ActivityHeatmapDay> days,
) {
  final weeks = <List<_ActivityHeatmapDay>>[];
  for (var index = 0; index < days.length; index += 7) {
    weeks.add(
      List.unmodifiable(days.skip(index).take(7).toList(growable: false)),
    );
  }
  return List.unmodifiable(weeks);
}

Color _activityHeatmapColor(ThemeData theme, int value, int maxValue) {
  if (value <= 0 || maxValue <= 0) {
    return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.48);
  }
  final normalized = (value / maxValue).clamp(0.0, 1.0);
  final base = theme.colorScheme.primary.withValues(alpha: 0.28);
  return Color.lerp(base, theme.colorScheme.primary, 0.32 + normalized * 0.68)!;
}

_ActivityHeatmapSummary _activityHeatmapSummary(
  List<_ActivityHeatmapDay> days,
) {
  var activeDays = 0;
  var currentRun = 0;
  var longestStreak = 0;
  _ActivityHeatmapDay? peakDay;

  for (final day in days) {
    if (day.playCount > 0) {
      activeDays += 1;
      currentRun += 1;
      longestStreak = math.max(longestStreak, currentRun);
      if (peakDay == null || day.playCount > peakDay.playCount) {
        peakDay = day;
      }
    } else {
      currentRun = 0;
    }
  }

  var currentStreak = 0;
  for (final day in days.reversed) {
    if (day.playCount <= 0) {
      break;
    }
    currentStreak += 1;
  }

  final weekdays = _weekdayActivityValues(days);
  _WeekdayActivityValue? bestWeekday;
  for (final weekday in weekdays) {
    if (weekday.playCount <= 0) {
      continue;
    }
    if (bestWeekday == null || weekday.playCount > bestWeekday.playCount) {
      bestWeekday = weekday;
    }
  }

  return _ActivityHeatmapSummary(
    activeDays: activeDays,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    peakDay: peakDay,
    bestWeekday: bestWeekday?.weekday,
  );
}

List<_WeekdayActivityValue> _weekdayActivityValues(
  List<_ActivityHeatmapDay> days,
) {
  final plays = List<int>.filled(8, 0);
  final activeDays = List<int>.filled(8, 0);
  for (final day in days) {
    final weekday = day.date.weekday;
    plays[weekday] += day.playCount;
    if (day.playCount > 0) {
      activeDays[weekday] += 1;
    }
  }
  return List.unmodifiable(
    List.generate(
      7,
      (index) => _WeekdayActivityValue(
        weekday: index + 1,
        playCount: plays[index + 1],
        activeDays: activeDays[index + 1],
      ),
    ),
  );
}

_ActivityHeatmapDay? _validSelectedActivityDay(
  List<_ActivityHeatmapDay> days,
  _ActivityHeatmapDay? selectedDay,
) {
  if (selectedDay == null) {
    return null;
  }
  for (final day in days) {
    if (_sameActivityDate(day, selectedDay)) {
      return day;
    }
  }
  return null;
}

bool _sameActivityDate(
  _ActivityHeatmapDay? first,
  _ActivityHeatmapDay? second,
) {
  if (first == null || second == null) {
    return false;
  }
  return snapshotDateKey(first.date) == snapshotDateKey(second.date);
}

String _activityHeatmapViewLabel(
  BuildContext context,
  _ActivityHeatmapView view,
) {
  return switch (view) {
    _ActivityHeatmapView.calendar => _t(context, 'Calendar', 'カレンダー'),
    _ActivityHeatmapView.weekdays => _t(context, 'Weekdays', '曜日'),
    _ActivityHeatmapView.highlights => _t(context, 'Highlights', 'ハイライト'),
  };
}

const _calendarWeekdayOrder = <int>[
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

String _weekdayLabel(BuildContext context, int weekday) {
  final monday = DateTime(2026, 1, 5);
  final date = monday.add(Duration(days: weekday - 1));
  return DateFormat.E(_localeName(context)).format(date);
}

String _weekdayShortLabel(BuildContext context, int weekday) {
  final label = _weekdayLabel(context, weekday);
  final locale = _localeName(context);
  if (locale.startsWith('ja')) {
    return label.replaceAll('曜', '');
  }
  return label.length <= 2 ? label : label.substring(0, 2);
}

bool _isWeekend(int weekday) {
  return weekday == DateTime.saturday || weekday == DateTime.sunday;
}

DateTime _localDateOnly(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

List<_TrackTrendValue> _trackTrendValues({
  required BuildContext context,
  required String trackId,
  required SnapshotHistory history,
  required TrendRange range,
}) {
  final buckets = _trackTrendBuckets(context, range);
  final values = List<int>.filled(buckets.length, 0);
  final snapshots = history.snapshots.toList(growable: false)
    ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

  if (snapshots.length >= 2) {
    for (var index = 1; index < snapshots.length; index++) {
      final current = snapshots[index];
      final currentDay = _localDateOnly(current.capturedAt);
      final bucketIndex = buckets.indexWhere(
        (bucket) => bucket.contains(currentDay),
      );
      if (bucketIndex < 0) {
        continue;
      }

      values[bucketIndex] += _trackPlayDeltaBetween(
        previous: snapshots[index - 1],
        current: current,
        trackId: trackId,
      );
    }
  }

  return [
    for (final indexed in buckets.indexed)
      _TrackTrendValue(label: indexed.$2.label, playDelta: values[indexed.$1]),
  ];
}

List<_TrackTrendBucket> _trackTrendBuckets(
  BuildContext context,
  TrendRange range,
) {
  final today = _localDateOnly(DateTime.now());
  return switch (range) {
    TrendRange.week => [
      for (var offset = 6; offset >= 0; offset--)
        _TrackTrendBucket(
          start: today.subtract(Duration(days: offset)),
          end: today.subtract(Duration(days: offset)),
          label: _weekdayShortLabel(
            context,
            today.subtract(Duration(days: offset)).weekday,
          ),
        ),
    ],
    TrendRange.month => [
      for (var offset = 3; offset >= 0; offset--)
        _TrackTrendBucket(
          start: today.subtract(Duration(days: offset * 7 + 6)),
          end: today.subtract(Duration(days: offset * 7)),
          label: offset == 0
              ? _t(context, 'This week', '今週')
              : _t(
                  context,
                  '${offset + 1}w',
                  '${offset + 1}週',
                  zh: '${offset + 1}周',
                  ko: '${offset + 1}주',
                ),
        ),
    ],
    TrendRange.year => [
      for (var offset = 11; offset >= 0; offset--)
        _monthTrendBucket(
          context: context,
          monthStart: DateTime(today.year, today.month - offset),
          isCurrentMonth: offset == 0,
          today: today,
        ),
    ],
  };
}

_TrackTrendBucket _monthTrendBucket({
  required BuildContext context,
  required DateTime monthStart,
  required bool isCurrentMonth,
  required DateTime today,
}) {
  final end = isCurrentMonth
      ? today
      : DateTime(monthStart.year, monthStart.month + 1, 0);
  final label = isCurrentMonth
      ? _t(context, 'This month', '今月')
      : DateFormat.MMM(_localeName(context)).format(monthStart);
  return _TrackTrendBucket(start: monthStart, end: end, label: label);
}

int _trackPlayDeltaBetween({
  required DailyLibrarySnapshot previous,
  required DailyLibrarySnapshot current,
  required String trackId,
}) {
  final previousTrack = _trackSnapshotById(previous, trackId);
  final currentTrack = _trackSnapshotById(current, trackId);
  if (previousTrack == null || currentTrack == null) {
    return 0;
  }
  final delta = currentTrack.playCount - previousTrack.playCount;
  return delta < 0 ? 0 : delta;
}

TrackCounterSnapshot? _trackSnapshotById(
  DailyLibrarySnapshot snapshot,
  String trackId,
) {
  for (final track in snapshot.tracks) {
    if (track.id == trackId) {
      return track;
    }
  }
  return null;
}

class _TrackTrendBucket {
  const _TrackTrendBucket({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;

  bool contains(DateTime date) {
    return !date.isBefore(start) && !date.isAfter(end);
  }
}

class _TrackTrendValue {
  const _TrackTrendValue({required this.label, required this.playDelta});

  final String label;
  final int playDelta;
}

String _compactNumber(int value) {
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}K';
  }
  return NumberFormat.decimalPattern().format(value);
}

String _normalizeLyricsText(String lyrics) {
  return lyrics.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
}

String _trendRangeLabel(BuildContext context, TrendRange range) {
  return switch (range) {
    TrendRange.week => _t(context, '7 days', '7日間', zh: '7天', ko: '7일'),
    TrendRange.month => _t(context, '4 weeks', '4週間', zh: '4周', ko: '4주'),
    TrendRange.year => _t(context, '1 year', '1年間', zh: '1年', ko: '1년'),
  };
}

String _rankingScopeLabel(BuildContext context, RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => _t(context, 'Songs', '曲'),
    RankingScope.artists => _t(context, 'Artists', 'アーティスト'),
    RankingScope.albums => _t(context, 'Albums', 'アルバム'),
    RankingScope.recent => _t(context, 'Recent', '最近'),
  };
}

String _libraryBrowseModeLabel(BuildContext context, _LibraryBrowseMode mode) {
  return switch (mode) {
    _LibraryBrowseMode.songs => _t(context, 'Songs', '曲'),
    _LibraryBrowseMode.artists => _t(context, 'Artists', 'アーティスト'),
    _LibraryBrowseMode.albums => _t(context, 'Albums', 'アルバム'),
    _LibraryBrowseMode.genres => _t(context, 'Genres', 'ジャンル'),
    _LibraryBrowseMode.playlists => _t(context, 'Playlists', 'プレイリスト'),
  };
}

String _librarySortModeLabel(BuildContext context, _LibrarySortMode sort) {
  return switch (sort) {
    _LibrarySortMode.recent => _t(context, 'Recently played', '最近再生'),
    _LibrarySortMode.plays => _t(context, 'Most played', '再生回数順'),
    _LibrarySortMode.skips => _t(context, 'Most skipped', 'スキップ順'),
    _LibrarySortMode.title => _t(context, 'Title', 'タイトル'),
  };
}

String _rankingTitle(BuildContext context, RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => _t(context, 'Top Songs', 'トップ曲'),
    RankingScope.artists => _t(context, 'Top Artists', 'トップアーティスト'),
    RankingScope.albums => _t(context, 'Top Albums', 'トップアルバム'),
    RankingScope.recent => _t(context, 'Recently Played', '最近再生した曲'),
  };
}

String _rankingSubtitle(BuildContext context, RankingScope scope) {
  return switch (scope) {
    RankingScope.tracks => _t(context, 'Ranked by play count', '再生回数順'),
    RankingScope.artists => _t(
      context,
      'Aggregated across each artist',
      'アーティストごとの合計',
    ),
    RankingScope.albums => _t(
      context,
      'Aggregated across each album',
      'アルバムごとの合計',
    ),
    RankingScope.recent => _t(
      context,
      'Sorted by last played date',
      '最後に再生した日時順',
    ),
  };
}

List<NavigationDestination> _navigationDestinations(BuildContext context) {
  return HomeSection.values
      .map(
        (section) => NavigationDestination(
          icon: Icon(_sectionIcon(section)),
          selectedIcon: Icon(_sectionSelectedIcon(section)),
          label: _sectionLabel(context, section),
        ),
      )
      .toList();
}

String _sectionLabel(BuildContext context, HomeSection section) {
  return switch (section) {
    HomeSection.playing => _t(context, 'Playing', '再生中'),
    HomeSection.overview => _t(context, 'Overview', '概要'),
    HomeSection.rankings => _t(context, 'Rankings', 'ランキング'),
    HomeSection.library => _t(context, 'Library', 'ライブラリ'),
    HomeSection.settings => _t(context, 'Settings', '設定'),
  };
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

String _sectionSubtitle(
  BuildContext context,
  HomeSection section,
  bool isDemo,
) {
  final source = isDemo
      ? _t(context, 'demo library', 'デモライブラリ', zh: '演示资料库', ko: '데모 라이브러리')
      : _t(
          context,
          'Music library',
          'ミュージックライブラリ',
          zh: '音乐资料库',
          ko: '음악 라이브러리',
        );
  return switch (section) {
    HomeSection.playing => _t(
      context,
      'Recent playback from the $source',
      '$source の直近再生トラック',
      zh: '$source 的最近播放曲目',
      ko: '$source의 최근 재생 트랙',
    ),
    HomeSection.overview => _t(
      context,
      'Overview of the $source',
      '$source の概要',
      zh: '$source 概览',
      ko: '$source 개요',
    ),
    HomeSection.rankings => _t(
      context,
      'Rankings from the $source',
      '$source のランキング',
      zh: '$source 排行榜',
      ko: '$source 순위',
    ),
    HomeSection.library => _t(
      context,
      'Browse the $source',
      '$source のブラウズ',
      zh: '浏览$source',
      ko: '$source 탐색',
    ),
    HomeSection.settings => _t(
      context,
      'Access and recording settings',
      'アクセスと記録設定',
    ),
  };
}
