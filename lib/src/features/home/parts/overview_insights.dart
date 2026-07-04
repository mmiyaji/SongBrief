part of '../home_screen.dart';

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
              'Different views of the current library',
              '現在のライブラリを複数の視点で表示',
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
