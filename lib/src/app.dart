import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'localization/generated/app_localizations.dart';
import 'settings/app_lock.dart';
import 'settings/app_preferences.dart';
import 'theme/app_theme.dart';

const songBriefSupportedLocales = <Locale>[
  Locale('en'),
  Locale('ja'),
  songBriefSimplifiedChineseLocale,
  Locale('ko'),
];

class SongBriefApp extends ConsumerWidget {
  const SongBriefApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeStyle = ref.watch(themeStyleProvider);
    final themeBrightness = ref.watch(themeBrightnessProvider);
    final appLanguage = ref.watch(appLanguageProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SongBrief',
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: appLanguage.locale,
      supportedLocales: songBriefSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: resolveSongBriefLocale,
      theme: buildSongBriefTheme(
        style: themeStyle,
        brightness: Brightness.light,
      ),
      darkTheme: buildSongBriefTheme(
        style: themeStyle,
        brightness: Brightness.dark,
      ),
      themeMode: themeBrightness.themeMode,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
      home: const HomeScreen(),
    );
  }
}

Locale resolveSongBriefLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  const fallback = Locale('en');
  final supported = supportedLocales.toList(growable: false);
  if (preferredLocales == null || preferredLocales.isEmpty) {
    return fallback;
  }

  for (final preferred in preferredLocales) {
    final resolved = _resolveSingleSongBriefLocale(preferred, supported);
    if (resolved != null) {
      return resolved;
    }
  }
  return fallback;
}

Locale? _resolveSingleSongBriefLocale(
  Locale preferred,
  List<Locale> supportedLocales,
) {
  if (preferred.languageCode == 'zh') {
    final scriptCode = preferred.scriptCode?.toLowerCase();
    final countryCode = preferred.countryCode?.toUpperCase();
    if (scriptCode == 'hans' ||
        (scriptCode == null &&
            (countryCode == 'CN' ||
                countryCode == 'SG' ||
                countryCode == 'MY'))) {
      return songBriefSimplifiedChineseLocale;
    }
    return null;
  }

  for (final supported in supportedLocales) {
    if (preferred.languageCode == supported.languageCode &&
        supported.scriptCode == null) {
      return supported;
    }
  }
  return null;
}

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool? _lastProtectedLockState;
  late final AppLockPrivacyProtector _privacyProtector;

  @override
  void initState() {
    super.initState();
    _privacyProtector = ref.read(appLockPrivacyProtectorProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    unawaited(_privacyProtector.setLocked(false));
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final lockState = ref.read(appLockControllerProvider).value;
      if (lockState?.enabled == true && lockState?.supported == true) {
        unawaited(_privacyProtector.setLocked(true));
        unawaited(ref.read(appLockControllerProvider.notifier).lock());
      } else {
        unawaited(_privacyProtector.setLocked(false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appLockControllerProvider);
    final initialLockEnabled = ref.watch(initialAppLockEnabledProvider);
    final state = asyncState.value;
    final initializing = initialLockEnabled && state == null;
    final locked = state?.locked ?? false;
    final contentBlocked = initializing || locked;
    final protectionActive =
        initializing ||
        (state?.enabled == true && state?.supported == true && locked);
    _syncPrivacyProtection(protectionActive);
    return Stack(
      children: [
        IgnorePointer(
          ignoring: contentBlocked,
          child: ExcludeSemantics(
            excluding: contentBlocked,
            child: ExcludeFocus(excluding: contentBlocked, child: widget.child),
          ),
        ),
        if (initializing) const _AppLockInitializingScreen(),
        if (locked) _AppLockScreen(state: state!),
      ],
    );
  }

  void _syncPrivacyProtection(bool locked) {
    if (_lastProtectedLockState == locked) {
      return;
    }
    _lastProtectedLockState = locked;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_privacyProtector.setLocked(locked));
    });
  }
}

class _AppLockInitializingScreen extends StatelessWidget {
  const _AppLockInitializingScreen();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: _PrivacyScreenShell(
          key: const ValueKey('app-lock-initializing'),
        ),
      ),
    );
  }
}

class _AppLockScreen extends ConsumerWidget {
  const _AppLockScreen({required this.state});

  final AppLockState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = Localizations.of<AppLocalizations>(context, AppLocalizations);
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
                        const _PrivacyScreenBrandMark(
                          size: 92,
                          showLockBadge: true,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          text?.appLockedTitle ?? 'SongBrief is locked',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          text?.appLockedSubtitle ??
                              'Unlock with your device authentication.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            text?.authenticationFailed ??
                                'Authentication failed.',
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
                                          localizedReason:
                                              text?.unlockSongBriefReason ??
                                              'Unlock SongBrief.',
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
                            label: Text(text?.unlock ?? 'Unlock'),
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

class _PrivacyScreenShell extends StatelessWidget {
  const _PrivacyScreenShell({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: const Center(child: _PrivacyScreenBrandMark(size: 112)),
    );
  }
}

class _PrivacyScreenBrandMark extends StatelessWidget {
  const _PrivacyScreenBrandMark({
    required this.size,
    this.showLockBadge = false,
  });

  final double size;
  final bool showLockBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/branding/songbrief_icon_foreground.png',
            key: const ValueKey('app-lock-privacy-mark'),
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.multiline_chart_rounded,
                color: theme.colorScheme.primary,
                size: size * 0.56,
              );
            },
          ),
          if (showLockBadge)
            Positioned(
              right: -size * 0.04,
              bottom: -size * 0.04,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 3,
                  ),
                ),
                child: SizedBox.square(
                  dimension: size * 0.3,
                  child: Icon(
                    Icons.lock_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: size * 0.16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
