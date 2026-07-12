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
        expect(find.text(text), findsWidgets, reason: text);
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
        expect(find.text(text), findsWidgets, reason: text);
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
    expect(find.text('音乐访问权限'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('应用信息'), findsOneWidget);
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
    'Listening insights',
    'Library distribution',
  ],
  HomeSection.rankings: [
    'Rankings',
    'Top Songs',
    'Ranked by play count',
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
    'Music Access',
    'Theme',
    'Language',
    'Security',
    'App Lock',
    'App Info',
    'Licenses',
  ],
};

const _expectedJapanese = <HomeSection, List<String>>{
  HomeSection.playing: ['再生中', '再生傾向', '最近再生した曲', '再生回数'],
  HomeSection.overview: ['概要', '総再生回数', '日々の聴取記録', 'リスニング洞察', 'ライブラリ分布'],
  HomeSection.rankings: ['ランキング', 'トップ曲', '再生回数順', '曲', 'アーティスト', 'アルバム', '最近'],
  HomeSection.library: ['ライブラリ', '曲', 'プレイリスト', '検索可能な曲詳細と再生コントロール', '並び替え'],
  HomeSection.settings: [
    '設定',
    'ミュージックアクセス',
    'テーマ',
    '言語',
    'セキュリティ',
    'アプリロック',
    'アプリ情報',
    'ライセンス',
  ],
};

Future<void> _pumpSection(
  WidgetTester tester, {
  required AppLanguage language,
  required HomeSection section,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
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
