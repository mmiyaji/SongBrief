part of '../home_screen.dart';

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
        _SnapshotBackgroundRefreshSetting(
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
          label: _labelsDemo(stats.overview)
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
      onChanged: (value) async {
        final saved = await ref
            .read(snapshotRecordingProvider.notifier)
            .setEnabled(value);
        if (!saved) {
          if (context.mounted) {
            _showDataManagementResult(
              context,
              _t(
                context,
                'Could not save the listening-record setting.',
                '聴取記録の設定を保存できませんでした。',
                zh: '无法保存收听记录设置。',
                ko: '청취 기록 설정을 저장할 수 없습니다.',
              ),
            );
          }
          return;
        }
        try {
          await ref
              .read(musicStatsControllerProvider.notifier)
              .rescheduleSnapshotRefresh();
        } on Object {
          if (context.mounted) {
            _showDataManagementResult(
              context,
              _t(
                context,
                'Could not update the background recording request.',
                'バックグラウンド記録の予約を更新できませんでした。',
                zh: '无法更新后台记录请求。',
                ko: '백그라운드 기록 요청을 업데이트할 수 없습니다.',
              ),
            );
          }
        }
      },
    );
  }
}

class _SnapshotBackgroundRefreshSetting extends ConsumerWidget {
  const _SnapshotBackgroundRefreshSetting({required this.recordingEnabled});

  final bool recordingEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final diagnostics = ref.watch(snapshotRefreshDiagnosticsProvider);
    final currentDiagnostics = diagnostics.asData?.value;
    final supported =
        currentDiagnostics != null &&
        currentDiagnostics.availability !=
            SnapshotBackgroundRefreshAvailability.unsupported;
    final detailedLoggingEnabled = ref.watch(snapshotDetailedLoggingProvider);

