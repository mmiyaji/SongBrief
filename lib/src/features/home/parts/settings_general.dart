part of '../home_screen.dart';

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
    final crashReporting = ref.watch(crashReportingControllerProvider);
    final libraryFilters = ref.watch(libraryFilterPreferencesProvider);
    final temporaryDemoLibraryEnabled = ref.watch(temporaryDemoLibraryProvider);
    final appVersion = ref
        .watch(_appVersionLabelProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => _fallbackAppVersionLabel,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!stats.authorizationStatus.canReadLibrary && !overview.isDemo) ...[
          _AuthorizationPanel(status: stats.authorizationStatus),
          const SizedBox(height: 14),
        ],
        _SettingsGroup(
          title: _t(context, 'Music Access', 'ミュージックアクセス'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 10),
              _TemporaryDemoLibrarySetting(
                enabled: temporaryDemoLibraryEnabled,
                stats: stats,
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.update,
                label: _t(context, 'Last record', '最終記録'),
                value: stats.snapshotRecordingEnabled
                    ? _dateTimeFormat(context).format(overview.generatedAt)
                    : _t(context, 'Off', 'オフ'),
              ),
              const SizedBox(height: 12),
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
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'Display & Operation', '表示と操作'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                description: _themeBrightnessDescription(
                  context,
                  selectedBrightness,
                ),
                selected: selectedBrightness,
                options: [
                  for (final brightness in SongBriefThemeBrightness.values)
                    _PreferenceOption(
                      value: brightness,
                      label: _themeBrightnessLabel(context, brightness),
                      description: _themeBrightnessDescription(
                        context,
                        brightness,
                      ),
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
              const SizedBox(height: 18),
              Text(
                _t(context, 'Security', 'セキュリティ'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _AppLockSetting(lockState: appLock),
              const SizedBox(height: 10),
              _CrashReportingSetting(state: crashReporting),
              _AdPrivacySetting(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'Export & Exclusions', 'エクスポートと除外'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExportSetting(stats: stats),
              const SizedBox(height: 16),
              Divider(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                height: 1,
              ),
              const SizedBox(height: 16),
              Text(
                _t(context, 'Display & Exclusions', '表示と除外'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _LibraryFilterSetting(stats: stats, filters: libraryFilters),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'Data Management', 'データ管理'),
          child: _DataManagementSetting(stats: stats),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: _t(context, 'App Info', 'アプリ情報'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                onTap: () => _openExternalUrl(
                  context,
                  _authorUrl,
                  requireConfirmation: true,
                ),
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
          ),
        ),
        const SizedBox(height: 14),
        AdBannerSlot(placement: _t(context, 'Settings', '設定')),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      tint: const Color(0x62FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TemporaryDemoLibrarySetting extends ConsumerWidget {
  const _TemporaryDemoLibrarySetting({
    required this.enabled,
    required this.stats,
  });

  final bool enabled;
  final MusicStatsState stats;

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

    return _SettingsSwitchCard(
      icon: Icons.preview_rounded,
      title: _t(
        context,
        'Temporary demo data',
        '一時的なデモデータ',
        zh: '临时演示数据',
        ko: '임시 데모 데이터',
      ),
      description: description,
      value: enabled,
      surfaceAlpha: 0.22,
      onChanged: (value) async {
        if (value) {
          await _enableTemporaryDemoLibrary(context, ref);
          return;
        }
        ref.read(temporaryDemoLibraryProvider.notifier).setEnabled(false);
        await ref.read(musicStatsControllerProvider.notifier).refreshStats();
      },
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
    this.surfaceAlpha = 0.28,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double surfaceAlpha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: surfaceAlpha,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.22,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
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
