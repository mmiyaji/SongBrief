import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/snapshot_preferences.dart';

void main() {
  const sizes = <Size>[
    Size(320, 690),
    Size(466, 678),
    Size(466, 1000),
    Size(560, 800),
    Size(669, 951),
    Size(720, 800),
    Size(760, 900),
    Size(951, 669),
  ];

  for (final size in sizes) {
    for (final section in HomeSection.values) {
      testWidgets(
        'lays out ${section.name} at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await _pumpAt(tester, size, section);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final section in HomeSection.values) {
    testWidgets('lays out ${section.name} with asymmetric safe area', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        const Size(951, 669),
        section,
        padding: const FakeViewPadding(left: 0, right: 44, top: 0, bottom: 21),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  HomeSection section, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _FixedLanguageController(AppLanguage.english),
        ),
        snapshotRecordingProvider.overrideWith(
          () => _FixedSnapshotRecordingController(true),
        ),
      ],
      child: const SongBriefApp(),
    ),
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(SongBriefApp)),
  ).read(homeSectionProvider.notifier).setSection(section);
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FixedLanguageController extends AppLanguageController {
  _FixedLanguageController(this.language);

  final AppLanguage language;

  @override
  AppLanguage build() => language;
}

class _FixedSnapshotRecordingController extends SnapshotRecordingController {
  _FixedSnapshotRecordingController(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}
