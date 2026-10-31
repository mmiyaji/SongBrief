part of '../home_screen.dart';

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(listeningHistorySyncStateProvider);
    final cloudSyncEnabled = ref.watch(snapshotCloudSyncProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _overviewPanelItems(
        context,
        stats: stats,
        countedOverview: ref.watch(countedListeningOverviewProvider),
        supplementalTracks: ref.watch(countedOutsideTracksProvider),
        syncState: syncState,
        cloudSyncEnabled: cloudSyncEnabled,
      ),
    );
  }
}

class _OverviewSliverSection extends ConsumerWidget {
  const _OverviewSliverSection({
    required this.stats,
    required this.horizontalPadding,
    required this.bottomPadding,
  });

  final MusicStatsState stats;
  final EdgeInsets horizontalPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(listeningHistorySyncStateProvider);
    final cloudSyncEnabled = ref.watch(snapshotCloudSyncProvider);
    final items = _overviewPanelItems(
      context,
      stats: stats,
      countedOverview: ref.watch(countedListeningOverviewProvider),
      supplementalTracks: ref.watch(countedOutsideTracksProvider),
      syncState: syncState,
      cloudSyncEnabled: cloudSyncEnabled,
    );

    return SliverPadding(
      padding: horizontalPadding.copyWith(top: 16, bottom: bottomPadding),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: items[index],
          ),
        ),
      ),
    );
  }
}

