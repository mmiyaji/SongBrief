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
