import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/theme/app_theme.dart';

void main() {
  test('dark Ember filled buttons meet WCAG AA text contrast', () {
    final theme = buildSongBriefTheme(
      style: SongBriefThemeStyle.ember,
      brightness: Brightness.dark,
    );
    final buttonStyle = theme.filledButtonTheme.style!;
    final foreground = buttonStyle.foregroundColor!.resolve({})!;
    final background = buttonStyle.backgroundColor!.resolve({})!;

    expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = math.max(first.computeLuminance(), second.computeLuminance());
  final darker = math.min(first.computeLuminance(), second.computeLuminance());
  return (lighter + 0.05) / (darker + 0.05);
}
