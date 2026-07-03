import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  testWidgets('opens stat-backed track lists from overview cards', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final tracksCard = find.text('Tracks').first;
    await tester.ensureVisible(tracksCard);
    await tester.tap(tracksCard);
    await tester.pumpAndSettle();

    expect(find.text('All songs'), findsOneWidget);
    expect(find.textContaining('Library tracks'), findsOneWidget);
  });

  testWidgets('opens a smart list as a track list', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final smartList = find.text('High skip rate');
    await tester.scrollUntilVisible(
      smartList,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(smartList);
    await tester.pumpAndSettle();

    expect(find.text('High skip rate'), findsNWidgets(2));
    expect(find.textContaining('Songs with repeated skips'), findsWidgets);
  });

  testWidgets('opens the expanded listening maps view', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    expect(find.text('Listening maps'), findsOneWidget);
    expect(find.text('Tap a year point'), findsOneWidget);

    final expandButton = find.byTooltip('Expand listening maps');
    await tester.ensureVisible(expandButton);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('Genre stack by release year'), findsOneWidget);
    expect(find.text('Era mix'), findsOneWidget);
    expect(find.text('Activity heatmap'), findsWidgets);
  });

  testWidgets('shows recap and collection insight panels', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    expect(find.text('Recap highlights'), findsOneWidget);
    expect(find.text('SongBrief Recap'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Next milestone'), findsOneWidget);
    expect(find.text('Listening curve'), findsOneWidget);

    final rediscovery = find.text('Rediscovery');
    await tester.scrollUntilVisible(
      rediscovery,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Diversity score'), findsOneWidget);
    expect(find.text('Album completion'), findsOneWidget);
    expect(find.text('Late Bloom'), findsWidgets);
  });

  testWidgets('opens an album completion list', (tester) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final album = find.text('Small Signals');
    await tester.scrollUntilVisible(
      album,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(album);
    await tester.pumpAndSettle();

    expect(find.textContaining('Album songs'), findsOneWidget);
  });

  testWidgets('opens a release decade list from expanded listening maps', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    final expandButton = find.byTooltip('Expand listening maps');
    await tester.ensureVisible(expandButton);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    final decadeRow = find.text('2010s');
    await tester.ensureVisible(decadeRow);
    await tester.tap(decadeRow);
    await tester.pumpAndSettle();

    expect(find.textContaining('Release decade songs'), findsOneWidget);
  });
}

Future<void> _pumpOverview(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(AppLanguage.english),
        ),
        homeSectionProvider.overrideWith(
          () => _FixedHomeSectionController(HomeSection.overview),
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
