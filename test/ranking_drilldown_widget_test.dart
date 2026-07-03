import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  testWidgets('opens artist ranking entries as artist song groups', (
    tester,
  ) async {
    await _pumpRankings(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Artists').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nami Arata').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Artist songs'), findsOneWidget);
    expect(find.text('Show position in ranking'), findsOneWidget);
    expect(find.text('Skyline Echo'), findsWidgets);
    expect(find.text('Glass Harbor'), findsWidgets);
  });

  testWidgets('opens album ranking entries as album song groups', (
    tester,
  ) async {
    await _pumpRankings(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Albums').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nami Arata - Night Transit').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Album songs'), findsOneWidget);
    expect(find.text('Show position in ranking'), findsOneWidget);
    expect(find.text('Night Transit'), findsWidgets);
    expect(find.text('Skyline Echo'), findsWidgets);
    expect(find.text('Glass Harbor'), findsWidgets);
  });
}

Future<void> _pumpRankings(WidgetTester tester) {
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
          () => _FixedHomeSectionController(HomeSection.rankings),
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
