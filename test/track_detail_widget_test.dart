import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';

void main() {
  testWidgets('shows playlist and lyrics metadata in track details', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: SongBriefApp()));
    await tester.pumpAndSettle();

    final skylineEcho = find.text('Skyline Echo');
    expect(skylineEcho, findsWidgets);

    await tester.tap(skylineEcho.last);
    await tester.pumpAndSettle();

    expect(find.text('Late Night Focus'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.textContaining('City lights are waking slow'), findsOneWidget);
  });
}
