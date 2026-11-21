part of '../home_screen.dart';

const _appStoreReviewUrl =
    'https://apps.apple.com/app/id6785969770?action=write-review';

enum _SettingsCategory {
  appearance(Icons.palette_outlined),
  history(Icons.history_rounded),
  library(Icons.library_music_outlined),
  export(Icons.download_outlined),
  privacy(Icons.shield_outlined),
  about(Icons.info_outline);

  const _SettingsCategory(this.icon);

  final IconData icon;

  String label(BuildContext context) => switch (this) {
    appearance => _t(
      context,
      'Appearance & Language',
      '外観と言語',
      zh: '外观与语言',
      ko: '외관 및 언어',
    ),
    history => _t(
      context,
      'Listening Records',
      '聴取記録',
      zh: '聆听记录',
      ko: '청취 기록',
    ),
    library => _t(
      context,
      'Music Library',
      'ミュージックライブラリ',
      zh: '音乐资料库',
      ko: '음악 보관함',
    ),
    export => _t(
      context,
      'Export & Cache',
      '書き出しとキャッシュ',
      zh: '导出与缓存',
      ko: '내보내기 및 캐시',
    ),
    privacy => _t(
      context,
      'Privacy & Security',
      'プライバシーとセキュリティ',
      zh: '隐私与安全',
      ko: '개인정보 보호 및 보안',
    ),
    about => _t(context, 'App Info', 'アプリ情報', zh: '应用信息', ko: '앱 정보'),
  };
}

class _SettingsSection extends ConsumerStatefulWidget {
  const _SettingsSection({required this.stats, this.historyPending = false});

  final MusicStatsState stats;
  final bool historyPending;

