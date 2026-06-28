import 'package:flutter/material.dart';

ThemeData buildSongBriefTheme() {
  const seed = Color(0xFFFF3D78);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF050507),
        surfaceContainerHighest: const Color(0xFF1B1B20),
        primary: seed,
        secondary: const Color(0xFFFF9B52),
        tertiary: const Color(0xFF6FE5C4),
        onSurface: const Color(0xFFF8F7FA),
        onSurfaceVariant: const Color(0xFFAAA6B3),
        outlineVariant: const Color(0xFF34323A),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, height: 1.05),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, height: 1.08),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(height: 1.35),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: seed,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: seed.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          color: scheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: seed.withValues(alpha: 0.18),
      selectedIconTheme: const IconThemeData(color: seed),
      selectedLabelTextStyle: const TextStyle(
        color: seed,
        fontWeight: FontWeight.w800,
      ),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
  );
}
