import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  testWidgets('shows the SongBrief dashboard shell in English', (tester) async {
    await _pumpApp(tester, AppLanguage.english);
    await tester.pumpAndSettle();

    expect(find.text('SongBrief'), findsOneWidget);
    expect(find.text('Skyline Echo'), findsWidgets);
    expect(find.text('Plays'), findsWidgets);
    expect(find.text('This week trend'), findsOneWidget);
    expect(find.text('Recently played songs'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('shows the SongBrief dashboard shell in Japanese', (
    tester,
  ) async {
    await _pumpApp(tester, AppLanguage.japanese);
    await tester.pumpAndSettle();

    expect(find.text('SongBrief'), findsOneWidget);
    expect(find.text('Skyline Echo'), findsWidgets);
    expect(find.text('再生回数'), findsWidgets);
    expect(find.text('今週の傾向'), findsOneWidget);
    expect(find.text('最近再生した曲'), findsOneWidget);
    expect(find.text('デモ'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, AppLanguage language) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(language),
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
