import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';

void main() {
  testWidgets(
    'denied Music access opens iOS Settings instead of requesting again',
    (tester) async {
      final controller = _FixedStatsController(
        _emptyState(MusicLibraryAuthorizationStatus.denied),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            musicStatsControllerProvider.overrideWith(() => controller),
          ],
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();

      expect(controller.openSettingsCalls, 1);
    },
  );

  testWidgets('restricted Music access does not show an unusable action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicStatsControllerProvider.overrideWith(
            () => _FixedStatsController(
              _emptyState(MusicLibraryAuthorizationStatus.restricted),
            ),
          ),
        ],
        child: const SongBriefApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Music access is restricted on this device.'), findsOne);
    expect(find.text('Open Settings'), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('load failure provides a working retry action', (tester) async {
    final controller = _FailingStatsController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicStatsControllerProvider.overrideWith(() => controller),
        ],
        child: const SongBriefApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load the music library.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(controller.refreshCalls, 1);
  });
}

MusicStatsState _emptyState(MusicLibraryAuthorizationStatus status) {
  return MusicStatsState(
    authorizationStatus: status,
    overview: LibraryOverview.empty(isDemo: false),
    snapshotHistory: SnapshotHistory.empty,
  );
}

class _FixedStatsController extends MusicStatsController {
  _FixedStatsController(this.value);

  final MusicStatsState value;
  int openSettingsCalls = 0;

  @override
  Future<MusicStatsState> build() async => value;

  @override
  Future<bool> openMusicSettings() async {
    openSettingsCalls += 1;
    return true;
  }
}

class _FailingStatsController extends MusicStatsController {
  int refreshCalls = 0;

  @override
  Future<MusicStatsState> build() => Future.error(StateError('load failed'));

  @override
  Future<void> refreshStats() async {
    refreshCalls += 1;
  }
}
