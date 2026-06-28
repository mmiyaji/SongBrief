import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';

class SongBriefApp extends StatelessWidget {
  const SongBriefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SongBrief',
      theme: buildSongBriefTheme(),
      home: const HomeScreen(),
    );
  }
}
