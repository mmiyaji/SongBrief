part of '../home_screen.dart';

class _AppLockSetting extends ConsumerWidget {
  const _AppLockSetting({required this.lockState});

  final AsyncValue<AppLockState> lockState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return lockState.when(
      loading: () => _SettingsRow(
        icon: Icons.lock_outline,
        label: _t(context, 'App Lock', 'アプリロック'),
        value: _t(context, 'Checking...', '確認中...'),
      ),
      error: (_, _) => _SettingsRow(
        icon: Icons.lock_outline,
        label: _t(context, 'App Lock', 'アプリロック'),
        value: _t(context, 'Unavailable', '利用不可'),
      ),
      data: (state) {
        final enabled = state.enabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                _t(context, 'App Lock', 'アプリロック'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                state.supported
                    ? _t(
                        context,
                        'Require device authentication when opening SongBrief.',
                        'SongBriefを開くときに端末認証を要求します。',
                      )
                    : _t(
                        context,
                        'Available on devices with Face ID, Touch ID, or passcode authentication.',
                        'Face ID、Touch ID、またはパスコード認証に対応した端末で利用できます。',
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: enabled,
              onChanged: !state.supported || state.authenticating
                  ? null
                  : (value) {
                      ref
                          .read(appLockControllerProvider.notifier)
                          .setEnabled(
                            value,
                            localizedReason: _t(
                              context,
                              'Enable SongBrief app lock.',
                              'SongBriefのアプリロックを有効にします。',
                            ),
                          );
                    },
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                state.errorMessage == 'device_authentication_unavailable'
                    ? _t(
                        context,
                        'Device authentication is not available.',
                        '端末認証を利用できません。',
                      )
                    : _t(
                        context,
                        'Authentication was not completed.',
                        '認証が完了しませんでした。',
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (enabled) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: state.authenticating
                      ? null
                      : () {
                          ref.read(appLockControllerProvider.notifier).lock();
                        },
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(_t(context, 'Lock now', '今すぐロック')),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CrashReportingSetting extends ConsumerWidget {
  const _CrashReportingSetting({required this.state});

  final CrashReportingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = state.enabled;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        Icons.bug_report_outlined,
        color: state.available
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        _t(context, 'Crash reports', 'クラッシュレポート', zh: '崩溃报告', ko: '크래시 리포트'),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        _crashReportingDescription(context, state),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: enabled,
      onChanged: state.canToggle
          ? (value) {
              ref
                  .read(crashReportingControllerProvider.notifier)
                  .setEnabled(value);
            }
          : null,
    );
  }
}

String _crashReportingDescription(
  BuildContext context,
  CrashReportingState state,
) {
  if (!state.available) {
    return switch (state.unavailableReason) {
      CrashReportingUnavailableReason.unsupportedPlatform => _t(
        context,
        'Crash reports are available in the iOS app, not in this preview.',
        'クラッシュレポートはiOSアプリで利用できます。このプレビューでは利用できません。',
        zh: '崩溃报告可在 iOS 应用中使用，当前预览不可用。',
        ko: '크래시 리포트는 iOS 앱에서 사용할 수 있으며 이 미리보기에서는 사용할 수 없습니다.',
      ),
      CrashReportingUnavailableReason.initializationFailed => _t(
        context,
        'Crash reports could not be started. Check Firebase configuration.',
        'クラッシュレポートを開始できませんでした。Firebase設定を確認してください。',
        zh: '无法启动崩溃报告。请检查 Firebase 设置。',
        ko: '크래시 리포트를 시작할 수 없습니다. Firebase 설정을 확인하세요.',
      ),
      _ => _t(
        context,
        'Crash reports are disabled in this build.',
        'このビルドではクラッシュレポートを無効化しています。',
        zh: '此构建已禁用崩溃报告。',
        ko: '이 빌드에서는 크래시 리포트가 비활성화되어 있습니다.',
      ),
    };
  }
  if (state.updating) {
    return _t(
      context,
      'Updating crash report settings...',
      'クラッシュレポート設定を更新しています...',
      zh: '正在更新崩溃报告设置...',
      ko: '크래시 리포트 설정을 업데이트하는 중...',
    );
  }
  if (state.enabled) {
    return _t(
      context,
      'Sends stack traces, device/OS information, and app version to Firebase after crashes. Music library details are not sent.',
      'クラッシュ後にスタックトレース、端末/OS情報、アプリバージョンをFirebaseへ送信します。曲名などは送信しません。',
      zh: '崩溃后会向 Firebase 发送堆栈跟踪、设备/系统信息和应用版本。不会发送音乐库详情。',
      ko: '크래시 후 스택 트레이스, 기기/OS 정보, 앱 버전을 Firebase로 보냅니다. 음악 라이브러리 상세 정보는 보내지 않습니다.',
    );
  }
  return _t(
    context,
    'When enabled, SongBrief can receive crash diagnostics. Track names, lyrics, playlists, and listening history are not included.',
    '有効にすると、SongBriefがクラッシュ診断を受け取れます。曲名、歌詞、プレイリスト、聴取履歴は含めません。',
    zh: '启用后，SongBrief 可以接收崩溃诊断。不会包含曲名、歌词、播放列表或收听历史。',
    ko: '활성화하면 SongBrief가 크래시 진단을 받을 수 있습니다. 곡명, 가사, 플레이리스트, 청취 기록은 포함하지 않습니다.',
  );
}

class _AdPrivacySetting extends ConsumerWidget {
  const _AdPrivacySetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(adConsentControllerProvider);
    return consent.when(
      data: (state) {
        if (!state.privacyOptionsRequired) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsRow(
                icon: Icons.ads_click_outlined,
                label: _t(
                  context,
                  'Ad privacy choices',
                  '広告プライバシー設定',
                  zh: '广告隐私设置',
                  ko: '광고 개인정보 설정',
                ),
                value: state.updating
                    ? _t(
                        context,
                        'Opening...',
                        '表示中...',
                        zh: '正在打开...',
                        ko: '여는 중...',
                      )
                    : _t(context, 'Manage', '管理'),
                onTap: state.updating
                    ? null
                    : () => _showAdPrivacyOptions(context, ref),
              ),
              const SizedBox(height: 4),
              Text(
                _t(
                  context,
                  'Change consent choices for ads when required in your region.',
                  'お住まいの地域で必要な場合、広告に関する同意内容を変更できます。',
                  zh: '如果你所在地区需要，可以更改广告相关的同意选择。',
                  ko: '거주 지역에서 필요한 경우 광고 동의 선택을 변경할 수 있습니다.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

Future<void> _showAdPrivacyOptions(BuildContext context, WidgetRef ref) async {
  final result = await ref
      .read(adConsentControllerProvider.notifier)
      .showPrivacyOptions();
  if (!context.mounted || result.errorMessage == null) {
    return;
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        _t(
          context,
          'Could not open ad privacy settings.',
          '広告プライバシー設定を開けませんでした。',
          zh: '无法打开广告隐私设置。',
          ko: '광고 개인정보 설정을 열 수 없습니다.',
        ),
      ),
    ),
  );
}
