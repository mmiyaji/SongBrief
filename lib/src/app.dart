import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';

class SongBriefApp extends ConsumerWidget {
  const SongBriefApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeStyle = ref.watch(themeStyleProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SongBrief',
      theme: buildSongBriefTheme(style: themeStyle),
      home: const HomeScreen(),
    );
  }
}