List<Widget> _overviewPanelItems(
  BuildContext context, {
  required MusicStatsState stats,
  required LibraryOverview countedOverview,
  required List<LibraryTrack> supplementalTracks,
  required SnapshotSyncState syncState,
  required bool cloudSyncEnabled,
}) {
  final overview = stats.overview;
  final items = <Widget>[];

  void add(Widget child, {double spaceAfter = 14}) {
    items.add(
      Padding(
        padding: EdgeInsets.only(bottom: spaceAfter),
        child: child,
      ),
    );
  }

  if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo) {
    add(_AuthorizationPanel(status: stats.authorizationStatus), spaceAfter: 16);
  }
  if (_labelsDemo(overview)) {
    add(const _DemoBanner(), spaceAfter: 16);
  }
  add(
    _OverviewPanel(
      overview: countedOverview,
      nativeOverview: overview,
      supplementalPlayCount: supplementalTracks.fold<int>(
        0,
        (sum, track) => sum + track.playCount,
      ),
      undatedTrackCount: supplementalTracks
          .where((track) => track.lastPlayedAt == null)
          .length,
    ),
  );
  if (stats.snapshotRecordingEnabled) {
    add(
      _SnapshotStatusPanel(
        history: stats.snapshotHistory,
        overview: overview,
        isDemo: overview.isDemo,
        syncState: syncState,
        cloudSyncEnabled: cloudSyncEnabled,
        onSync: overview.isDemo || syncState.isSyncing
            ? null
            : () =>
                  ProviderScope.containerOf(context)
                      .read(musicStatsControllerProvider.notifier)
                      .syncCloudSnapshots(),
      ),
    );
  }
  add(
    _SummaryGrid(
      overview: countedOverview,
      includesSupplemental: supplementalTracks.isNotEmpty,
    ),
  );
  add(
    _OverviewAnalyticsPanel(
      overview: overview,
      history: stats.snapshotHistory,
      snapshotRecordingEnabled: stats.snapshotRecordingEnabled,
    ),
  );
  if (stats.snapshotRecordingEnabled) {
    add(
      _RecapHighlightsPanel(overview: overview, history: stats.snapshotHistory),
    );
  }
  add(
    _TasteAndCollectionPanel(
      overview: overview,
      history: stats.snapshotHistory,
    ),
  );
  add(
    _OverviewInsightPanel(overview: countedOverview, nativeOverview: overview),
  );
  add(_SmartListsPanel(overview: overview));
  add(
    _OverviewBreakdownPanel(
      overview: countedOverview,
      nativeOverview: overview,
    ),
  );
  add(
    AdBannerSlot(
      key: const ValueKey('overview-ad-slot'),
      placement: _t(context, 'Overview', '概要'),
    ),
    spaceAfter: 0,
  );
  return items;
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.overview,
    required this.nativeOverview,
    this.supplementalPlayCount = 0,
    this.undatedTrackCount = 0,
  });

  final LibraryOverview overview;
  final LibraryOverview nativeOverview;
  final int supplementalPlayCount;
  final int undatedTrackCount;

  @override
  Widget build(BuildContext context) {
    final number = _numberFormat(context);
    final topTrack = overview.topTracks.isEmpty
        ? null
        : overview.topTracks.first;
    final skipRate = nativeOverview.totalPlayCount == 0
        ? 0.0
        : nativeOverview.totalSkipCount / nativeOverview.totalPlayCount * 100;

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
            skips: number.format(nativeOverview.totalSkipCount),
            skipRate: '${skipRate.toStringAsFixed(1)}%',
          );

          if (constraints.maxWidth >= 640) {
            final signalWidth = (constraints.maxWidth * 0.4)
                .clamp(320.0, 360.0)
                .toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _OverviewMain(
                    overview: overview,
                    topTrack: topTrack,
                    supplementalPlayCount: supplementalPlayCount,
                    undatedTrackCount: undatedTrackCount,
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(width: signalWidth, child: signalTiles),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverviewMain(
                overview: overview,
                topTrack: topTrack,
                supplementalPlayCount: supplementalPlayCount,
                undatedTrackCount: undatedTrackCount,
              ),
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
  const _OverviewMain({
    required this.overview,
    required this.topTrack,
    this.supplementalPlayCount = 0,
    this.undatedTrackCount = 0,
  });

  final LibraryOverview overview;
  final int supplementalPlayCount;
  final int undatedTrackCount;
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
            key: const ValueKey('overview-total-play-count'),
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
        if (supplementalPlayCount > 0) ...[
          const SizedBox(height: 8),
          _LifetimeScopeCaption(
            playCount: supplementalPlayCount,
            undatedTrackCount: undatedTrackCount,
          ),
        ],
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
                  _EllipsisTextWithTooltip(
                    entry.title,
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
    final tiles = [
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 220) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < tiles.length; index++) ...[
                tiles[index],
                if (index < tiles.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < tiles.length; index++) ...[
              Expanded(child: tiles[index]),
              if (index < tiles.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
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
    return DecoratedBox(
      key: ValueKey('overview-signal-$label'),
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
            _AdaptiveValueText(
              value: value,
              tooltipMessage: '$label: $value',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            _EllipsisTextWithTooltip(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotStatusPanel extends ConsumerWidget {
  const _SnapshotStatusPanel({
    required this.history,
    required this.overview,
    required this.isDemo,
    required this.syncState,
    required this.cloudSyncEnabled,
    required this.onSync,
  });

  final SnapshotHistory history;
  final LibraryOverview overview;
  final bool isDemo;
  final SnapshotSyncState syncState;
  final bool cloudSyncEnabled;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final number = _numberFormat(context);
    final latest = history.latest;
    final delta = history.latestDelta;

    if (latest == null) {
      final hasDatedHistory =
          !isDemo && ref.watch(countedSupplementalEventsProvider).isNotEmpty;
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
                        _t(context, 'Daily listening records', '日々の聴取記録'),
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
                                'The first listening record will be saved after the next library update.',
                                '次回のライブラリ更新後に最初の聴取記録を保存します。',
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
            if (hasDatedHistory) ...[
              const SizedBox(height: 12),
              _SnapshotTrendChart(history: history),
            ],
          ],
        ),
      );
    }

    final latestDate = _dateTimeFormat(context).format(latest.capturedAt);
    final daysSinceLatest = history.daysSinceLatest(DateTime.now());
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
                      _t(context, 'Daily listening records', '日々の聴取記録'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _t(
                        context,
                        'Last recorded $latestDate - ${_snapshotSourceLabel(context, latest.source)}',
                        '最終記録 $latestDate ・ ${_snapshotSourceLabel(context, latest.source)}',
                        zh: '最后记录 $latestDate · ${_snapshotSourceLabel(context, latest.source)}',
                        ko: '마지막 기록 $latestDate · ${_snapshotSourceLabel(context, latest.source)}',
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
          const SizedBox(height: 12),
          _SnapshotSyncStatusLine(
            state: syncState,
            cloudSyncEnabled: cloudSyncEnabled,
            daysSinceLatest: daysSinceLatest,
            onSync: onSync,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _SnapshotMetric(
                  label: _t(context, 'Window', '期間'),
                  value: delta == null && history.previous != null
                      ? _t(context, 'Unavailable', '利用不可')
                      : observedDays <= 0
                      ? _t(context, 'Baseline', '基準値')
                      : _dayCountLabel(context, observedDays),
                ),
                _SnapshotMetric(
                  label: _t(context, 'New plays', '増加再生'),
                  value: delta == null && history.previous != null
                      ? '—'
                      : number.format(delta?.totalPlayDelta ?? 0),
                ),
                _SnapshotMetric(
                  label: _t(context, 'New skips', '増加スキップ'),
                  value: delta == null && history.previous != null
                      ? '—'
                      : number.format(delta?.totalSkipDelta ?? 0),
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
              _t(context, 'Top gains since previous record', '前回の記録からの増加上位'),
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
                'No play-count changes were found between the last two records.',
                '直近2回の記録では再生回数の変化はありませんでした。',
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

class _SnapshotSyncStatusLine extends StatelessWidget {
  const _SnapshotSyncStatusLine({
    required this.state,
    required this.cloudSyncEnabled,
    required this.daysSinceLatest,
    required this.onSync,
  });

  final SnapshotSyncState state;
  final bool cloudSyncEnabled;
  final int daysSinceLatest;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = state.result;
    final syncLabel = !cloudSyncEnabled
        ? _t(context, 'iCloud sync off', 'iCloud同期オフ')
        : state.isSyncing
        ? _t(context, 'Syncing with iCloud', 'iCloudと同期中')
        : _snapshotSyncResultLabel(context, result?.status);
    final recordLabel = daysSinceLatest <= 0
        ? _t(context, 'Recorded today', '本日記録済み')
        : _t(
            context,
            '$daysSinceLatest days since the last record',
            '最終記録から$daysSinceLatest日',
            zh: '距上次记录 $daysSinceLatest 天',
            ko: '$daysSinceLatest일 전 마지막 기록',
          );
    final warning = daysSinceLatest >= 3;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warning
              ? theme.colorScheme.error.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              warning
                  ? Icons.history_toggle_off_rounded
                  : Icons.cloud_done_outlined,
              size: 20,
              color: warning
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recordLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _syncStatusDetail(context, syncLabel, state.lastAttemptAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (cloudSyncEnabled)
              IconButton(
                tooltip: _t(context, 'Sync now', '今すぐ同期'),
                onPressed: onSync,
                icon: state.isSyncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

String _snapshotSyncResultLabel(
  BuildContext context,
  SnapshotSyncStatus? status,
) {
  return switch (status) {
    SnapshotSyncStatus.synced => _t(
      context,
      'iCloud sync complete',
      'iCloud同期完了',
    ),
    SnapshotSyncStatus.unchanged => _t(
      context,
      'iCloud is up to date',
      'iCloudは最新です',
    ),
    SnapshotSyncStatus.partial => _t(
      context,
      'iCloud sync partially complete',
      'iCloud同期が一部未完了です',
    ),
    SnapshotSyncStatus.noAccount => _t(
      context,
      'Sign in to iCloud to sync',
      '同期するにはiCloudへサインインしてください',
    ),
    SnapshotSyncStatus.unavailable => _t(
      context,
      'iCloud is unavailable',
      'iCloudを利用できません',
    ),
    SnapshotSyncStatus.error => _t(
      context,
      'iCloud sync failed',
      'iCloud同期に失敗しました',
    ),
    SnapshotSyncStatus.disabled => _t(context, 'iCloud sync off', 'iCloud同期オフ'),
    null => _t(context, 'iCloud sync pending', 'iCloud同期を確認中'),
  };
}

String _syncStatusDetail(
  BuildContext context,
  String label,
  DateTime? attemptedAt,
) {
  if (attemptedAt == null) {
    return label;
  }
  return '$label · ${_dateTimeFormat(context).format(attemptedAt)}';
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
            Flexible(
              child: _AdaptiveValueText(
                value: value,
                tooltipMessage: '$label: $value',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotTrendChart extends ConsumerWidget {
  const _SnapshotTrendChart({required this.history});

  final SnapshotHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUpdating =
        ref.watch(statsRefreshInFlightProvider) ||
        ref.watch(snapshotSyncStateProvider.select((s) => s.isSyncing));
    final capturedAt = history.latest?.capturedAt;
    final capturedAtLabel = capturedAt == null
        ? null
        : _dateTimeFormat(context).format(capturedAt);
    final statusLabel = isUpdating
        ? capturedAtLabel == null
              ? _t(context, 'Updating…', '更新中…', zh: '正在更新…', ko: '업데이트 중…')
              : _t(
                  context,
                  'Updating… Showing records as of $capturedAtLabel',
                  '更新中… 前回 $capturedAtLabel 時点の記録を表示',
                  zh: '正在更新… 显示截至 $capturedAtLabel 的记录',
                  ko: '업데이트 중… $capturedAtLabel 기준 기록 표시',
                )
        : capturedAtLabel == null
        ? null
        : _t(
            context,
            'Library records as of $capturedAtLabel',
            '登録曲の記録: $capturedAtLabel 時点',
            zh: '资料库记录截至 $capturedAtLabel',
            ko: '보관함 기록 기준 $capturedAtLabel',
          );
    final number = _numberFormat(context);
    final supplementalEvents = uncoveredListeningEvents(
      history: history,
      events: ref.watch(countedSupplementalEventsProvider),
      dailyOnly: false,
    );
    final values = _snapshotTrendValues(
      context,
      history,
      supplementalEvents: supplementalEvents,
    );
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
                    _t(context, 'Listening record trend', '聴取記録の推移'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isUpdating)
                  SizedBox.square(
                    key: const ValueKey('snapshot-trend-updating'),
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                      semanticsLabel: _t(
                        context,
                        'Updating',
                        '更新中',
                        zh: '正在更新',
                        ko: '업데이트 중',
                      ),
                    ),
                  ),
              ],
            ),
            if (statusLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (supplementalEvents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Text(
                  _t(
                    context,
                    'Includes confirmed history',
                    '確認済み履歴を含む',
                    zh: '包含已确认的播放记录',
                    ko: '확인된 재생 기록 포함',
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              Text(
                _t(
                  context,
                  'Trend bars appear after records from two or more days are available.',
                  '2日分以上の記録がたまると推移を表示します。',
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
                    key: ValueKey('snapshot-trend-${value.label}'),
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
    super.key,
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
  const _SummaryGrid({
    required this.overview,
    this.includesSupplemental = false,
  });

  final LibraryOverview overview;
  final bool includesSupplemental;

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
                subtitle: includesSupplemental
                    ? _t(
                        context,
                        'Included artists',
                        '含まれるアーティスト',
                        zh: '包含的艺人',
                        ko: '포함된 아티스트',
                      )
                    : _t(
                        context,
                        'All artist groups in the current library',
                        '現在のライブラリ内のアーティスト一覧',
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
                subtitle: includesSupplemental
                    ? _t(
                        context,
                        'Included albums',
                        '含まれるアルバム',
                        zh: '包含的专辑',
                        ko: '포함된 앨범',
                      )
                    : _t(
                        context,
                        'All album groups in the current library',
                        '現在のライブラリ内のアルバム一覧',
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
                subtitle: includesSupplemental
                    ? _t(
                        context,
                        'Included songs',
                        '含まれる曲',
                        zh: '包含的歌曲',
                        ko: '포함된 곡',
                      )
                    : _t(context, 'Library tracks', 'ライブラリ内の曲'),
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
          padding: EdgeInsets.zero,
          primary: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 4 ? 1.72 : 1.45,
          ),
          itemBuilder: (context, index) => _SummaryCard(
            key: ValueKey('overview-summary-card-$index'),
            value: values[index],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, super.key});

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
                _AdaptiveValueText(
                  value: value.value,
                  tooltipMessage: '${value.label}: ${value.value}',
                  triggerMode: TooltipTriggerMode.longPress,
                  style: theme.textTheme.titleMedium,
                ),
                _EllipsisTextWithTooltip(
                  value.label,
                  triggerMode: TooltipTriggerMode.longPress,
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

class _LifetimeScopeCaption extends StatelessWidget {
  const _LifetimeScopeCaption({
    required this.playCount,
    required this.undatedTrackCount,
  });
  final int playCount;
  final int undatedTrackCount;
  @override
  Widget build(BuildContext context) {
    final count = _numberFormat(context).format(playCount);
    final undated = _numberFormat(context).format(undatedTrackCount);
    return Text(
      [
        _t(
          context,
          'Includes at least $count plays confirmed from history; listening time is estimated from song duration. Skip metrics use registered library only.',
          '履歴から確認できた再生$count回以上を含みます。再生時間は曲の長さから推定し、スキップ指標は登録済みライブラリのみです。',
          zh: '包含从历史记录确认的至少$count次播放；聆听时长按歌曲时长估算。跳过指标仅统计已登记曲库。',
          ko: '기록에서 확인된 재생을 최소 $count회 포함합니다. 감상 시간은 곡 길이로 추정하며 건너뛰기 지표는 등록된 보관함만 집계합니다.',
        ),
        if (undatedTrackCount > 0)
          _t(
            context,
            '$undated outside-library ${undatedTrackCount == 1 ? 'track has' : 'tracks have'} unknown play times',
            'ライブラリ外の$undated曲は再生日不明',
            zh: '$undated首资料库外歌曲的播放时间未知',
            ko: '보관함 외 곡 $undated곡의 재생 시각을 알 수 없습니다',
          ),
      ].join(' · '),
      key: const ValueKey('supplemental-count-caption'),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _SupplementalCountCaption extends StatelessWidget {
  const _SupplementalCountCaption({
    required this.playCount,
    required this.undatedTrackCount,
  });

  final int playCount;
  final int undatedTrackCount;

  @override
  Widget build(BuildContext context) {
    final count = _numberFormat(context).format(playCount);
    final undated = _numberFormat(context).format(undatedTrackCount);
    return Text(
      [
        _t(
          context,
          'Includes at least $count plays confirmed from history',
          '履歴から確認できた再生$count回以上を含む',
          zh: '包含从历史记录确认的至少$count次播放',
          ko: '기록에서 확인된 재생 최소 $count회 포함',
        ),
        if (playCount > undatedTrackCount)
          _t(
            context,
            'Dated outside-library plays are included in the calendar',
            '日時を確認できたライブラリ外の再生履歴はカレンダーに含みます',
            zh: '日期已确认的资料库外播放记录已计入日历',
            ko: '날짜를 확인한 보관함 외 재생 기록은 캘린더에 포함됩니다',
          ),
        if (undatedTrackCount > 0)
          _t(
            context,
            '$undated outside-library ${undatedTrackCount == 1 ? 'track has' : 'tracks have'} unknown play times',
            'ライブラリ外の$undated曲は再生日不明',
            zh: '$undated首资料库外歌曲的播放时间未知',
            ko: '보관함 외 곡 $undated곡의 재생 시각을 알 수 없습니다',
          ),
      ].join(' · '),
      key: const ValueKey('supplemental-count-caption'),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
