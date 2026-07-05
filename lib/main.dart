import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/analytics/app_analytics.dart';
import 'src/analytics/crash_reporting.dart';
import 'src/settings/app_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final analytics = await AppAnalytics.initialize();
  final crashReporting = await CrashReporting.initialize(preferences);
  final appLockEnabled =
      preferences.getBool(appLockEnabledPreferenceKey) ?? false;
  runApp(
    ProviderScope(
      overrides: [
        appAnalyticsProvider.overrideWithValue(analytics),
        initialCrashReportingStateProvider.overrideWithValue(crashReporting),
        initialAppLockEnabledProvider.overrideWithValue(appLockEnabled),
      ],
      child: const SongBriefApp(),
    ),
  );
}
