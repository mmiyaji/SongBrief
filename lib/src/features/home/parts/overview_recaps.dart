part of '../home_screen.dart';

class _RecapHighlightsPanel extends StatelessWidget {
  const _RecapHighlightsPanel({required this.overview, required this.history});

  final LibraryOverview overview;
  final SnapshotHistory history;

  @override
  Widget build(BuildContext context) {
    final month = _periodRecap(
      history: history,
      period: _RecapPeriod.month,
      now: overview.generatedAt,
    );
    final year = _periodRecap(
      history: history,
      period: _RecapPeriod.year,
      now: overview.generatedAt,
    );
    final milestones = _milestoneForecasts(context, overview, history);
    final burnout = _burnoutSummary(context, overview, history);

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
            icon: Icons.auto_awesome_rounded,
            title: _t(context, 'Recap highlights', 'リキャップ'),
            subtitle: _t(
              context,
              'Monthly and yearly movement from saved snapshots',
              '保存済みスナップショットから月間・年間の動きを表示',
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final recapCards = [
                _PeriodRecapCard(
                  title: _t(context, 'This month', '今月'),
                  recap: month,
                  icon: Icons.calendar_view_month_rounded,
                  fileStem: 'songbrief-monthly-recap',
                ),
                _PeriodRecapCard(
                  title: _t(context, 'This year', '今年'),
                  recap: year,
                  icon: Icons.event_available_rounded,
                  fileStem: 'songbrief-yearly-recap',
                ),
              ];
              final wide = constraints.maxWidth >= 700;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: recapCards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: recapCards[1]),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  recapCards[0],
                  const SizedBox(height: 12),
                  recapCards[1],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final milestoneCard = _MilestoneCountdownCard(
                forecasts: milestones,
              );
              final burnoutCard = _BurnoutSummaryCard(summary: burnout);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: milestoneCard),
                    const SizedBox(width: 12),
                    Expanded(child: burnoutCard),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  milestoneCard,
                  const SizedBox(height: 12),
                  burnoutCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TasteAndCollectionPanel extends ConsumerWidget {
  const _TasteAndCollectionPanel({
    required this.overview,
    required this.history,
  });

  final LibraryOverview overview;
  final SnapshotHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rediscoveryTracks = _rediscoveryTracks(overview);
    final diversity = _diversityScore(overview);
    final albums = _albumCompletionValues(context, overview);

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
            icon: Icons.explore_rounded,
            title: _t(context, 'Taste and collection', '好みとコレクション'),
            subtitle: _t(
              context,
              'Rediscovery, listening range, and album completion',
              '再発見・聴取幅・アルバム制覇率を表示',
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final cards = [
                _RediscoveryCard(
                  tracks: rediscoveryTracks,
                  onPlay: (track) => ref
                      .read(playbackControllerProvider.notifier)
                      .playTrack(track.id),
                ),
                _DiversityScoreCard(score: diversity),
                _AlbumCompletionCard(albums: albums),
              ];

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[2]),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cards[0],
                  const SizedBox(height: 12),
                  cards[1],
                  const SizedBox(height: 12),
                  cards[2],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodRecapCard extends StatefulWidget {
  const _PeriodRecapCard({
    required this.title,
    required this.recap,
    required this.icon,
    required this.fileStem,
  });

  final String title;
  final _PeriodRecap recap;
  final IconData icon;
  final String fileStem;

  @override
  State<_PeriodRecapCard> createState() => _PeriodRecapCardState();
}

class _PeriodRecapCardState extends State<_PeriodRecapCard> {
  final _captureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: _captureKey,
          child: _PeriodRecapCardContent(
            title: widget.title,
            recap: widget.recap,
            icon: widget.icon,
          ),
        ),
        if (widget.recap.hasData) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _saveImage,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_t(context, 'Save PNG', 'PNG保存')),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveImage() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Recap card is not ready.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Could not encode recap image.');
      }
      final savedPath = await FileSaver.instance.saveAs(
        name: widget.fileStem,
        bytes: byteData.buffer.asUint8List(),
        fileExtension: 'png',
        mimeType: MimeType.png,
      );

      if (!mounted) {
        return;
      }
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? _t(context, 'Image save was cancelled.', '画像保存をキャンセルしました。')
                : _t(context, 'Recap image saved.', 'リキャップ画像を保存しました。'),
          ),
        ),
      );
    } on Object {
      if (!mounted) {
        return;
      }
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'Could not save the recap image.',
              'リキャップ画像を保存できませんでした。',
            ),
          ),
        ),
      );
    }
  }
}

