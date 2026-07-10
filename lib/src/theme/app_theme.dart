import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeStylePreferenceKey = 'songbrief_theme_style_v1';
const _themeBrightnessPreferenceKey = 'songbrief_theme_brightness_v1';

const _appFontFallback = <String>[
  'Yu Gothic',
  'Meiryo',
  'Noto Sans JP',
  'Hiragino Sans',
  'sans-serif',
];

enum SongBriefThemeStyle {
  prism,
  flux,
  ember,
  mono,
  aurora,
  grove,
  pulse,
  muse,
}

enum SongBriefThemeBrightness {
  dark,
  light,
  system;

  ThemeMode get themeMode {
    return switch (this) {
      SongBriefThemeBrightness.dark => ThemeMode.dark,
      SongBriefThemeBrightness.light => ThemeMode.light,
      SongBriefThemeBrightness.system => ThemeMode.system,
    };
  }
}

final themeStyleProvider =
    NotifierProvider<ThemeStyleController, SongBriefThemeStyle>(
      ThemeStyleController.new,
    );

final themeBrightnessProvider =
    NotifierProvider<ThemeBrightnessController, SongBriefThemeBrightness>(
      ThemeBrightnessController.new,
    );

class ThemeStyleController extends Notifier<SongBriefThemeStyle> {
  var _changedByUser = false;

  @override
  SongBriefThemeStyle build() {
    _restore();
    return SongBriefThemeStyle.prism;
  }

  void setStyle(SongBriefThemeStyle style) {
    _changedByUser = true;
    state = style;
    unawaited(_save(style));
  }

  void _restore() {
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      final preferences = await SharedPreferences.getInstance();
      final style = _themeStyleFromName(
        preferences.getString(_themeStylePreferenceKey),
      );
      if (!disposed && !_changedByUser && style != null) {
        state = style;
      }
    }());
  }

  Future<void> _save(SongBriefThemeStyle style) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeStylePreferenceKey, style.name);
  }
}

class ThemeBrightnessController extends Notifier<SongBriefThemeBrightness> {
  var _changedByUser = false;

  @override
  SongBriefThemeBrightness build() {
    _restore();
    return SongBriefThemeBrightness.system;
  }

  void setBrightness(SongBriefThemeBrightness brightness) {
    _changedByUser = true;
    state = brightness;
    unawaited(_save(brightness));
  }

  void _restore() {
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      final preferences = await SharedPreferences.getInstance();
      final brightness = _themeBrightnessFromName(
        preferences.getString(_themeBrightnessPreferenceKey),
      );
      if (!disposed && !_changedByUser && brightness != null) {
        state = brightness;
      }
    }());
  }

  Future<void> _save(SongBriefThemeBrightness brightness) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeBrightnessPreferenceKey, brightness.name);
  }
}

SongBriefThemeStyle? _themeStyleFromName(String? name) {
  for (final style in SongBriefThemeStyle.values) {
    if (style.name == name) {
      return style;
    }
  }
  return null;
}

SongBriefThemeBrightness? _themeBrightnessFromName(String? name) {
  for (final brightness in SongBriefThemeBrightness.values) {
    if (brightness.name == name) {
      return brightness;
    }
  }
  return null;
}