    return Material(
      key: const ValueKey('snapshot-background-refresh-setting'),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>(
          'snapshot-background-refresh-expansion',
        ),
        initiallyExpanded: false,
        maintainState: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.settings_backup_restore_rounded,
          color: theme.colorScheme.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _t(
                  context,
                  'Background recording',
                  'バックグラウンド記録',
                  zh: '后台记录',
                  ko: '백그라운드 기록',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'iOS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        subtitle: Text(
          _snapshotBackgroundSummaryLabel(
            context,
            diagnostics,
            recordingEnabled: recordingEnabled,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _t(
                  context,
                  'When iOS provides background time, SongBrief updates the daily record without opening the app. The timing is not fixed.',
                  'アプリを開いていない間も、iOSが実行機会を割り当てたときに日々の記録を更新します。実行時刻は一定ではありません。',
                  zh: '无需打开 App；当 iOS 分配后台运行机会时，SongBrief 会更新每日记录。运行时间并不固定。',
                  ko: '앱을 열지 않아도 iOS가 백그라운드 실행 기회를 할당하면 일일 기록을 업데이트합니다. 실행 시각은 일정하지 않습니다.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              diagnostics.when(
                loading: () => _SettingsRow(
                  icon: Icons.schedule_rounded,
                  label: _t(
                    context,
                    'Background status',
                    'バックグラウンド状態',
                    zh: '后台状态',
                    ko: '백그라운드 상태',
                  ),
                  value: _t(
                    context,
                    'Checking...',
                    '確認中...',
                    zh: '正在检查...',
                    ko: '확인 중...',
                  ),
                ),
                error: (_, _) => _SettingsRow(
                  icon: Icons.error_outline_rounded,
                  label: _t(
                    context,
                    'Background status',
                    'バックグラウンド状態',
                    zh: '后台状态',
                    ko: '백그라운드 상태',
                  ),
                  value: _t(
                    context,
                    'Could not load',
                    '取得できません',
                    zh: '无法获取',
                    ko: '불러올 수 없음',
                  ),
                ),
                data: (value) =>
                    _SnapshotRefreshDiagnosticsRows(diagnostics: value),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('snapshot-refresh-status-button'),
                    onPressed: () =>
                        ref.invalidate(snapshotRefreshDiagnosticsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _t(
                        context,
                        'Refresh history',
                        '履歴を更新',
                        zh: '刷新历史',
                        ko: '기록 새로고침',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  key: const PageStorageKey<String>(
                    'snapshot-support-logs-expansion',
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                  childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    _t(
                      context,
                      'Support logs',
                      'サポート用ログ',
                      zh: '支持日志',
                      ko: '지원용 로그',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    _SettingsSwitchCard(
                      icon: Icons.article_outlined,
                      title: _t(
                        context,
                        'Detailed logging',
                        '詳細ログを記録',
                        zh: '记录详细日志',
                        ko: '상세 로그 기록',
                      ),
                      description: _t(
                        context,
                        'For troubleshooting. Song and library metadata are not included.',
                        '問題調査用です。曲やライブラリのメタデータは含めません。',
                        zh: '用于问题排查。不包含歌曲或资料库元数据。',
                        ko: '문제 조사용입니다. 곡 또는 보관함 메타데이터는 포함하지 않습니다.',
                      ),
                      value: detailedLoggingEnabled,
                      surfaceAlpha: 0.18,
                      onChanged: diagnostics.isLoading || !supported
                          ? null
                          : (value) async {
                              final saved = await ref
                                  .read(
                                    snapshotDetailedLoggingProvider.notifier,
                                  )
                                  .setEnabled(value);
                              if (!saved) {
                                if (context.mounted) {
                                  _showDataManagementResult(
                                    context,
                                    _t(
                                      context,
                                      'Could not save the detailed-log setting.',
                                      '詳細ログの設定を保存できませんでした。',
                                      zh: '无法保存详细日志设置。',
                                      ko: '상세 로그 설정을 저장할 수 없습니다.',
                                    ),
                                  );
                                }
                                return;
                              }
                              try {
                                await ref
                                    .read(musicStatsControllerProvider.notifier)
                                    .ensureSnapshotRefreshScheduled();
                              } on Object {
                                ref.invalidate(
                                  snapshotRefreshDiagnosticsProvider,
                                );
                              }
                            },
                    ),
                    if (currentDiagnostics != null)
                      _SettingsRow(
                        icon: Icons.folder_outlined,
                        label: _t(
                          context,
                          'Log storage',
                          'ログ保存量',
                          zh: '日志存储',
                          ko: '로그 저장량',
                        ),
                        value: _snapshotRefreshLogStorageLabel(
                          context,
                          currentDiagnostics,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey(
                          'snapshot-refresh-log-download-button',
                        ),
                        onPressed: currentDiagnostics?.hasLogs == true
                            ? () => _saveSnapshotRefreshLogs(context, ref)
                            : null,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          _t(
                            context,
                            'Save logs',
                            'ログを保存',
                            zh: '保存日志',
                            ko: '로그 저장',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _snapshotBackgroundSummaryLabel(
  BuildContext context,
  AsyncValue<SnapshotRefreshDiagnostics> diagnostics, {
  required bool recordingEnabled,
}) {
  if (!recordingEnabled) {
    return _t(context, 'Off', 'オフ', zh: '已关闭', ko: '꺼짐');
  }
  return diagnostics.when(
    loading: () => _t(
      context,
      'Checking status...',
      '状態を確認中...',
      zh: '正在检查状态...',
      ko: '상태 확인 중...',
    ),
    error: (_, _) => _t(
      context,
      'Status unavailable',
      '状態を取得できません',
      zh: '无法获取状态',
      ko: '상태를 불러올 수 없음',
    ),
    data: (value) {
      if (value.lastSuccessfulCaptureAt == null) {
        return _t(
          context,
          'No background record yet',
          'バックグラウンド記録はまだありません',
          zh: '暂无后台记录',
          ko: '아직 백그라운드 기록 없음',
        );
      }
      final lastSuccess = _dateTimeFormat(
        context,
      ).format(value.lastSuccessfulCaptureAt!.toLocal());
      return _t(
        context,
        'Last recorded $lastSuccess',
        '最終記録 $lastSuccess',
        zh: '上次记录 $lastSuccess',
        ko: '마지막 기록 $lastSuccess',
      );
    },
  );
}

class _SnapshotRefreshDiagnosticsRows extends StatelessWidget {
  const _SnapshotRefreshDiagnosticsRows({required this.diagnostics});

  final SnapshotRefreshDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsRow(
          icon: Icons.phonelink_setup_rounded,
          label: _t(
            context,
            'Background App Refresh',
            'Appのバックグラウンド更新',
            zh: '后台 App 刷新',
            ko: '백그라운드 App 새로고침',
          ),
          value: _snapshotRefreshAvailabilityLabel(
            context,
            diagnostics.availability,
          ),
        ),
        _SettingsRow(
          icon: Icons.check_circle_outline_rounded,
          label: _t(
            context,
            'Last successful record',
            '最後に成功した記録',
            zh: '上次成功记录',
            ko: '마지막 성공 기록',
          ),
          value: _snapshotRefreshDateLabel(
            context,
            diagnostics.lastSuccessfulCaptureAt,
          ),
        ),
        _SnapshotRefreshHistory(diagnostics: diagnostics),
      ],
    );
  }
}

class _SnapshotRefreshHistory extends StatelessWidget {
  const _SnapshotRefreshHistory({required this.diagnostics});

  final SnapshotRefreshDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = diagnostics.recentEvents.reversed.take(6).toList();
    final latestEvent = events.isEmpty ? null : events.first;
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        key: const PageStorageKey<String>('snapshot-refresh-history-expansion'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 6),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.history_rounded, color: theme.colorScheme.primary),
        title: Text(
          _t(context, 'Recent activity', '更新履歴', zh: '更新历史', ko: '업데이트 기록'),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          latestEvent == null
              ? _snapshotRefreshLastEventLabel(context, diagnostics)
              : '${_snapshotRefreshEventLabel(context, latestEvent.event)} / '
                    '${_dateTimeFormat(context).format(latestEvent.at.toLocal())}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: events.isEmpty
            ? [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 8, right: 4),
                  title: Text(
                    _t(
                      context,
                      'No activity yet',
                      '更新履歴はまだありません',
                      zh: '暂无更新历史',
                      ko: '아직 업데이트 기록 없음',
                    ),
                  ),
                ),
              ]
            : events
                  .map(
                    (event) => ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.only(left: 8, right: 4),
                      leading: const Icon(Icons.circle, size: 7),
                      title: Text(
                        _snapshotRefreshEventLabel(context, event.event),
                      ),
                      subtitle: Text(
                        _dateTimeFormat(context).format(event.at.toLocal()),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}

String _snapshotRefreshAvailabilityLabel(
  BuildContext context,
  SnapshotBackgroundRefreshAvailability availability,
) {
  return switch (availability) {
    SnapshotBackgroundRefreshAvailability.available => _t(
      context,
      'Available',
      '利用可能',
      zh: '可用',
      ko: '사용 가능',
    ),
    SnapshotBackgroundRefreshAvailability.denied => _t(
      context,
      'Turned off in Settings',
      '設定でオフ',
      zh: '已在设置中关闭',
      ko: '설정에서 꺼짐',
    ),
    SnapshotBackgroundRefreshAvailability.restricted => _t(
      context,
      'Restricted',
      '制限されています',
      zh: '受限',
      ko: '제한됨',
    ),
    SnapshotBackgroundRefreshAvailability.unsupported => _t(
      context,
      'iOS only',
      'iOSのみ',
      zh: '仅限 iOS',
      ko: 'iOS 전용',
    ),
  };
}

String _snapshotRefreshDateLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return _t(context, 'Not yet', 'まだありません', zh: '暂无', ko: '아직 없음');
  }
  return _dateTimeFormat(context).format(value.toLocal());
}

String _snapshotRefreshLastEventLabel(
  BuildContext context,
  SnapshotRefreshDiagnostics diagnostics,
) {
  final eventLabel = _snapshotRefreshEventLabel(context, diagnostics.lastEvent);
  final at = diagnostics.lastEventAt;
  if (at == null) {
    return eventLabel;
  }
  return '$eventLabel / ${_dateTimeFormat(context).format(at.toLocal())}';
}

String _snapshotRefreshEventLabel(BuildContext context, String? event) {
  return switch (event) {
    'schedule_queued' => _t(context, 'Scheduled', '予約済み', zh: '已安排', ko: '예약됨'),
    'ios_execution_waiting' => _t(
      context,
      'Waiting for iOS to run',
      'iOSの実行待ち',
      zh: '等待 iOS 运行',
      ko: 'iOS 실행 대기 중',
    ),
    'record_updated' => _t(
      context,
      'Daily record updated',
      '日々の記録を更新',
      zh: '每日记录已更新',
      ko: '일일 기록 업데이트됨',
    ),
    'record_failed' => _t(
      context,
      'Could not update record',
      '記録を更新できませんでした',
      zh: '无法更新记录',
      ko: '기록을 업데이트할 수 없음',
    ),
    'record_skipped' => _t(
      context,
      'Record not needed',
      '記録を見送り',
      zh: '无需记录',
      ko: '기록하지 않음',
    ),
    'background_update_interrupted' => _t(
      context,
      'Background update interrupted',
      'バックグラウンド更新を中断',
      zh: '后台更新已中断',
      ko: '백그라운드 업데이트 중단됨',
    ),
    'icloud_sync_completed' => _t(
      context,
      'iCloud sync completed',
      'iCloud同期が完了',
      zh: 'iCloud 同步已完成',
      ko: 'iCloud 동기화 완료됨',
    ),
    'icloud_sync_deferred' => _t(
      context,
      'iCloud sync will retry later',
      'iCloud同期は後で再試行',
      zh: 'iCloud 同步稍后重试',
      ko: 'iCloud 동기화는 나중에 다시 시도',
    ),
    'schedule_cancelled' => _t(
      context,
      'Request cancelled',
      '予約を解除',
      zh: '请求已取消',
      ko: '요청 취소됨',
    ),
    'schedule_kept' => _t(
      context,
      'Request already queued',
      '予約済み',
      zh: '请求已排队',
      ko: '요청 대기 중',
    ),
    'schedule_replaced' => _t(
      context,
      'Previous request updated',
      '以前の予約を更新',
      zh: '已更新之前的请求',
      ko: '이전 요청 업데이트됨',
    ),
    'schedule_submitted' => _t(
      context,
      'Refresh requested',
      '更新を予約',
      zh: '已请求刷新',
      ko: '새로고침 요청됨',
    ),
    'schedule_failed' => _t(
      context,
      'Request failed',
      '予約に失敗',
      zh: '请求失败',
      ko: '요청 실패',
    ),
    'task_started' => _t(
      context,
      'Refresh started',
      '更新を開始',
      zh: '刷新已开始',
      ko: '새로고침 시작됨',
    ),
    'task_expired' => _t(
      context,
      'Time limit reached',
      '実行時間の上限に到達',
      zh: '已达到时间限制',
      ko: '실행 시간 제한 도달',
    ),
    'capture_succeeded' => _t(
      context,
      'Record saved',
      '記録を保存',
      zh: '记录已保存',
      ko: '기록 저장됨',
    ),
    'snapshot_write_failed' => _t(
      context,
      'Could not save record',
      '記録の保存に失敗',
      zh: '无法保存记录',
      ko: '기록 저장 실패',
    ),
    'capture_skipped' => _t(
      context,
      'Record skipped',
      '記録をスキップ',
      zh: '已跳过记录',
      ko: '기록 건너뜀',
    ),
    'cloud_upload_started' => _t(
      context,
      'iCloud upload started',
      'iCloud送信を開始',
      zh: 'iCloud 上传已开始',
      ko: 'iCloud 업로드 시작됨',
    ),
    'cloud_upload_completed' => _t(
      context,
      'iCloud upload completed',
      'iCloud送信が完了',
      zh: 'iCloud 上传已完成',
      ko: 'iCloud 업로드 완료됨',
    ),
    'cloud_upload_skipped' => _t(
      context,
      'iCloud upload skipped',
      'iCloud送信をスキップ',
      zh: '已跳过 iCloud 上传',
      ko: 'iCloud 업로드 건너뜀',
    ),
    'task_completed' => _t(
      context,
      'Background processing ended',
      'バックグラウンド処理を終了',
      zh: '后台处理已结束',
      ko: '백그라운드 처리 종료됨',
    ),
    _ => _t(
      context,
      'No operations yet',
      '動作履歴はまだありません',
      zh: '暂无操作记录',
      ko: '아직 동작 기록 없음',
    ),
  };
}

String _snapshotRefreshLogStorageLabel(
  BuildContext context,
  SnapshotRefreshDiagnostics diagnostics,
) {
  final count = _numberFormat(context).format(diagnostics.logFileCount);
  final size = _byteSizeLabel(diagnostics.logBytes);
  final days = diagnostics.retentionDays;
  return _t(
    context,
    '$count daily files / $size / delete after $days days',
    '$count日分 / $size / $days日後に自動削除',
    zh: '$count 个日文件 / $size / $days 天后自动删除',
    ko: '일별 파일 $count개 / $size / $days일 후 자동 삭제',
  );
}

Future<void> _saveSnapshotRefreshLogs(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final content = await ref
        .read(musicStatsControllerProvider.notifier)
        .exportSnapshotRefreshLogs();
    if (!context.mounted) {
      return;
    }
    if (content == null || content.trim().isEmpty) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'There are no background logs to save.',
              '保存できるバックグラウンドログはありません。',
              zh: '没有可保存的后台日志。',
              ko: '저장할 백그라운드 로그가 없습니다.',
            ),
          ),
        ),
      );
      ref.invalidate(snapshotRefreshDiagnosticsProvider);
      return;
    }
    final timestamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final fileName = 'songbrief-background-log-$timestamp';
    final saved = await _shareFileForSaving(
      context,
      bytes: Uint8List.fromList(utf8.encode(content)),
      fileName: '$fileName.jsonl',
      mimeType: 'text/plain',
    );
    if (!context.mounted) {
      return;
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _t(
                  context,
                  'Saved $fileName.jsonl.',
                  '$fileName.jsonl を保存しました。',
                  zh: '已保存 $fileName.jsonl。',
                  ko: '$fileName.jsonl 저장됨.',
                )
              : _t(
                  context,
                  'Log save was cancelled.',
                  'ログの保存をキャンセルしました。',
                  zh: '已取消保存日志。',
                  ko: '로그 저장을 취소했습니다.',
                ),
        ),
      ),
    );
  } on Object {
    if (!context.mounted) {
      return;
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          _t(
            context,
            'Could not save the background logs.',
            'バックグラウンドログを保存できませんでした。',
            zh: '无法保存后台日志。',
            ko: '백그라운드 로그를 저장할 수 없습니다.',
          ),
        ),
      ),
    );
  }
}