class _PeriodRecapCardContent extends StatelessWidget {
  const _PeriodRecapCardContent({
    required this.title,
    required this.recap,
    required this.icon,
  });

  final String title;
  final _PeriodRecap recap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = _numberFormat(context);
    final topTrack = recap.topTrack;
    return _OverviewAnalysisCard(
      icon: icon,
      title: title,
      subtitle: recap.hasData
          ? _t(
              context,
              '${_dayCountLabel(context, recap.observedDays)} observed',
              '${_dayCountLabel(context, recap.observedDays)}分の変化',
            )
          : _t(context, 'Needs two or more snapshots', '2件以上のスナップショットが必要です'),
      child: recap.hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number.format(recap.playDelta),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _t(context, 'new plays', '増加再生'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _RecapLine(
                  icon: Icons.music_note_rounded,
                  label: _t(context, 'Top song', 'トップ曲'),
                  value: topTrack == null
                      ? _t(context, 'None', 'なし')
                      : '${topTrack.title} +${number.format(topTrack.playDelta)}',
                ),
                const SizedBox(height: 8),
                _RecapLine(
                  icon: Icons.person_add_alt_rounded,
                  label: _t(context, 'New artists', '新しく聴いたアーティスト'),
                  value: number.format(recap.newArtistCount),
                ),
              ],
            )
          : _AnalyticsEmptyState(
              label: _t(
                context,
                'Recaps appear after daily snapshots accumulate.',
                '日次スナップショットが貯まるとリキャップを表示します。',
              ),
            ),
    );
  }
}

class _MilestoneCountdownCard extends StatelessWidget {
  const _MilestoneCountdownCard({required this.forecasts});