ThemeData buildSongBriefTheme({
  required SongBriefThemeStyle style,
  required Brightness brightness,
}) {
  final tokens = _ThemeTokens.forStyle(style, brightness);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: tokens.primary,
        brightness: brightness,
      ).copyWith(
        surface: tokens.surface,
        surfaceContainerHighest: tokens.surfaceHigh,
        primary: tokens.primary,
        onPrimary: tokens.onPrimary,
        secondary: tokens.secondary,
        tertiary: tokens.tertiary,
        onSurface: tokens.onSurface,
        onSurfaceVariant: tokens.onSurfaceVariant,
        outlineVariant: tokens.outline,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamilyFallback: _appFontFallback,
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
        foregroundColor: tokens.onPrimary,
        backgroundColor: tokens.primary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: tokens.primary.withValues(alpha: 0.18),
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
      indicatorColor: tokens.primary.withValues(alpha: 0.18),
      selectedIconTheme: IconThemeData(color: tokens.primary),
      selectedLabelTextStyle: TextStyle(
        color: tokens.primary,
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

class _ThemeTokens {
  const _ThemeTokens({
    required this.surface,
    required this.surfaceHigh,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.tertiary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
  });

  final Color surface;
  final Color surfaceHigh;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color tertiary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;

  static _ThemeTokens forStyle(
    SongBriefThemeStyle style,
    Brightness brightness,
  ) {
    if (brightness == Brightness.light) {
      return switch (style) {
        SongBriefThemeStyle.prism => const _ThemeTokens(
          surface: Color(0xFFF6FAF8),
          surfaceHigh: Color(0xFFEAF3F0),
          primary: Color(0xFF006E5F),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF657500),
          tertiary: Color(0xFF5262D7),
          onSurface: Color(0xFF10201C),
          onSurfaceVariant: Color(0xFF58706A),
          outline: Color(0xFFC6D7D2),
        ),
        SongBriefThemeStyle.flux => const _ThemeTokens(
          surface: Color(0xFFF4FBFC),
          surfaceHigh: Color(0xFFE5F4F7),
          primary: Color(0xFF007486),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF246A9B),
          tertiary: Color(0xFF4C6FD9),
          onSurface: Color(0xFF0E1F24),
          onSurfaceVariant: Color(0xFF52717A),
          outline: Color(0xFFC0D9DF),
        ),
        SongBriefThemeStyle.ember => const _ThemeTokens(
          surface: Color(0xFFFFF8FA),
          surfaceHigh: Color(0xFFF9ECF1),
          primary: Color(0xFFC51F57),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFFA44F00),
          tertiary: Color(0xFF007A68),
          onSurface: Color(0xFF231319),
          onSurfaceVariant: Color(0xFF735E67),
          outline: Color(0xFFE2CCD4),
        ),
        SongBriefThemeStyle.mono => const _ThemeTokens(
          surface: Color(0xFFFAFAFA),
          surfaceHigh: Color(0xFFEDEDED),
          primary: Color(0xFF171717),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF246487),
          tertiary: Color(0xFF4D6F00),
          onSurface: Color(0xFF121212),
          onSurfaceVariant: Color(0xFF606060),
          outline: Color(0xFFD4D4D4),
        ),
        SongBriefThemeStyle.aurora => const _ThemeTokens(
          surface: Color(0xFFFCF7FD),
          surfaceHigh: Color(0xFFF3EAF6),
          primary: Color(0xFF8B2F74),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF006C88),
          tertiary: Color(0xFFA76000),
          onSurface: Color(0xFF251422),
          onSurfaceVariant: Color(0xFF765E71),
          outline: Color(0xFFE3CCE0),
        ),
        SongBriefThemeStyle.grove => const _ThemeTokens(
          surface: Color(0xFFF8FAF4),
          surfaceHigh: Color(0xFFEDF3E5),
          primary: Color(0xFF426B00),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF00736A),
          tertiary: Color(0xFFC24B4F),
          onSurface: Color(0xFF1A1F13),
          onSurfaceVariant: Color(0xFF687159),
          outline: Color(0xFFD2DAC4),
        ),
        SongBriefThemeStyle.pulse => const _ThemeTokens(
          surface: Color(0xFFF7F9FF),
          surfaceHigh: Color(0xFFEAF0FA),
          primary: Color(0xFF225FD3),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF008477),
          tertiary: Color(0xFFB14375),
          onSurface: Color(0xFF101827),
          onSurfaceVariant: Color(0xFF59677E),
          outline: Color(0xFFC8D2E6),
        ),
        SongBriefThemeStyle.muse => const _ThemeTokens(
          surface: Color(0xFFFBF8FF),
          surfaceHigh: Color(0xFFF1ECF8),
          primary: Color(0xFF8753A1),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF007A74),
          tertiary: Color(0xFFB05800),
          onSurface: Color(0xFF1F1724),
          onSurfaceVariant: Color(0xFF6C6172),
          outline: Color(0xFFDCCFE4),
        ),
      };
    }

    return switch (style) {
      SongBriefThemeStyle.prism => const _ThemeTokens(
        surface: Color(0xFF040708),
        surfaceHigh: Color(0xFF151C1F),
        primary: Color(0xFF4DECC7),
        onPrimary: Color(0xFF001F1A),
        secondary: Color(0xFFE0FF67),
        tertiary: Color(0xFF7B8CFF),
        onSurface: Color(0xFFF5FCF8),
        onSurfaceVariant: Color(0xFF9DB1AD),
        outline: Color(0xFF263538),
      ),
      SongBriefThemeStyle.flux => const _ThemeTokens(
        surface: Color(0xFF03090C),
        surfaceHigh: Color(0xFF102127),
        primary: Color(0xFF55DDF7),
        onPrimary: Color(0xFF001E25),
        secondary: Color(0xFF7EC8FF),
        tertiary: Color(0xFF8EE7B9),
        onSurface: Color(0xFFF1FBFE),
        onSurfaceVariant: Color(0xFF9FC0C8),
        outline: Color(0xFF243A42),
      ),
      SongBriefThemeStyle.ember => const _ThemeTokens(
        surface: Color(0xFF050507),
        surfaceHigh: Color(0xFF1B1B20),
        primary: Color(0xFFFF3D78),
        onPrimary: Color(0xFF28000D),
        secondary: Color(0xFFFF9B52),
        tertiary: Color(0xFF6FE5C4),
        onSurface: Color(0xFFF8F7FA),
        onSurfaceVariant: Color(0xFFAAA6B3),
        outline: Color(0xFF34323A),
      ),
      SongBriefThemeStyle.mono => const _ThemeTokens(
        surface: Color(0xFF050505),
        surfaceHigh: Color(0xFF1A1A1A),
        primary: Color(0xFFEDEDED),
        onPrimary: Color(0xFF080808),
        secondary: Color(0xFF9FD8FF),
        tertiary: Color(0xFFC4FF8C),
        onSurface: Color(0xFFF7F7F7),
        onSurfaceVariant: Color(0xFFA6A6A6),
        outline: Color(0xFF303030),
      ),
      SongBriefThemeStyle.aurora => const _ThemeTokens(
        surface: Color(0xFF08050A),
        surfaceHigh: Color(0xFF211622),
        primary: Color(0xFFFF8BD8),
        onPrimary: Color(0xFF3B0030),
        secondary: Color(0xFF75D8FF),
        tertiary: Color(0xFFFFC15A),
        onSurface: Color(0xFFFFF7FC),
        onSurfaceVariant: Color(0xFFC8AFC1),
        outline: Color(0xFF3E2C3B),
      ),
      SongBriefThemeStyle.grove => const _ThemeTokens(
        surface: Color(0xFF060805),
        surfaceHigh: Color(0xFF172112),
        primary: Color(0xFFB6EC67),
        onPrimary: Color(0xFF122000),
        secondary: Color(0xFF65E6D2),
        tertiary: Color(0xFFFF9A9C),
        onSurface: Color(0xFFF8FCF2),
        onSurfaceVariant: Color(0xFFB1BEA8),
        outline: Color(0xFF2E3927),
      ),
      SongBriefThemeStyle.pulse => const _ThemeTokens(
        surface: Color(0xFF05070C),
        surfaceHigh: Color(0xFF151C2A),
        primary: Color(0xFF8CB7FF),
        onPrimary: Color(0xFF001B4A),
        secondary: Color(0xFF60E7D6),
        tertiary: Color(0xFFFF9AC2),
        onSurface: Color(0xFFF5F8FF),
        onSurfaceVariant: Color(0xFFAAB5CA),
        outline: Color(0xFF2B3548),
      ),
      SongBriefThemeStyle.muse => const _ThemeTokens(
        surface: Color(0xFF08050B),
        surfaceHigh: Color(0xFF1B1520),
        primary: Color(0xFFDDA8FF),
        onPrimary: Color(0xFF2C003F),
        secondary: Color(0xFF71E4D8),
        tertiary: Color(0xFFFFB568),
        onSurface: Color(0xFFFCF7FF),
        onSurfaceVariant: Color(0xFFC0B2C7),
        outline: Color(0xFF382C3F),
      ),
    };
  }
}
