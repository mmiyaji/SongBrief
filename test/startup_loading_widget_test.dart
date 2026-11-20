import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_load_progress.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('phone navigation stays hidden until ready and is reused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ready = Completer<MusicStatsState>();
    await _pumpLoading(tester, ready);
    expect(find.byType(NavigationBar), findsNothing);
    final prepared = find
        .byType(NavigationBar, skipOffstage: false)
        .evaluate()
        .single;
    final preparedWidget = prepared.widget;
    ready.complete(_loadedState());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      identical(find.byType(NavigationBar).evaluate().single, prepared),
      isTrue,
    );
    expect(
      identical(
        tester.widget<NavigationBar>(find.byType(NavigationBar)),
        preparedWidget,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading keeps static copy stable and hands off without a ticker',
    (tester) async {
      final ready = Completer<MusicStatsState>();
      await _pumpLoading(tester, ready);
      final message = find.text('Reading your library');
      expect(message, findsOneWidget);
      final copy = tester.widget<Text>(message);
      await tester.pump(const Duration(milliseconds: 120));
      expect(identical(tester.widget<Text>(message), copy), isTrue);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      ready.complete(_loadedState());
      await tester.pumpAndSettle();
      expect(message, findsNothing);
      expect(find.text('SongBrief'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion stops the loading ticker while data is pending', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpLoading(tester, Completer<MusicStatsState>());
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Reading your library'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading stage wraps and identifies completed stages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 690);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpLoading(tester, Completer<MusicStatsState>());
    final container = ProviderScope.containerOf(
      tester.element(find.text('Reading your library')),
    );
    container
        .read(libraryLoadProgressProvider.notifier)
        .report(
          const LibraryLoadProgress(
            stage: LibraryLoadStage.loadingHistory,
            step: 5,
            totalSteps: 5,
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final label = tester.widget<Text>(
      find.text('Loading your listening history'),
    );
    expect(label.maxLines, isNull);
    expect(label.overflow, isNot(TextOverflow.ellipsis));
    expect(find.text('4 of 5 stages complete'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.8,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Playing and navigation while history is pending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ready = Completer<MusicStatsState>();
    await _pumpLoading(tester, ready);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Reading your library')),
    );
    container.read(startupOverviewProvider.notifier).publish(_loadedState());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Startup song'), findsWidgets);
    expect(find.text('Reading your library'), findsNothing);

    container
        .read(homeSectionProvider.notifier)
        .setSection(HomeSection.overview);
    await tester.pump();
    expect(find.text('Reading your library'), findsOneWidget);
    ready.complete(_loadedState());
    await tester.pumpAndSettle();
    expect(find.text('Reading your library'), findsNothing);
    expect(container.read(homeSectionProvider), HomeSection.overview);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLoading(
  WidgetTester tester,
  Completer<MusicStatsState> ready,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicStatsControllerProvider.overrideWith(() => _PendingStats(ready)),
        appLanguageProvider.overrideWith(_English.new),
      ],
      child: const SongBriefApp(),
    ),
  );
  await tester.pump();
}

MusicStatsState _loadedState() => MusicStatsState(
  authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
  overview: LibraryOverview.fromTracks(const [
    LibraryTrack(
      id: 'startup',
      title: 'Startup song',
      artist: 'Sample artist',
      albumTitle: 'Sample album',
      duration: Duration(minutes: 3),
      playCount: 12,
      skipCount: 1,
      isCloudItem: false,
    ),
  ], isDemo: true),
  snapshotHistory: SnapshotHistory.empty,
);

class _PendingStats extends MusicStatsController {
  _PendingStats(this.ready);
  final Completer<MusicStatsState> ready;
  @override
  Future<MusicStatsState> build() => ready.future;
}

class _English extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
