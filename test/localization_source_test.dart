import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/localization/generated/app_localizations.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  test('Simplified Chinese is modeled as zh-Hans', () {
    const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
    expect(AppLanguage.chineseSimplified.locale, zhHans);
    expect(AppLocalizations.supportedLocales, contains(zhHans));
    expect(songBriefSupportedLocales, contains(zhHans));
    expect(songBriefSupportedLocales, isNot(contains(const Locale('zh'))));
    expect(resolveSongBriefLocale([zhHans], songBriefSupportedLocales), zhHans);
    expect(
      resolveSongBriefLocale(const [
        Locale('zh', 'CN'),
      ], songBriefSupportedLocales),
      zhHans,
    );
    expect(
      resolveSongBriefLocale(const [Locale('zh')], songBriefSupportedLocales),
      const Locale('en'),
    );
    expect(
      resolveSongBriefLocale(const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ], songBriefSupportedLocales),
      const Locale('en'),
    );
  });

  test('iOS localizations publish zh-Hans instead of generic zh', () {
    expect(Directory('ios/Runner/zh-Hans.lproj').existsSync(), isTrue);
    expect(Directory('ios/Runner/zh.lproj').existsSync(), isFalse);

    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(infoPlist, contains('<string>zh-Hans</string>'));
    expect(infoPlist, isNot(contains('<string>zh</string>')));

    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(project, contains('zh-Hans.lproj/InfoPlist.strings'));
    expect(project, isNot(contains('zh.lproj/InfoPlist.strings')));
  });

  test('home copy does not rely on English fallback for zh-Hans or ko', () {
    final copyKeys = _localizedCopyKeys();
    final missing = <String>[];
    for (final file in _homeDartFiles()) {
      final text = file.readAsStringSync();
      for (final match in _translationCallPattern.allMatches(text)) {
        final english = match.group(1)!;
        final block = _callBlock(text, match.start);
        final hasExplicitChinese = block.contains('zh:');
        final hasExplicitKorean = block.contains('ko:');
        if ((!hasExplicitChinese || !hasExplicitKorean) &&
            !copyKeys.contains(english)) {
          final line =
              '\n'.allMatches(text.substring(0, match.start)).length + 1;
          missing.add('${file.path}:$line: $english');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('appText does not use regex-based dynamic translation fallback', () {
    final source = File(
      'lib/src/localization/app_text.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('_dynamicText')));
    expect(source, isNot(contains('RegExp(')));
  });
}

final _translationCallPattern = RegExp(
  r"_t\(\s*context,\s*'((?:\\.|[^'\\])*)'",
  multiLine: true,
  dotAll: true,
);

Set<String> _localizedCopyKeys() {
  final source = File('lib/src/localization/app_text.dart').readAsStringSync();
  return RegExp(
    r"^\s*'((?:\\.|[^'\\])*)':\s*_LocalizedCopy",
    multiLine: true,
  ).allMatches(source).map((match) => match.group(1)!).toSet();
}

Iterable<File> _homeDartFiles() {
  return Directory('lib/src/features/home')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

String _callBlock(String source, int start) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var index = start; index < source.length; index++) {
    final char = source[index];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
  }
  return source.substring(start);
}
