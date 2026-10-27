part of '../home_screen.dart';

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
          label: _t(context, 'Listening records', '聴取記録'),
          value: _dayCountLabel(context, stats.snapshotHistory.snapshotCount),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            context,
            'CSV is suited for spreadsheets. JSON includes listening record summaries for backup or analysis.',
            'CSVは表計算向け、JSONは聴取記録の概要も含む分析・バックアップ向けです。',
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
            'Matching songs are hidden from SongBrief rankings, library, exports, and future records. Your Apple Music library is not changed.',
            '一致する曲をSongBriefのランキング、ライブラリ、エクスポート、今後の聴取記録から除外します。Apple Musicの内容は変更しません。',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final summaryItems = [
                  _FilterSummaryItem(
                    icon: Icons.playlist_remove_rounded,
                    label: _t(context, 'Playlists', 'プレイリスト'),
                    count: filters.excludedPlaylists.length,
                  ),
                  _FilterSummaryItem(
                    icon: Icons.category_outlined,
                    label: _t(context, 'Genres', 'ジャンル'),
                    count: filters.excludedGenres.length,
                  ),
                  _FilterSummaryItem(
                    icon: Icons.manage_search_rounded,
                    label: _t(context, 'Keywords', 'キーワード'),
                    count: filters.excludedKeywords.length,
                  ),
                ];

                final action = OutlinedButton.icon(
                  onPressed: () =>
                      _showLibraryFilterManagerSheet(context, stats: stats),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(_t(context, 'Manage', '管理')),
                );

                if (constraints.maxWidth >= 620) {
                  return Row(
                    children: [
                      for (final item in summaryItems)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: item,
                          ),
                        ),
                      action,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in summaryItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: item,
                      ),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSummaryItem extends StatelessWidget {
  const _FilterSummaryItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: theme.colorScheme.primary, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          _numberFormat(context).format(count),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

Future<void> _showLibraryFilterManagerSheet(
  BuildContext context, {
  required MusicStatsState stats,
}) {
  final size = MediaQuery.sizeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxWidth: math.min(size.width - 32, 760)),
    builder: (context) => _LibraryFilterManagerSheet(stats: stats),
  );
}

class _LibraryFilterManagerSheet extends ConsumerWidget {
  const _LibraryFilterManagerSheet({required this.stats});

  final MusicStatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filters = ref.watch(libraryFilterPreferencesProvider);
    final controller = ref.read(libraryFilterPreferencesProvider.notifier);
    final height = MediaQuery.sizeOf(context).height;
    final overview = stats.overview;

    return SafeArea(
      top: false,
      child: DefaultTabController(
        length: 3,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height * 0.86),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(context, 'Manage hidden items', '非表示項目を管理'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _t(
                              context,
                              'Edit exclusion rules without changing your Apple Music library.',
                              'Apple Musicの内容は変更せず、SongBrief上の除外ルールだけを編集します。',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!filters.isEmpty)
                      TextButton.icon(
                        onPressed: controller.clearAll,
                        icon: const Icon(Icons.clear_all_rounded),
                        label: Text(_t(context, 'Clear all', 'すべて解除')),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.playlist_remove_rounded),
                      text:
                          '${_t(context, 'Playlists', 'プレイリスト')} (${filters.excludedPlaylists.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.category_outlined),
                      text:
                          '${_t(context, 'Genres', 'ジャンル')} (${filters.excludedGenres.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.manage_search_rounded),
                      text:
                          '${_t(context, 'Keywords', 'キーワード')} (${filters.excludedKeywords.length})',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: _RuleGroup(
                          icon: Icons.playlist_remove_rounded,
                          title: _t(context, 'Hidden playlists', '非表示プレイリスト'),
                          description: _t(
                            context,
                            'Hide songs that belong to selected playlists.',
                            '選択したプレイリストに含まれる曲を非表示にします。',
                          ),
                          rules: filters.excludedPlaylists,
                          suggestions: _playlistSuggestions(overview, filters),
                          emptyLabel: _t(
                            context,
                            'No hidden playlists',
                            '非表示プレイリストはありません',
                          ),
                          addLabel: _t(context, 'Add playlist', 'プレイリストを追加'),
                          onAdd: () => _addPlaylistExclusion(context, ref),
                          onAddSuggestion: controller.addExcludedPlaylist,
                          onRemove: controller.removeExcludedPlaylist,
                        ),
                      ),
                      SingleChildScrollView(
                        child: _RuleGroup(
                          icon: Icons.category_outlined,
                          title: _t(context, 'Hidden genres', '非表示ジャンル'),
                          description: _t(
                            context,
                            'Hide songs with selected genre names.',
                            '選択したジャンル名の曲を非表示にします。',
                          ),
                          rules: filters.excludedGenres,
                          suggestions: _genreSuggestions(overview, filters),
                          emptyLabel: _t(
                            context,
                            'No hidden genres',
                            '非表示ジャンルはありません',
                          ),
                          addLabel: _t(context, 'Add genre', 'ジャンルを追加'),
                          onAdd: () => _addGenreExclusion(context, ref),
                          onAddSuggestion: controller.addExcludedGenre,
                          onRemove: controller.removeExcludedGenre,
                        ),
                      ),
                      SingleChildScrollView(
                        child: _RuleGroup(
                          icon: Icons.manage_search_rounded,
                          title: _t(context, 'Hidden keywords', '非表示キーワード'),
                          description: _t(
                            context,
                            'Hide songs whose title, artist, album, genre, or playlist contains a keyword.',
                            '曲名、アーティスト、アルバム、ジャンル、プレイリストにキーワードを含む曲を非表示にします。',
                          ),
                          rules: filters.excludedKeywords,
                          suggestions: const <String>[],
                          emptyLabel: _t(
                            context,
                            'No hidden keywords',
                            '非表示キーワードはありません',
                          ),
                          addLabel: _t(context, 'Add keyword', 'キーワードを追加'),
                          onAdd: () => _addKeywordExclusion(context, ref),
                          onAddSuggestion: controller.addExcludedKeyword,
                          onRemove: controller.removeExcludedKeyword,
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
  return _t(
    context,
    '$count rules',
    '$count件',
    zh: '$count 条规则',
    ko: '$count개 규칙',
  );
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
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _RuleTextDialog(title: title, label: label, helperText: helperText),
  );
  return result?.trim();
}

// Owns its controller so it is disposed only after the exit animation ends.
class _RuleTextDialog extends StatefulWidget {
  const _RuleTextDialog({
    required this.title,
    required this.label,
    required this.helperText,
  });

  final String title;
  final String label;
  final String helperText;

  @override
  State<_RuleTextDialog> createState() => _RuleTextDialogState();
}

class _RuleTextDialogState extends State<_RuleTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t(context, 'Cancel', 'キャンセル')),
        ),
        FilledButton(onPressed: _submit, child: Text(_t(context, 'Add', '追加'))),
      ],
    );
  }
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
          zh: '已保存 ${payload.fileName}。',
          ko: '${payload.fileName} 저장됨.',
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
