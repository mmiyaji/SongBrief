import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:songbrief/src/analytics/app_analytics.dart';
import 'package:songbrief/src/analytics/crash_reporting.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/theme/startup_typography.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_lock.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

@JS('performance.mark')
external void _performanceMark(JSString name);

void _mark(String name) => _performanceMark(name.toJS);

final class _StartupObserver extends ProviderObserver {
  bool _loadingMarked = false;
  bool _dataMarked = false;
  bool _contentFrameMarked = false;

  void _observe(Object? value) {
    if (value is! AsyncValue) return;
    if (!_loadingMarked && value.isLoading) {
      _loadingMarked = true;
      _mark('songbrief-loading');
    }
    if (!_dataMarked && value.hasValue) {
      _dataMarked = true;
      _mark('songbrief-data-ready');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_contentFrameMarked) return;
        _contentFrameMarked = true;
        _mark('songbrief-content-frame');
      });
    }
  }

  bool _isStats(ProviderObserverContext context) =>
      context.provider == musicStatsControllerProvider;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (_isStats(context)) _observe(value);
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (_isStats(context)) _observe(newValue);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugProfileBuildsEnabled = const bool.fromEnvironment(
    'SONGBRIEF_PROFILE_WIDGETS',
  );
  debugProfileLayoutsEnabled = debugProfileBuildsEnabled;
  debugProfilePaintsEnabled = debugProfileBuildsEnabled;
  final typographyReady = prepareAppTypography();
  final preferences = await SharedPreferences.getInstance();
  final analytics = await AppAnalytics.initialize();
  final crashReporting = await CrashReporting.initialize(preferences);
  final appLockEnabled =
      preferences.getBool(appLockEnabledPreferenceKey) ?? false;
  await typographyReady;
  runApp(
    ProviderScope(
      observers: [_StartupObserver()],
      overrides: [
        appAnalyticsProvider.overrideWithValue(analytics),
        initialCrashReportingStateProvider.overrideWithValue(crashReporting),
        initialAppLockEnabledProvider.overrideWithValue(appLockEnabled),
        musicDataSharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const SongBriefApp(),
    ),
  );
}
