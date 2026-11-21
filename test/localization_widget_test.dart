import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  for (final section in HomeSection.values) {
    testWidgets('localizes ${section.name} in English', (tester) async {
      await _pumpSection(
        tester,
        language: AppLanguage.english,
        section: section,
      );
      await tester.pumpAndSettle();

      for (final text in _expectedEnglish[section]!) {
        if (section == HomeSection.overview) {
          await _scrollOverviewUntilVisible(tester, find.text(text));
        }
        expect(find.text(text), findsWidgets, reason: text);
      }
      if (section == HomeSection.rankings) {
        expect(find.text('Rankings from the demo library'), findsNothing);
        await _expectRankingInfo(tester, 'Ranked by play count');
      }
      if (section == HomeSection.settings) {
        final library = find.byKey(const ValueKey('settings-category-library'));
        expect(
          tester.getCenter(library).dx,
          lessThan(tester.getCenter(find.text('Theme')).dx),
        );
        await _expectSettingsDetail(tester, 'library', 'Music Access');
        expect(library, findsOneWidget);
        expect(find.text('Theme'), findsNothing);
        await _expectSettingsDetail(tester, 'privacy', 'App Lock');
        await _expectSettingsDetail(tester, 'about', 'Licenses');
      }
    });

    testWidgets('localizes ${section.name} in Japanese', (tester) async {
      await _pumpSection(
        tester,
        language: AppLanguage.japanese,
        section: section,
      );
      await tester.pumpAndSettle();

      for (final text in _expectedJapanese[section]!) {
        if (section == HomeSection.overview) {
          await _scrollOverviewUntilVisible(tester, find.text(text));
        }
        expect(find.text(text), findsWidgets, reason: text);
      }
      if (section == HomeSection.rankings) {
        await _expectRankingInfo(tester, '再生回数順');
      }
      if (section == HomeSection.settings) {
        await _expectSettingsDetail(tester, 'library', 'ミュージックアクセス');
        await _expectSettingsDetail(tester, 'privacy', 'アプリロック');
        await _expectSettingsDetail(tester, 'about', 'ライセンス');
      }
    });
  }

  testWidgets('browses playlist groups in the library', (tester) async {
    await _pumpSection(
      tester,
      language: AppLanguage.english,
      section: HomeSection.library,
    );
    await tester.pumpAndSettle();

    final playlistMode = find.text('Playlists').last;
    await tester.ensureVisible(playlistMode);
    await tester.tap(playlistMode);
    await tester.pumpAndSettle();

    expect(find.text('Late Night Focus'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.text('Playlist'), findsWidgets);
  });

  testWidgets('stacks library sort below mode selector on tablet width', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      language: AppLanguage.english,
      section: HomeSection.library,
    );
    await tester.pumpAndSettle();

    final playlistMode = find.text('Playlists').last;
    final sortLabel = find.text('Sort').last;

    expect(playlistMode, findsOneWidget);
    expect(sortLabel, findsOneWidget);
    expect(
      tester.getTopLeft(sortLabel).dy,
      greaterThan(tester.getTopLeft(playlistMode).dy + 28),
    );
  });

  testWidgets('localizes settings in Simplified Chinese', (tester) async {
    await _pumpSection(
      tester,
      language: AppLanguage.chineseSimplified,
      section: HomeSection.settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    for (final label in ['外观与语言', '聆听记录', '音乐资料库', '导出与缓存', '隐私与安全', '应用信息']) {
      expect(find.text(label), findsWidgets);
    }
    await _expectSettingsDetail(tester, 'library', '访问与更新');
  });

  testWidgets('localizes settings in Korean', (tester) async {
    await _pumpSection(
      tester,
      language: AppLanguage.korean,
      section: HomeSection.settings,
    );
    await tester.pumpAndSettle();

    for (final label in [
      '설정',
      '외관 및 언어',
      '청취 기록',
      '음악 보관함',
      '내보내기 및 캐시',
      '개인정보 보호 및 보안',
      '앱 정보',
    ]) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('localizes playing in Korean', (tester) async {
    await _pumpSection(
      tester,
      language: AppLanguage.korean,
      section: HomeSection.playing,
    );
    await tester.pumpAndSettle();

    expect(find.text('재생 중'), findsWidgets);
    expect(find.text('재생 추세'), findsOneWidget);
    expect(find.text('가사'), findsOneWidget);
    expect(find.text('재생 횟수'), findsWidgets);
  });
}

Future<void> _expectSettingsDetail(
  WidgetTester tester,
  String category,
  String label,
) async {
  final entry = find.byKey(ValueKey('settings-category-$category'));
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(find.text(label), findsWidgets);
}

Future<void> _scrollOverviewUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  for (var attempt = 0; attempt < 60; attempt += 1) {
    if (target.evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  expect(target, findsWidgets);
}

Future<void> _expectRankingInfo(WidgetTester tester, String caption) async {
  final info = find.byKey(const ValueKey('ranking-info-button'));
  final tooltip = find.text(caption, findRichText: true);
  expect(tooltip, findsNothing);
  await tester.tap(info);
  await tester.pumpAndSettle();
  expect(tooltip, findsOneWidget);
}

const _expectedEnglish = <HomeSection, List<String>>{
  HomeSection.playing: [
    'Playing',
    'Listening trend',
    'Recently played songs',
    'Plays',
  ],
  HomeSection.overview: [
    'Overview',
    'Total Plays',
    'Daily listening records',
    'Library distribution',
    'Listening insights',
  ],
  HomeSection.rankings: [
    'Rankings',
    'Top Songs',
    'Songs',
    'Artists',
    'Albums',
    'Recent',
  ],
  HomeSection.library: [
    'Library',
    'Library browser',
    'Songs',
    'Playlists',
    'Searchable track details with play controls',
    'Sort',
  ],
  HomeSection.settings: [
    'Settings',
    'Appearance & Language',
    'Listening Records',
    'Music Library',
    'Export & Cache',
    'Privacy & Security',
    'App Info',
    'Theme',
    'Language',
  ],
};

const _expectedJapanese = <HomeSection, List<String>>{
  HomeSection.playing: ['再生中', '再生傾向', '最近再生した曲', '再生回数'],
  HomeSection.overview: ['概要', '総再生回数', '日々の聴取記録', 'ライブラリ分布', 'リスニング洞察'],
  HomeSection.rankings: ['ランキング', 'トップ曲', '曲', 'アーティスト', 'アルバム', '最近'],
  HomeSection.library: ['ライブラリ', '曲', 'プレイリスト', '検索可能な曲詳細と再生コントロール', '並び替え'],
  HomeSection.settings: [
    '設定',
    '外観と言語',
    '聴取記録',
    'ミュージックライブラリ',
    '書き出しとキャッシュ',
    'プライバシーとセキュリティ',
    'アプリ情報',
    'テーマ',
    '言語',
  ],
};

Future<void> _pumpSection(
  WidgetTester tester, {
  required AppLanguage language,
  required HomeSection section,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = section == HomeSection.settings
      ? const Size(1194, 1200)
      : const Size(900, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(language),
        ),
        homeSectionProvider.overrideWith(
          () => _FixedHomeSectionController(section),
        ),
      ],
      child: const SongBriefApp(),
    ),
  );
}

class _FixedLanguageController extends AppLanguageController {
  _FixedLanguageController(this.language);

  final AppLanguage language;

  @override
  AppLanguage build() {
    return language;
  }
}

class _FixedHomeSectionController extends HomeSectionController {
  _FixedHomeSectionController(this.section);

  final HomeSection section;

  @override
  HomeSection build() {
    return section;
  }
}
