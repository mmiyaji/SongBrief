import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
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
      home: const HomeScreen(),
    );
  }
}
