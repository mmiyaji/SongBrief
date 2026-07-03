import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/settings/app_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final appLockEnabled =
      preferences.getBool(appLockEnabledPreferenceKey) ?? false;
  runApp(
    ProviderScope(
      overrides: [
        initialAppLockEnabledProvider.overrideWithValue(appLockEnabled),
      ],
      child: const SongBriefApp(),
    ),
  );
}
