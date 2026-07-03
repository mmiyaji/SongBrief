import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
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
