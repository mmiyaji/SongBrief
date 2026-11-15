// Captures the actual app. No screenshot-specific UI or image composition.
// flutter test tool/capture_store_test.dart --dart-define=SONGBRIEF_SCREENSHOT_MODE=true --reporter expanded
// Optional: SONGBRIEF_PREVIEW_FONT points to a Japanese-capable .ttf font.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';
import 'package:songbrief/src/theme/app_theme.dart';

import 'fixtures/store_demo.dart';

const _boundaryKey = ValueKey('website-capture');

void main() {
  testWidgets('capture bilingual App Store screenshots of the real app', (
    tester,
  ) async {
    expect(
      screenshotModeEnabled,
      isTrue,
      reason: 'Use --dart-define=SONGBRIEF_SCREENSHOT_MODE=true.',
    );
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final font = File(
      Platform.environment['SONGBRIEF_PREVIEW_FONT'] ??
          'C:/Windows/Fonts/NotoSansJP-VF.ttf',
    );
    expect(
      font.existsSync(),
      isTrue,
      reason: 'Set SONGBRIEF_PREVIEW_FONT to a Japanese-capable font.',
    );
    final loader = FontLoader('WebsiteCapture');
    loader.addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final stats = websiteDemoState();
    final today = DateTime.now();
    expect(websiteDemoDate.isAfter(today), isFalse);
    expect(stats.overview.isDemo, isTrue);
    expect(
      stats.overview.tracks.map((track) => track.playCount).toSet().length,
      greaterThan(10),
    );
    expect(stats.snapshotHistory.snapshots.length, greaterThanOrEqualTo(90));
    var previousCount = -1;
    for (final snapshot in stats.snapshotHistory.snapshots) {
      expect(snapshot.capturedAt.isAfter(websiteDemoDate), isFalse);
      expect(snapshot.totalPlayCount, greaterThanOrEqualTo(previousCount));
      previousCount = snapshot.totalPlayCount;
    }
    expect(previousCount, stats.overview.totalPlayCount);
    for (final track in stats.overview.tracks) {
      expect(File(track.artworkAsset!).existsSync(), isTrue);
      expect(track.lastPlayedAt!.isAfter(websiteDemoDate), isFalse);
    }
    for (final language in [AppLanguage.japanese, AppLanguage.english]) {
      final suffix = language == AppLanguage.english ? '-en' : '';
      for (final device in ['iphone', 'ipad', 'duo']) {
        final tablet = device == 'ipad';
        tester.view.physicalSize = device == 'duo'
            ? const Size(669, 951)
            : tablet
            ? const Size(1366, 1024)
            : const Size(430, 932);
        final sections = [
          HomeSection.playing,
          HomeSection.overview,
          HomeSection.rankings,
          HomeSection.library,
        ];
        for (final section in sections) {
          final container = ProviderContainer(
            overrides: [
              homeSectionProvider.overrideWith(() => _Section(section)),
              appLanguageProvider.overrideWith(() => _Language(language)),
              themeStyleProvider.overrideWith(_Mint.new),
              themeBrightnessProvider.overrideWith(_Dark.new),
              snapshotCloudSyncProvider.overrideWith(_LocalSnapshots.new),
              musicStatsControllerProvider.overrideWith(() => _Stats(stats)),
              playbackControllerProvider.overrideWith(() => _Playback(stats)),
              trackArtworkProvider.overrideWith((ref, id) async => null),
            ],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const RepaintBoundary(
                key: _boundaryKey,
                child: _ActualAppWithCaptureFont(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final context = tester.element(find.byType(Scaffold).first);
            for (final name in websiteDemoArtwork) {
              await precacheImage(
                AssetImage('assets/demo_art/$name.png'),
                context,
              );
              await precacheImage(
                ResizeImage(
                  AssetImage('assets/demo_art/$name.png'),
                  width: 256,
                  height: 256,
                ),
                context,
              );
            }
          });
          await tester.pumpAndSettle();
          await _capture(tester, '$device-${section.name}$suffix');
          if (section == HomeSection.overview) {
            await _showActualPanel(tester, '_ActivityHeatmapCard');
            final artistLabel = language == AppLanguage.english
                ? 'Artist'
                : 'アーティスト';
            final artistTab = find.text(artistLabel);
            if (artistTab.evaluate().isNotEmpty) {
              await tester.tap(artistTab.first);
              await tester.pumpAndSettle();
            }
            await _capture(tester, '$device-calendar$suffix');
            await _showActualPanel(tester, '_RecapHighlightsPanel');
            final month = find.text(
              language == AppLanguage.english ? 'Month' : '月間',
            );
            await tester.ensureVisible(month.first);
            await tester.tap(month.first);
            await tester.pumpAndSettle();
            await _capture(tester, '$device-recap$suffix');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await tester.pumpAndSettle();
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<void> _showActualPanel(WidgetTester tester, String type) async {
  final target = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == type,
  );
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    target,
    320,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: 'Rendering $name');
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('store_assets/v1.2.8/raw/$name.png');
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

// Build the production SongBriefApp and preserve its home, locale, preferences,
// theme and app-lock builder. Only supply the loaded font for the test renderer.
class _ActualAppWithCaptureFont extends ConsumerWidget {
  const _ActualAppWithCaptureFont();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = const SongBriefApp().build(context, ref) as MaterialApp;
    ThemeData fontTheme(ThemeData theme) => theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'WebsiteCapture'),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: 'WebsiteCapture',
      ),
      navigationRailTheme: theme.navigationRailTheme.copyWith(
        selectedLabelTextStyle: theme.navigationRailTheme.selectedLabelTextStyle
            ?.copyWith(fontFamily: 'WebsiteCapture'),
        unselectedLabelTextStyle: theme
            .navigationRailTheme
            .unselectedLabelTextStyle
            ?.copyWith(fontFamily: 'WebsiteCapture'),
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
      title: app.title,
      onGenerateTitle: app.onGenerateTitle,
      locale: app.locale,
      supportedLocales: app.supportedLocales,
      localizationsDelegates: app.localizationsDelegates,
      localeListResolutionCallback: app.localeListResolutionCallback,
      theme: fontTheme(app.theme!),
      darkTheme: fontTheme(app.darkTheme!),
      themeMode: app.themeMode,
      builder: app.builder,
      home: app.home,
    );
  }
}

class _Stats extends MusicStatsController {
  _Stats(this.value);
  final MusicStatsState value;
  @override
  Future<MusicStatsState> build() async => value;
}

class _Section extends HomeSectionController {
  _Section(this.value);
  final HomeSection value;
  @override
  HomeSection build() => value;
}

class _Language extends AppLanguageController {
  _Language(this.value);
  final AppLanguage value;
  @override
  AppLanguage build() => value;
}

class _Mint extends ThemeStyleController {
  @override
  SongBriefThemeStyle build() => SongBriefThemeStyle.prism;
}

class _Dark extends ThemeBrightnessController {
  @override
  SongBriefThemeBrightness build() => SongBriefThemeBrightness.dark;
}

class _Playback extends PlaybackController {
  _Playback(this.stats);
  final MusicStatsState stats;
  @override
  PlaybackState build() => PlaybackState(
    activeTrackId: stats.overview.tracks.first.id,
    nowPlaying: stats.overview.tracks.first,
    isPlaying: true,
  );
}

class _LocalSnapshots extends SnapshotCloudSyncController {
  @override
  bool build() => false;
}