  final List<_MilestoneForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    return _OverviewAnalysisCard(
      icon: Icons.flag_rounded,
      title: _t(context, 'Milestone countdown', 'マイルストーン予測'),
      subtitle: _t(
        context,
        'Estimated from recent snapshot pace',
        '直近スナップショットのペースから推定',
      ),
      child: forecasts.isEmpty
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'Needs at least two snapshots with movement.',
                '変化のあるスナップショットが2件以上必要です。',
              ),
            )
          : Column(
              children: [
                for (final forecast in forecasts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecapLine(
                      icon: forecast.icon,
                      label: forecast.label,
                      value: forecast.daysLabel,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _BurnoutSummaryCard extends StatelessWidget {
  const _BurnoutSummaryCard({required this.summary});

  final _BurnoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final burnout = summary.burnoutTrack;
    final evergreen = summary.evergreenTrack;
    return _OverviewAnalysisCard(
      icon: Icons.local_fire_department_rounded,
      title: _t(context, 'Burnout curve', '聴き飽き曲線'),
      subtitle: _t(
        context,
        'Detects spikes and steady favorites',
        '急上昇曲と安定して聴く曲を検出',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecapLine(
            icon: Icons.trending_down_rounded,
            label: _t(context, 'Cooling down', '落ち着いた曲'),
            value: burnout?.title ?? _t(context, 'None yet', 'まだありません'),
          ),
          const SizedBox(height: 10),
          _RecapLine(
            icon: Icons.workspace_premium_rounded,
            label: _t(context, 'Hall of fame', '殿堂入り'),
            value: evergreen?.title ?? _t(context, 'None yet', 'まだありません'),
          ),
          const SizedBox(height: 10),
          Text(
            summary.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RediscoveryCard extends StatelessWidget {
  const _RediscoveryCard({required this.tracks, required this.onPlay});

  final List<LibraryTrack> tracks;
  final ValueChanged<LibraryTrack> onPlay;

  @override
  Widget build(BuildContext context) {
    return _OverviewAnalysisCard(
      icon: Icons.history_toggle_off_rounded,
      title: _t(context, 'Rediscovery', '再発見'),
      subtitle: _t(
        context,
        'Favorites not played in 90+ days',
        '90日以上再生していないお気に入り',
      ),
      child: tracks.isEmpty
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'No old favorites need rediscovery.',
                '再発見候補はまだありません。',
              ),
            )
          : Column(
              children: [
                for (final track in tracks.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RediscoveryTrackRow(
                      track: track,
                      onTap: () => onPlay(track),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RediscoveryTrackRow extends StatelessWidget {
  const _RediscoveryTrackRow({required this.track, required this.onTap});

  final LibraryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                  Icons.play_arrow_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _t(
                        context,
                        '${track.artist} - ${_playCountLabel(context, track.playCount)}',
                        '${track.artist} ・ ${_playCountLabel(context, track.playCount)}',
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DiversityScoreCard extends StatelessWidget {
  const _DiversityScoreCard({required this.score});

  final _DiversityScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _OverviewAnalysisCard(
      icon: Icons.travel_explore_rounded,
      title: _t(context, 'Diversity score', '聴取多様性スコア'),
      subtitle: _t(context, 'Focused listener to explorer', '一途リスナーから探検家まで'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.value.round().toString(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('/ 100', style: theme.textTheme.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score.value / 100,
              minHeight: 10,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _t(context, 'Focused', '一途'),
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                _t(context, 'Explorer', '探検家'),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              context,
              'Top 3 artists hold ${score.topThreeShare.toStringAsFixed(0)}% of plays.',
              '上位3アーティストが再生の${score.topThreeShare.toStringAsFixed(0)}%を占めています。',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumCompletionCard extends StatelessWidget {
  const _AlbumCompletionCard({required this.albums});

  final List<_AlbumCompletionValue> albums;

  @override
  Widget build(BuildContext context) {
    return _OverviewAnalysisCard(
      icon: Icons.verified_rounded,
      title: _t(context, 'Album completion', 'アルバム制覇率'),
      subtitle: _t(context, 'Played-track coverage by album', 'アルバム内の再生済み曲の割合'),
      child: albums.isEmpty
          ? _AnalyticsEmptyState(
              label: _t(
                context,
                'Album groups appear after library scan.',
                'ライブラリスキャン後に表示します。',
              ),
            )
          : Column(
              children: [
                for (final album in albums.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AlbumCompletionRow(album: album),
                  ),
              ],
            ),
    );
  }
}

class _AlbumCompletionRow extends StatelessWidget {
  const _AlbumCompletionRow({required this.album});

  final _AlbumCompletionValue album;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = album.ratio * 100;
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percent.round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: album.isComplete
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: album.ratio,
            minHeight: 8,
            backgroundColor: theme.colorScheme.outlineVariant.withValues(
              alpha: 0.34,
            ),
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTrackGroupSheet(
          context,
          title: album.title,
          subtitle: _t(context, 'Album songs', 'アルバムの曲'),
          icon: Icons.album_rounded,
          tracks: album.tracks,
          rankingScope: RankingScope.albums,
          rankingTitle: _albumRankingTitle(album.tracks.first),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

class _RecapLine extends StatelessWidget {
  const _RecapLine({
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
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _RecapPeriod { month, year }

class _PeriodRecap {
  const _PeriodRecap({
    required this.playDelta,
    required this.observedDays,
    required this.newArtistCount,
    this.topTrack,
  });

  final int playDelta;
  final int observedDays;
  final int newArtistCount;
  final _TrackDeltaSummary? topTrack;

  bool get hasData => observedDays > 0 || playDelta > 0 || topTrack != null;
}

class _TrackDeltaSummary {
  const _TrackDeltaSummary({
    required this.id,
    required this.title,
    required this.artist,
    required this.playDelta,
  });

  final String id;
  final String title;
  final String artist;
  final int playDelta;
}

class _MilestoneForecast {
  const _MilestoneForecast({
    required this.icon,
    required this.label,
    required this.daysLabel,
  });

  final IconData icon;
  final String label;
  final String daysLabel;
}

class _BurnoutSummary {
  const _BurnoutSummary({
    required this.description,
    this.burnoutTrack,
    this.evergreenTrack,
  });

  final String description;
  final _TrackDeltaSummary? burnoutTrack;
  final _TrackDeltaSummary? evergreenTrack;
}

class _DiversityScore {
  const _DiversityScore({required this.value, required this.topThreeShare});

  final double value;
  final double topThreeShare;
}

class _AlbumCompletionValue {
  const _AlbumCompletionValue({
    required this.title,
    required this.tracks,
    required this.playedTrackCount,
  });

  final String title;
  final List<LibraryTrack> tracks;
  final int playedTrackCount;

  int get totalTrackCount => tracks.length;
  double get ratio =>
      totalTrackCount == 0 ? 0 : playedTrackCount / totalTrackCount;
  bool get isComplete =>
      totalTrackCount > 0 && playedTrackCount == totalTrackCount;
}

class _TrackDeltaSeries {
  const _TrackDeltaSeries({
    required this.id,
    required this.title,
    required this.artist,
    required this.deltas,
  });

  final String id;
  final String title;
  final String artist;
  final List<int> deltas;

  int get total => deltas.fold<int>(0, (sum, value) => sum + value);
  int get activeIntervals => deltas.where((value) => value > 0).length;
  int get peak => deltas.fold<int>(0, math.max);
  int get recentTotal => deltas
      .skip(math.max(0, deltas.length - 2))
      .fold<int>(0, (sum, value) => sum + value);
  int get earlyTotal => deltas
      .take(math.max(1, deltas.length ~/ 2))
      .fold<int>(0, (sum, value) => sum + value);
}

_PeriodRecap _periodRecap({
  required SnapshotHistory history,
  required _RecapPeriod period,
  required DateTime now,
}) {
  final snapshots = history.snapshots;
  if (snapshots.length < 2) {
    return const _PeriodRecap(playDelta: 0, observedDays: 0, newArtistCount: 0);
  }

  final localNow = now.toLocal();
  final periodStart = switch (period) {
    _RecapPeriod.month => DateTime(localNow.year, localNow.month),
    _RecapPeriod.year => DateTime(localNow.year),
  };
  final current = snapshots.last;
  var baseline = snapshots.first;
  for (final snapshot in snapshots) {
    if (snapshot.capturedAt.isBefore(periodStart)) {
      baseline = snapshot;
    }
  }
  if (baseline.dateKey == current.dateKey && snapshots.length >= 2) {
    baseline = snapshots[snapshots.length - 2];
  }

  final delta = SnapshotDelta.compare(previous: baseline, current: current);
  final topTrack = delta.trackDeltas.isEmpty
      ? null
      : _TrackDeltaSummary(
          id: delta.trackDeltas.first.id,
          title: delta.trackDeltas.first.title,
          artist: delta.trackDeltas.first.artist,
          playDelta: delta.trackDeltas.first.playDelta,
        );
  final previousTracks = {for (final track in baseline.tracks) track.id: track};
  final newArtists = <String>{};
  for (final track in current.tracks) {
    final previous = previousTracks[track.id];
    if ((previous?.playCount ?? 0) == 0 && track.playCount > 0) {
      newArtists.add(track.artist);
    }
  }

  return _PeriodRecap(
    playDelta: delta.totalPlayDelta,
    observedDays: delta.observedDays,
    newArtistCount: newArtists.length,
    topTrack: topTrack,
  );
}

List<LibraryTrack> _rediscoveryTracks(LibraryOverview overview) {
  final now = overview.generatedAt;
  final ranked = overview.tracksByPlayCount;
  final thresholdIndex = ranked.isEmpty
      ? 0
      : math.min(ranked.length - 1, (ranked.length * 0.65).floor());
  final minimumPlays = ranked.isEmpty
      ? 10
      : math.max(10, ranked[thresholdIndex].playCount);
  final tracks =
      overview.tracks
          .where((track) {
            final lastPlayedAt = track.lastPlayedAt;
            return lastPlayedAt != null &&
                now.difference(lastPlayedAt).inDays >= 90 &&
                track.playCount >= minimumPlays;
          })
          .toList(growable: false)
        ..sort((a, b) {
          final byPlays = b.playCount.compareTo(a.playCount);
          if (byPlays != 0) {
            return byPlays;
          }
          return _compareDateDesc(a.lastPlayedAt, b.lastPlayedAt);
        });
  return List.unmodifiable(tracks.take(8));
}

_DiversityScore _diversityScore(LibraryOverview overview) {
  final playsByArtist = <String, int>{};
  for (final track in overview.tracks) {
    playsByArtist[track.artist] =
        (playsByArtist[track.artist] ?? 0) + track.playCount;
  }
  final values = playsByArtist.values.where((value) => value > 0).toList()
    ..sort((a, b) => b.compareTo(a));
  final total = values.fold<int>(0, (sum, value) => sum + value);
  if (values.length <= 1 || total <= 0) {
    return const _DiversityScore(value: 0, topThreeShare: 100);
  }

  var entropy = 0.0;
  for (final value in values) {
    final probability = value / total;
    entropy -= probability * math.log(probability);
  }
  final normalized = entropy / math.log(values.length) * 100;
  final topThree = values.take(3).fold<int>(0, (sum, value) => sum + value);
  return _DiversityScore(
    value: normalized.clamp(0, 100),
    topThreeShare: topThree / total * 100,
  );
}

List<_MilestoneForecast> _milestoneForecasts(
  BuildContext context,
  LibraryOverview overview,
  SnapshotHistory history,
) {
  final pace = _snapshotPace(history);
  if (pace == null || pace.playRatePerDay <= 0) {
    return const [];
  }

  final playTarget = _nextPlayMilestone(overview.totalPlayCount);
  final playDays =
      ((playTarget - overview.totalPlayCount) / pace.playRatePerDay).ceil();
  final listeningTargetSeconds = _nextListeningMilestoneSeconds(
    overview.totalListeningSeconds,
  );
  final listeningDays = pace.listeningSecondsRatePerDay <= 0
      ? null
      : ((listeningTargetSeconds - overview.totalListeningSeconds) /
                pace.listeningSecondsRatePerDay)
            .ceil();

  return [
    _MilestoneForecast(
      icon: Icons.play_arrow_rounded,
      label: _t(
        context,
        '${_numberFormat(context).format(playTarget)} plays',
        '${_numberFormat(context).format(playTarget)}回再生',
      ),
      daysLabel: _daysUntilLabel(context, playDays),
    ),
    if (listeningDays != null)
      _MilestoneForecast(
        icon: Icons.schedule_rounded,
        label: _t(
          context,
          '${_hoursLabel(listeningTargetSeconds)} hours',
          '${_hoursLabel(listeningTargetSeconds)}時間',
        ),
        daysLabel: _daysUntilLabel(context, listeningDays),
      ),
  ];
}

_BurnoutSummary _burnoutSummary(
  BuildContext context,
  LibraryOverview overview,
  SnapshotHistory history,
) {
  final series = _trackDeltaSeries(history);
  if (series.isEmpty) {
    return _BurnoutSummary(
      description: _t(
        context,
        'Burnout detection appears after several snapshots.',
        'スナップショットが増えると聴き飽き傾向を表示します。',
      ),
    );
  }

  final burnoutCandidates =
      series
          .where(
            (track) =>
                track.total >= 3 &&
                track.earlyTotal >= 2 &&
                track.recentTotal == 0 &&
                track.peak >= 2,
          )
          .toList()
        ..sort((a, b) => b.earlyTotal.compareTo(a.earlyTotal));
  final evergreenCandidates =
      series
          .where(
            (track) =>
                track.total >= 3 &&
                track.activeIntervals >=
                    math.max(2, (track.deltas.length / 3).ceil()) &&
                track.recentTotal > 0,
          )
          .toList()
        ..sort((a, b) {
          final byActive = b.activeIntervals.compareTo(a.activeIntervals);
          if (byActive != 0) {
            return byActive;
          }
          return b.total.compareTo(a.total);
        });

  _TrackDeltaSummary? toSummary(_TrackDeltaSeries? value) {
    if (value == null) {
      return null;
    }
    return _TrackDeltaSummary(
      id: value.id,
      title: value.title,
      artist: value.artist,
      playDelta: value.total,
    );
  }

  final burnout = burnoutCandidates.isEmpty ? null : burnoutCandidates.first;
  final evergreen = evergreenCandidates.isEmpty
      ? null
      : evergreenCandidates.first;
  return _BurnoutSummary(
    burnoutTrack: toSummary(burnout),
    evergreenTrack: toSummary(evergreen),
    description: burnout == null
        ? _t(
            context,
            'No sharp drop-off detected in the saved period.',
            '保存期間内で急な聴き飽きは検出されていません。',
          )
        : _t(
            context,
            '${burnout.title} cooled after an early spike.',
            '${burnout.title} は急上昇後に落ち着きました。',
          ),
  );
}

List<_AlbumCompletionValue> _albumCompletionValues(
  BuildContext context,
  LibraryOverview overview,
) {
  final groups = _libraryGroupsForMode(
    context,
    _LibraryBrowseMode.albums,
    overview.tracks,
    _LibrarySortMode.plays,
  );
  final values =
      groups
          .where((group) => group.tracks.isNotEmpty)
          .map(
            (group) => _AlbumCompletionValue(
              title: group.title,
              tracks: group.tracks,
              playedTrackCount: group.tracks
                  .where((track) => track.playCount > 0)
                  .length,
            ),
          )
          .toList()
        ..sort((a, b) {
          final byRatio = b.ratio.compareTo(a.ratio);
          if (byRatio != 0) {
            return byRatio;
          }
          final byTracks = b.totalTrackCount.compareTo(a.totalTrackCount);
          if (byTracks != 0) {
            return byTracks;
          }
          return a.title.compareTo(b.title);
        });
  return List.unmodifiable(values.take(8));
}

_SnapshotPace? _snapshotPace(SnapshotHistory history) {
  final snapshots = history.snapshots;
  if (snapshots.length < 2) {
    return null;
  }
  final recent = snapshots.length > 8
      ? snapshots.sublist(snapshots.length - 8)
      : snapshots;
  final first = recent.first;
  final last = recent.last;
  final days = math.max(
    1,
    _localDateOnly(
      last.capturedAt,
    ).difference(_localDateOnly(first.capturedAt)).inDays,
  );
  final playDelta = _positiveOverviewDelta(
    last.totalPlayCount,
    first.totalPlayCount,
  );
  final listeningDelta = _positiveOverviewDelta(
    last.totalListeningSeconds,
    first.totalListeningSeconds,
  );
  if (playDelta <= 0 && listeningDelta <= 0) {
    return null;
  }
  return _SnapshotPace(
    playRatePerDay: playDelta / days,
    listeningSecondsRatePerDay: listeningDelta / days,
  );
}

class _SnapshotPace {
  const _SnapshotPace({
    required this.playRatePerDay,
    required this.listeningSecondsRatePerDay,
  });

  final double playRatePerDay;
  final double listeningSecondsRatePerDay;
}

int _nextPlayMilestone(int current) {
  if (current < 1000) {
    return 1000;
  }
  if (current < 10000) {
    return ((current ~/ 1000) + 1) * 1000;
  }
  return ((current ~/ 10000) + 1) * 10000;
}

int _nextListeningMilestoneSeconds(int currentSeconds) {
  final currentHours = currentSeconds / 3600;
  final targetHours = currentHours < 100
      ? 100
      : currentHours < 1000
      ? ((currentHours ~/ 100) + 1) * 100
      : ((currentHours ~/ 1000) + 1) * 1000;
  return (targetHours * 3600).round();
}

String _daysUntilLabel(BuildContext context, int days) {
  if (days <= 0) {
    return _t(context, 'soon', 'まもなく');
  }
  return _t(
    context,
    'about ${_dayCountLabel(context, days)}',
    '約${_dayCountLabel(context, days)}',
  );
}

List<_TrackDeltaSeries> _trackDeltaSeries(SnapshotHistory history) {
  final snapshots = history.snapshots;
  if (snapshots.length < 3) {
    return const [];
  }
  final ids = <String, _TrackDeltaSeriesBuilder>{};
  for (var index = 1; index < snapshots.length; index++) {
    final previous = {
      for (final track in snapshots[index - 1].tracks) track.id: track,
    };
    for (final current in snapshots[index].tracks) {
      final previousTrack = previous[current.id];
      final delta = previousTrack == null
          ? 0
          : _positiveOverviewDelta(current.playCount, previousTrack.playCount);
      final builder = ids.putIfAbsent(
        current.id,
        () => _TrackDeltaSeriesBuilder(
          id: current.id,
          title: current.title,
          artist: current.artist,
          length: snapshots.length - 1,
        ),
      );
      builder.deltas[index - 1] = delta;
    }
  }
  final values =
      ids.values
          .map((builder) => builder.toValue())
          .where((value) => value.total > 0)
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));
  return List.unmodifiable(values);
}

class _TrackDeltaSeriesBuilder {
  _TrackDeltaSeriesBuilder({
    required this.id,
    required this.title,
    required this.artist,
    required int length,
  }) : deltas = List<int>.filled(length, 0);

  final String id;
  final String title;
  final String artist;
  final List<int> deltas;

  _TrackDeltaSeries toValue() {
    return _TrackDeltaSeries(
      id: id,
      title: title,
      artist: artist,
      deltas: List.unmodifiable(deltas),
    );
  }
}

int _positiveOverviewDelta(int current, int previous) {
  final delta = current - previous;
  return delta < 0 ? 0 : delta;
}
