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
import 'package:songbrief/src/features/home/recent_listening_provider.dart';
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

  testWidgets('loading shows one wrapping message for the current stage', (
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
    expect(find.text('Reading your library'), findsNothing);
    expect(find.textContaining('stages complete'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tablet tabs keep their headings and safe controls while loading',
    (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ready = Completer<MusicStatsState>();
      final library = Completer<LibraryTabOverview>();
      await _pumpLoading(tester, ready, library: library);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Reading your library')),
      );
      container.read(startupOverviewProvider.notifier).publish(_loadedState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Startup song'), findsWidgets);
      expect(find.text('Reading your library'), findsNothing);
      expect(find.text('Listening trend'), findsOneWidget);
      expect(find.text('Loading your listening history'), findsOneWidget);
      final sections = container.read(homeSectionProvider.notifier);
      sections.setSection(HomeSection.overview);
      await tester.pump();
      expect(find.text('Daily listening records'), findsOneWidget);
      expect(find.text('Listening record trend'), findsOneWidget);
      expect(find.textContaining('first listening record'), findsNothing);

      sections.setSection(HomeSection.rankings);
      container
          .read(rankingScopeProvider.notifier)
          .setScope(RankingScope.recent);
      await tester.pump();
      final scopes = find.byType(SegmentedButton<RankingScope>);
      expect(
        tester.widget<SegmentedButton<RankingScope>>(scopes).onSelectionChanged,
        isNotNull,
      );
      expect(find.text('Recently Played'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      sections.setSection(HomeSection.settings);
      await tester.pump();
      expect(find.text('Theme'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-category-history')));
      await tester.pump();
      final records = find.widgetWithText(OutlinedButton, 'Manage records');
      expect(tester.widget<OutlinedButton>(records).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('settings-category-export')));
      await tester.pump();
      final caches = find.widgetWithText(OutlinedButton, 'Manage caches');
      expect(tester.widget<OutlinedButton>(caches).onPressed, isNotNull);
      await tester.tap(
        find.byKey(const ValueKey('settings-category-appearance')),
      );
      await tester.pump();
      await tester.tap(find.text('Theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(BottomSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      sections.setSection(HomeSection.library);
      await tester.pump();
      final search = find.byType(TextField);
      expect(tester.widget<TextField>(search).enabled, isFalse);
      final searchTop = tester.getTopLeft(search);
      ready.complete(_loadedState());
      await tester.pump();
      expect(tester.widget<TextField>(search).enabled, isFalse);
      expect(tester.getTopLeft(search), searchTop);
      final overview = _loadedState().overview;
      library.complete((
        overview: overview,
        songsOverview: overview,
        supplementalTrackIds: <String>{},
      ));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).enabled, isTrue);
      expect(find.text('Startup song'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tab skeleton animates after a delay and respects reduced motion',
    (tester) async {
      final ready = Completer<MusicStatsState>();
      await _pumpLoading(tester, ready);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Reading your library')),
      );
      container.read(startupOverviewProvider.notifier).publish(_loadedState());
      container
          .read(homeSectionProvider.notifier)
          .setSection(HomeSection.rankings);
      container
          .read(rankingScopeProvider.notifier)
          .setScope(RankingScope.recent);
      await tester.pump();
      final status = find.text('Loading your listening history');
      final rows = find
          .byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_SkeletonRows',
          )
          .first;
      final waveMask = find.ancestor(
        of: rows,
        matching: find.byType(ShaderMask),
      );
      final wave = find
          .ancestor(of: waveMask, matching: find.byType(AnimatedBuilder))
          .first;
      double statusOpacity() => tester
          .widget<Opacity>(
            find.ancestor(of: status, matching: find.byType(Opacity)).first,
          )
          .opacity;
      await tester.pump(const Duration(milliseconds: 350));
      expect(waveMask, findsNothing);
      expect(statusOpacity(), 0.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(waveMask, findsOneWidget);
      expect(statusOpacity(), 0.0);
      final phase =
          tester.widget<AnimatedBuilder>(wave).listenable as Animation<double>;
      final initialPhase = phase.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(phase.value, greaterThan(initialPhase));
      expect(statusOpacity(), 0.0);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(statusOpacity(), 1.0);
      expect(tester.getCenter(status).dy, lessThan(tester.getTopLeft(rows).dy));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      expect(waveMask, findsNothing);
      expect(statusOpacity(), 1.0);
      ready.complete(_loadedState());
      await tester.pumpAndSettle();
      expect(status, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpLoading(
  WidgetTester tester,
  Completer<MusicStatsState> ready, {
  Completer<LibraryTabOverview>? library,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicStatsControllerProvider.overrideWith(() => _PendingStats(ready)),
        appLanguageProvider.overrideWith(_English.new),
        if (library != null)
          libraryTabOverviewProvider.overrideWith((ref) => library.future),
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