  @override
  ConsumerState<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<_SettingsSection> {
  static const _categoryStorage = ValueKey('settings-active-category');
  _SettingsCategory? _selected;
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    _selected = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _categoryStorage) as _SettingsCategory?;
  }

  void _select(_SettingsCategory? category) {
    if (_selected == category) return;
    PageStorage.maybeOf(context)
        ?.writeState(context, category, identifier: _categoryStorage);
    Scrollable.maybeOf(context)?.position.jumpTo(0);
    setState(() => _selected = category);
  }

  String _summary(BuildContext context, _SettingsCategory category) {
    final stats = widget.stats;
    final on = _t(context, 'On', 'オン', zh: '开启', ko: '켜짐');
    final off = _t(context, 'Off', 'オフ', zh: '关闭', ko: '꺼짐');
    switch (category) {
      case _SettingsCategory.appearance:
        return '${_themeBrightnessLabel(context, ref.watch(themeBrightnessProvider))} · '
            '${_languageLabel(context, ref.watch(appLanguageProvider))}';
      case _SettingsCategory.history:
        final recording = ref.watch(snapshotRecordingProvider) ? on : off;
        final cloud = ref.watch(snapshotCloudSyncProvider) ? on : off;
        return _t(
          context,
          'Recording $recording · iCloud $cloud',
          '記録$recording・iCloud $cloud',
          zh: '记录$recording · iCloud $cloud',
          ko: '기록 $recording · iCloud $cloud',
        );
      case _SettingsCategory.library:
        final rules = ref.watch(libraryFilterPreferencesProvider).ruleCount;
        final access = _labelsDemo(stats.overview)
            ? _t(context, 'Demo mode', 'デモモード')
            : _authorizationLabel(
                context,
                _displayedAuthorizationStatus(stats),
              );
        final exclusions = _filterRuleCountLabel(context, rules);
        return _t(
          context,
          '$access · Exclusions: $exclusions',
          '$access・除外$exclusions',
          zh: '$access · 排除$exclusions',
          ko: '$access · 제외 $exclusions',
        );
      case _SettingsCategory.export:
        ref.watch(_cacheUsageRevisionProvider);
        final size = _byteSizeLabel(_currentCacheUsage().bytes);
        return _t(
          context,
          'CSV · JSON · Cache $size',
          'CSV・JSON・キャッシュ $size',
          zh: 'CSV · JSON · 缓存 $size',
          ko: 'CSV · JSON · 캐시 $size',
        );
      case _SettingsCategory.privacy:
        final enabled = ref.watch(
          appLockControllerProvider.select((state) => state.value?.enabled),
        );
        if (enabled == null) {
          return _t(context, 'App lock', 'アプリロック', zh: '应用锁', ko: '앱 잠금');
        }
        final lock = enabled ? on : off;
        return _t(
          context,
          'App lock $lock',
          'アプリロック $lock',
          zh: '应用锁 $lock',
          ko: '앱 잠금 $lock',
        );
      case _SettingsCategory.about:
        return _t(
          context,
          'Version · Rate the app',
          'バージョン・アプリを評価',
          zh: '版本 · 为应用评分',
          ko: '버전 · 앱 평가',
        );
    }
  }

  Widget _buildIndex(BuildContext context, _SettingsCategory? active) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          for (final category in _SettingsCategory.values) ...[
            ListTile(
              key: ValueKey('settings-category-${category.name}'),
              leading: Icon(
                category.icon,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                category.label(context),
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(_summary(context, category)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              selected: active == category,
              selectedTileColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: theme.colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              onTap: () => _select(category),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    _SettingsCategory category, {
    required bool split,
  }) {
    final theme = Theme.of(context);
    final stats = widget.stats;
    final historyPending = widget.historyPending;
    return Column(
      key: ValueKey(category),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!split)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('settings-category-back'),
              onPressed: () => _select(null),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                _t(
                  context,
                  'Back to Settings',
                  '設定に戻る',
                  zh: '返回设置',
                  ko: '설정으로 돌아가기',
                ),
              ),
            ),
          ),
        Semantics(
          header: true,
          child: Text(
            category.label(context),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 14),
        switch (category) {
          _SettingsCategory.appearance => _buildAppearance(),
          _SettingsCategory.history => _ListeningRecordsSetting(
            stats: stats,
            historyPending: historyPending,
          ),
          _SettingsCategory.library => _buildLibrary(),
          _SettingsCategory.export => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsGroup(
                title: _t(
                  context,
                  'Export data',
                  'データの書き出し',
                  zh: '导出数据',
                  ko: '데이터 내보내기',
                ),
                child: _ExportSetting(
                  stats: stats,
                  historyPending: historyPending,
                ),
              ),
              const SizedBox(height: 24),
              _SettingsGroup(
                title: _t(
                  context,
                  'Device storage',
                  '端末のストレージ',
                  zh: '设备存储空间',
                  ko: '기기 저장 공간',
                ),
                child: const _CacheSetting(),
              ),
            ],
          ),
          _SettingsCategory.privacy => _buildPrivacy(),
          _SettingsCategory.about => _buildAbout(),
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final showAccess =
        !stats.authorizationStatus.canReadLibrary && !stats.overview.isDemo;
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final split =
            constraints.maxWidth >= 640 &&
            MediaQuery.sizeOf(context).width >= 720;
        final selected = _selected;
        final active = selected ?? _SettingsCategory.appearance;
        return PopScope<void>(
          canPop: split || selected == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !split && _selected != null) _select(null);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showAccess &&
                  (split ||
                      selected == null ||
                      selected == _SettingsCategory.library)) ...[
                _AuthorizationPanel(status: stats.authorizationStatus),
                const SizedBox(height: 14),
              ],
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 12),
              if (split)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth * 0.36).clamp(218.0, 285.0),
                      child: _buildIndex(context, active),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: BorderDirectional(
                            start: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 20),
                          child: _buildDetail(context, active, split: true),
                        ),
                      ),
                    ),
                  ],
                )
              else if (selected == null)
                _buildIndex(context, null)
              else
                _buildDetail(context, selected, split: false),
              const SizedBox(height: 14),
              AdBannerSlot(placement: _t(context, 'Settings', '設定')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibrary() {
    final stats = widget.stats;
    final demo = _labelsDemo(stats.overview);
    final lastRefresh = stats.lastDataRefreshAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsGroup(
          title: _t(
            context,
            'Music Access',
            'ミュージックアクセス',
            zh: '访问与更新',
            ko: '접근 및 업데이트',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: _t(context, 'Authorization', '認証状態'),
                value: demo
                    ? _t(context, 'Demo mode', 'デモモード')
                    : _authorizationLabel(
                        context,
                        _displayedAuthorizationStatus(stats),
                      ),
              ),
              _SettingsRow(
                icon: Icons.storage,
                label: _t(context, 'Data source', 'データソース'),
                value: demo
                    ? _t(context, 'Sample library', 'サンプルライブラリ')
                    : _t(context, 'iOS Music library', 'iOSミュージックライブラリ'),
              ),
              _SettingsRow(
                icon: Icons.update,
                label: _t(
                  context,
                  'Last library update',
                  'ライブラリの最終更新',
                  zh: '资料库上次更新',
                  ko: '보관함 마지막 업데이트',
                ),
                value: lastRefresh == null
                    ? _t(context, 'Unavailable', '不明', zh: '未知', ko: '알 수 없음')
                    : _dateTimeFormat(context).format(lastRefresh),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: widget.historyPending
                      ? null
                      : () => ref
                            .read(musicStatsControllerProvider.notifier)
                            .refreshStats(),
                  icon: const Icon(Icons.refresh),
                  label: Text(_t(context, 'Refresh', '更新')),
                ),
              ),
              if (!screenshotModeEnabled) ...[
                const SizedBox(height: 10),
                _TemporaryDemoLibrarySetting(
                  enabled: ref.watch(temporaryDemoLibraryProvider),
                  stats: stats,
                  historyPending: widget.historyPending,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          title: _t(
            context,
            'What to include',
            '集計対象',
            zh: '统计范围',
            ko: '집계 대상',
          ),
          child: _LibraryFilterSetting(
            stats: stats,
            filters: ref.watch(libraryFilterPreferencesProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearance() {
    final selectedTheme = ref.watch(themeStyleProvider);
    final selectedBrightness = ref.watch(themeBrightnessProvider);
    final selectedLanguage = ref.watch(appLanguageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreferenceSelectorTile<SongBriefThemeStyle>(
          icon: Icons.palette_outlined,
          label: _t(context, 'Theme', 'テーマ'),
          valueLabel: _themeStyleLabel(context, selectedTheme),
          valueLeading: _ThemeStyleSwatch(style: selectedTheme),
          description: _themeStyleDescription(context, selectedTheme),
          selected: selectedTheme,
          options: [
            for (final style in SongBriefThemeStyle.values)
              _PreferenceOption(
                value: style,
                label: _themeStyleLabel(context, style),
                description: _themeStyleDescription(context, style),
                leading: _ThemeStyleSwatch(style: style),
              ),
          ],
          onChanged: (style) {
            ref.read(themeStyleProvider.notifier).setStyle(style);
          },
        ),
        const SizedBox(height: 10),
        _PreferenceSelectorTile<SongBriefThemeBrightness>(
          icon: Icons.contrast_rounded,
          label: _t(context, 'Appearance', '外観'),
          valueLabel: _themeBrightnessLabel(context, selectedBrightness),
          description: _themeBrightnessDescription(context, selectedBrightness),
          selected: selectedBrightness,
          options: [
            for (final brightness in SongBriefThemeBrightness.values)
              _PreferenceOption(
                value: brightness,
                label: _themeBrightnessLabel(context, brightness),
                description: _themeBrightnessDescription(context, brightness),
              ),
          ],
          onChanged: (brightness) {
            ref
                .read(themeBrightnessProvider.notifier)
                .setBrightness(brightness);
          },
        ),
        const SizedBox(height: 10),
        _PreferenceSelectorTile<AppLanguage>(
          icon: Icons.language_rounded,
          label: _t(context, 'Language', '言語'),
          valueLabel: _languageLabel(context, selectedLanguage),
          description: _languageDescription(context, selectedLanguage),
          selected: selectedLanguage,
          options: [
            for (final language in AppLanguage.values)
              _PreferenceOption(
                value: language,
                label: _languageLabel(context, language),
                description: _languageDescription(context, language),
              ),
          ],
          onChanged: (language) {
            ref.read(appLanguageProvider.notifier).setLanguage(language);
          },
        ),
      ],
    );
  }

  Widget _buildPrivacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsGroup(
          title: _t(
            context,
            'Access protection',
            'アクセスの保護',
            zh: '访问保护',
            ko: '접근 보호',
          ),
          child: _AppLockSetting(
            lockState: ref.watch(appLockControllerProvider),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          title: _t(
            context,
            'Data sharing',
            'データの共有',
            zh: '数据共享',
            ko: '데이터 공유',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CrashReportingSetting(
                state: ref.watch(crashReportingControllerProvider),
              ),
              _AdPrivacySetting(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAbout() {
    final theme = Theme.of(context);
    final appVersion = ref
        .watch(_appVersionLabelProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => _fallbackAppVersionLabel,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          icon: Icons.info_outline,
          label: _t(context, 'Application', 'アプリケーション'),
          value: 'SongBrief',
          onTap: () => _openExternalUrl(
            context,
            _officialWebsiteUrl,
            requireConfirmation: true,
          ),
        ),
        _SettingsRow(
          icon: Icons.sell_outlined,
          label: _t(context, 'Version', 'バージョン'),
          value: appVersion,
        ),
        _SettingsRow(
          icon: Icons.person_outline_rounded,
          label: _t(context, 'Author', '作者', zh: '作者', ko: '작성자'),
          value: 'mmiyaji',
          onTap: () =>
              _openExternalUrl(context, _authorUrl, requireConfirmation: true),
        ),
        _SettingsRow(
          icon: Icons.privacy_tip_outlined,
          label: _t(context, 'Privacy Policy', 'プライバシーポリシー'),
          value: _t(context, 'Open', '開く'),
          onTap: () => _openExternalUrl(
            context,
            _privacyPolicyUrl,
            requireConfirmation: true,
          ),
        ),
        _SettingsRow(
          icon: Icons.gavel_outlined,
          label: _t(context, 'Terms of Use', '利用規約'),
          value: _t(context, 'Open', '開く'),
          onTap: () => _openExternalUrl(
            context,
            _termsOfUseUrl,
            requireConfirmation: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openExternalUrl(context, _appStoreReviewUrl),
              icon: const Icon(Icons.star_outline_rounded),
              label: Text(
                _t(
                  context,
                  'Rate on the App Store',
                  'App Store で評価する',
                  zh: '在 App Store 评分',
                  ko: 'App Store에서 평가하기',
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'SongBrief',
                  applicationVersion: appVersion,
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
      ],
    );
  }
}

class _SupplementalHistorySetting extends ConsumerStatefulWidget {
  const _SupplementalHistorySetting({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_SupplementalHistorySetting> createState() =>
      _SupplementalHistorySettingState();
}

class _SupplementalHistorySettingState
    extends ConsumerState<_SupplementalHistorySetting> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return _SettingsSwitchCard(
      icon: Icons.history_rounded,
      title: _t(
        context,
        'Include plays outside your library (recommended)',
        'ライブラリ外の再生履歴も含める（推奨）',
        zh: '也包含资料库外的播放记录（推荐）',
        ko: '보관함 외 재생 기록도 포함(권장)',
      ),
      description: _t(
        context,
        'Show confirmed plays outside your library in totals and Calendar. Only confirmed plays are counted. When off, saved history stays available, collection continues, and playback controls keep working.',
        'ライブラリに追加していない曲も、確認できた再生履歴を集計やカレンダーに表示します。再生回数は確認できた分だけを数えます。オフにしても保存済み履歴は残り、収集と再生操作は続きます。',
        zh: '汇总和日历也会显示未添加到资料库的歌曲中已确认的播放记录。播放次数只统计已确认的部分。关闭后，已保存的记录仍可查看，收集和播放控制也会继续。',
        ko: '보관함에 추가하지 않은 곡도 확인된 재생 기록을 합계와 캘린더에 표시합니다. 재생 횟수는 확인된 만큼만 계산합니다. 끄면 저장된 기록은 계속 볼 수 있고 수집과 재생 제어도 계속됩니다.',
      ),
      value: widget.enabled,
      onChanged: _saving ? null : _setEnabled,
    );
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _saving = true);
    final saved = await ref
        .read(supplementalHistoryIncludedProvider.notifier)
        .setEnabled(enabled);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'Could not save this setting.',
              '設定を保存できませんでした。',
              zh: '无法保存此设置。',
              ko: '설정을 저장하지 못했습니다.',
            ),
          ),
        ),
      );
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _TemporaryDemoLibrarySetting extends ConsumerWidget {
  const _TemporaryDemoLibrarySetting({
    required this.enabled,
    required this.stats,
    required this.historyPending,
  });

  final bool enabled;
  final MusicStatsState stats;
  final bool historyPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realLibraryAvailable =
        stats.authorizationStatus.canReadLibrary && stats.overview.hasTracks;
    final active = enabled && stats.overview.isDemo;
    final description = active
        ? _t(
            context,
            'Temporary demo data is visible. It is not saved or synced.',
            '一時的なデモデータを表示中です。保存や同期の対象にはなりません。',
            zh: '正在显示临时演示数据。它不会被保存或同步。',
            ko: '임시 데모 데이터를 표시 중입니다. 저장되거나 동기화되지 않습니다.',
          )
        : realLibraryAvailable
        ? _t(
            context,
            'Your Music library is available, so real data is shown first.',
            'ミュージックライブラリを利用できるため、実データを優先して表示しています。',
            zh: '可以使用你的音乐资料库，因此优先显示真实数据。',
            ko: '음악 보관함을 사용할 수 있으므로 실제 데이터를 우선 표시합니다.',
          )
        : _t(
            context,
            'When Music access is unavailable or no songs are found, show sample data so you can try the app.',
            'ミュージックにアクセスできない場合や曲が見つからない場合に、アプリを試せるサンプルデータを表示します。',
            zh: '当无法访问音乐或找不到歌曲时，显示示例数据以便试用应用。',
            ko: '음악 접근이 불가능하거나 곡을 찾을 수 없을 때 앱을 시험해 볼 수 있는 샘플 데이터를 표시합니다.',
          );

    final title = _t(
      context,
      'Temporary demo data',
      '一時的なデモデータ',
      zh: '临时演示数据',
      ko: '임시 데모 데이터',
    );
    final switchCard = _SettingsSwitchCard(
      icon: Icons.preview_rounded,
      title: title,
      description: description,
      value: enabled,
      onChanged: historyPending
          ? null
          : (value) async {
              if (value) {
                await _enableTemporaryDemoLibrary(context, ref);
                return;
              }
              ref.read(temporaryDemoLibraryProvider.notifier).setEnabled(false);
              await ref
                  .read(musicStatsControllerProvider.notifier)
                  .refreshStats();
            },
    );
    if (enabled || !realLibraryAvailable) {
      return switchCard;
    }

    // Most users have a real library, so keep the demo switch out of the way.
    final theme = Theme.of(context);
    return ExpansionTile(
      key: const PageStorageKey<String>('temporary-demo-library-expansion'),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      dense: true,
      leading: Icon(
        Icons.preview_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      children: [switchCard],
    );
  }
}

class _SettingsSwitchCard extends StatelessWidget {
  const _SettingsSwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          secondary: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceOption<T> {
  const _PreferenceOption({
    required this.value,
    required this.label,
    required this.description,
    this.leading,
  });

  final T value;
  final String label;
  final String description;
  final Widget? leading;
}

class _PreferenceSelectorTile<T> extends StatelessWidget {
  const _PreferenceSelectorTile({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.description,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.valueLeading,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final String description;
  final T selected;
  final List<_PreferenceOption<T>> options;
  final ValueChanged<T> onChanged;
  final Widget? valueLeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showPreferenceSheet<T>(
          context: context,
          title: label,
          selected: selected,
          options: options,
          onChanged: onChanged,
        ),
        child: Ink(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final valueWidth = math.min(
                        260.0,
                        math.max(156.0, constraints.maxWidth * 0.38),
                      );
                      final labelColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                      final value = _PreferenceSelectorValue(
                        leading: valueLeading,
                        label: valueLabel,
                      );

                      if (constraints.maxWidth < 430) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            labelColumn,
                            const SizedBox(height: 8),
                            value,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: labelColumn),
                          const SizedBox(width: 16),
                          SizedBox(width: valueWidth, child: value),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSelectorValue extends StatelessWidget {
  const _PreferenceSelectorValue({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showPreferenceSheet<T>({
  required BuildContext context,
  required String title,
  required T selected,
  required List<_PreferenceOption<T>> options,
  required ValueChanged<T> onChanged,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height;
      final maxSheetHeight = height * 0.86;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxSheetHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option.value == selected;
                      return _PreferenceOptionRow<T>(
                        option: option,
                        selected: isSelected,
                        onTap: () {
                          onChanged(option.value);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PreferenceOptionRow<T> extends StatelessWidget {
  const _PreferenceOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PreferenceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: option.label,
      hint: option.description,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.22,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.38)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (option.leading != null) ...[
                              option.leading!,
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                option.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          option.description,
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
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
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

class _ThemeStyleSwatch extends StatelessWidget {
  const _ThemeStyleSwatch({required this.style});

  final SongBriefThemeStyle style;

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final colors = _themeStyleSwatchColors(style);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: currentTheme.colorScheme.outlineVariant.withValues(
            alpha: 0.58,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 44,
          height: 20,
          child: CustomPaint(painter: _ThemeStyleSwatchPainter(colors)),
        ),
      ),
    );
  }
}

List<Color> _themeStyleSwatchColors(SongBriefThemeStyle style) {
  return switch (style) {
    SongBriefThemeStyle.prism => const [
      Color(0xFF4DECC7),
      Color(0xFFE0FF67),
      Color(0xFF7B8CFF),
    ],
    SongBriefThemeStyle.flux => const [
      Color(0xFF55DDF7),
      Color(0xFF7EC8FF),
      Color(0xFF8EE7B9),
    ],
    SongBriefThemeStyle.ember => const [
      Color(0xFFFF3D78),
      Color(0xFFFF9B52),
      Color(0xFF6FE5C4),
    ],
    SongBriefThemeStyle.mono => const [
      Color(0xFFEDEDED),
      Color(0xFFA6A6A6),
      Color(0xFF303030),
    ],
    SongBriefThemeStyle.aurora => const [
      Color(0xFFFF8BD8),
      Color(0xFF75D8FF),
      Color(0xFFFFC15A),
    ],
    SongBriefThemeStyle.grove => const [
      Color(0xFFB6EC67),
      Color(0xFF65E6D2),
      Color(0xFFFF9A9C),
    ],
    SongBriefThemeStyle.pulse => const [
      Color(0xFF8CB7FF),
      Color(0xFF60E7D6),
      Color(0xFFFF9AC2),
    ],
    SongBriefThemeStyle.muse => const [
      Color(0xFFDDA8FF),
      Color(0xFF71E4D8),
      Color(0xFFFFB568),
    ],
  };
}

class _ThemeStyleSwatchPainter extends CustomPainter {
  const _ThemeStyleSwatchPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final segmentWidth = size.width / colors.length;
    for (var index = 0; index < colors.length; index += 1) {
      paint.color = colors[index];
      final left = index * segmentWidth;
      final right = index == colors.length - 1
          ? size.width
          : (index + 1) * segmentWidth;
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeStyleSwatchPainter oldDelegate) {
    if (oldDelegate.colors.length != colors.length) {
      return true;
    }
    for (var index = 0; index < colors.length; index += 1) {
      if (oldDelegate.colors[index] != colors[index]) {
        return true;
      }
    }
    return false;
  }
}
