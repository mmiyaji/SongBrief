// Render the real calendar widget with local sample artwork, without iOS APIs.
// flutter test tool/preview_calendar_test.dart --reporter expanded
// PNGs are written under build/calendar-preview/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/localization/generated/app_localizations.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/theme/app_theme.dart';

void main() {
  testWidgets('capture the actual jacket calendar in dark and light themes', (
    tester,
  ) async {
    // This tool is a Flutter test entrypoint outside the automatic test suite.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final fontPath =
        Platform.environment['SONGBRIEF_PREVIEW_FONT'] ??
        'C:/Windows/Fonts/NotoSansJP-VF.ttf';
    final font = File(fontPath);
    if (font.existsSync()) {
      final loader = FontLoader('CalendarPreview');
      loader.addFont(
        Future.value(ByteData.sublistView(font.readAsBytesSync())),
      );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final state = _fixture();
    final container = ProviderContainer(
      overrides: [
        homeSectionProvider.overrideWith(_OverviewSection.new),
        appLanguageProvider.overrideWith(_Japanese.new),
        musicStatsControllerProvider.overrideWith(() => _Stats(state)),
        trackArtworkProvider.overrideWith((ref, id) async => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SongBriefApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      for (final track in state.overview.tracks) {
        await precacheImage(AssetImage(track.artworkAsset!), context);
      }
    });
    await tester.pumpAndSettle();
    // Reuse the actual private production widget; no duplicate UI is built here.
    final card = tester.widget<Widget>(
      find
          .byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_ActivityHeatmapCard',
          )
          .first,
    );
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = const Size(390, 2200);
      var theme = buildSongBriefTheme(
        style: SongBriefThemeStyle.prism,
        brightness: brightness,
      );
      if (font.existsSync()) {
        theme = theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'CalendarPreview'),
        );
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ja'),
            supportedLocales: songBriefSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: theme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: const ValueKey('calendar-preview-boundary'),
                  child: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: card,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final artist = find.text('アーティスト');
      await tester.tap(artist.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('calendar-preview-boundary')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/calendar-preview/${brightness.name}.png');
        output.parent.createSync(recursive: true);
        output.writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

MusicStatsState _fixture() {
  final now = DateTime.now();
  const titles = [
    'Skyline Echo',
    'Late Bloom',
    'North Line',
    'Signal Blue',
    'Glass Harbor',
    'Midnight Arcade',
    'Subway Light',
    'Tableau',
  ];
  const assets = [
    'skyline_echo',
    'late_bloom',
    'north_line',
    'signal_blue',
    'glass_harbor',
    'midnight_arcade',
    'subway_light',
    'tableau',
  ];
  final counts = List<int>.filled(titles.length, 100);
  List<LibraryTrack> tracks(DateTime date) => List.generate(titles.length, (i) {
    return LibraryTrack(
      id: 'preview-$i',
      title: titles[i],
      artist: ['Aoi', 'Mika', 'Haru', 'Sora'][i % 4],
      albumTitle: titles[i],
      playCount: counts[i],
      skipCount: 0,
      duration: const Duration(minutes: 4),
      lastPlayedAt: date,
      isCloudItem: false,
      artworkAsset: 'assets/demo_art/${assets[i]}.png',
    );
  });
  final snapshots = <DailyLibrarySnapshot>[];
  for (var day = 0; day <= now.day; day++) {
    final date = DateTime(now.year, now.month, day, 9);
    counts[day % titles.length] += 8 + day % 7;
    counts[(day + 3) % titles.length] += day % 5;
    if (day == 12 || day == 19) continue;
    snapshots.add(
      DailyLibrarySnapshot.fromOverview(
        LibraryOverview.fromTracks(tracks(date), isDemo: true),
        capturedAt: date,
      ),
    );
  }
  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
    overview: LibraryOverview.fromTracks(tracks(now), isDemo: true),
    snapshotHistory: SnapshotHistory(snapshots: snapshots),
    snapshotRecordingEnabled: true,
  );
}

class _Stats extends MusicStatsController {
  _Stats(this.value);
  final MusicStatsState value;
  @override
  Future<MusicStatsState> build() async => value;
}

class _Japanese extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.japanese;
}

class _OverviewSection extends HomeSectionController {
  @override
  HomeSection build() => HomeSection.overview;
}
