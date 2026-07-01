import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'settings/app_lock.dart';
import 'settings/app_preferences.dart';
import 'theme/app_theme.dart';

class SongBriefApp extends ConsumerWidget {
  const SongBriefApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeStyle = ref.watch(themeStyleProvider);
    final appLanguage = ref.watch(appLanguageProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SongBrief',
      locale: appLanguage.locale,
      supportedLocales: const [Locale('en'), Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: buildSongBriefTheme(style: themeStyle),
      home: const AppLockGate(child: HomeScreen()),
    );
  }
}

String _appText(BuildContext context, String en, String ja) {
  return Localizations.localeOf(context).languageCode == 'ja' ? ja : en;
}

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(ref.read(appLockControllerProvider.notifier).lock());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockControllerProvider).value;
    return Stack(
      children: [
        widget.child,
        if (state?.locked ?? false) _AppLockScreen(state: state!),
      ],
    );
  }
}

class _AppLockScreen extends ConsumerWidget {
  const _AppLockScreen({required this.state});

  final AppLockState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.72,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          color: theme.colorScheme.primary,
                          size: 42,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _appText(
                            context,
                            'SongBrief is locked',
                            'SongBriefはロック中です',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _appText(
                            context,
                            'Unlock with your device authentication.',
                            '端末認証でロックを解除してください。',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _appText(
                              context,
                              'Authentication failed.',
                              '認証に失敗しました。',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: state.authenticating
                                ? null
                                : () {
                                    ref
                                        .read(
                                          appLockControllerProvider.notifier,
                                        )
                                        .unlock(
                                          localizedReason: _appText(
                                            context,
                                            'Unlock SongBrief.',
                                            'SongBriefのロックを解除します。',
                                          ),
                                        );
                                  },
                            icon: state.authenticating
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_open_rounded),
                            label: Text(_appText(context, 'Unlock', 'ロック解除')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
