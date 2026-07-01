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
}

const _expectedEnglish = <HomeSection, List<String>>{
  HomeSection.playing: [
    'Playing',
    'This week trend',
    'Recently played songs',
    'Plays',
  ],
  HomeSection.overview: [
    'Overview',
    'Total Plays',
    'Daily snapshots',
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
  HomeSection.playing: ['再生中', '今週の傾向', '最近再生した曲', '再生回数'],
  HomeSection.overview: ['概要', '総再生回数', '日次スナップショット', 'リスニング洞察', 'ライブラリ分布'],
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
