import 'package:flutter/material.dart';
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
import 'package:songbrief/src/features/home/recent_listening_provider.dart';
import 'package:songbrief/src/settings/app_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

void main() {
  testWidgets(
    'library songs include supplemental history without native stats',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final native = _track('native', 'Gyakko', plays: 8, skips: 3);
      final outside = _track(
        'outside:stay-away',
        'STAY AWAY',
        plays: 3,
        skips: 0,
        at: DateTime(2026, 10, 30),
      );
      final nativeOverview = LibraryOverview.fromTracks([
        native,
      ], isDemo: false);
      final stats = MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: nativeOverview,
        snapshotHistory: SnapshotHistory.empty,
      );
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          musicDataSharedPreferencesProvider.overrideWithValue(preferences),
          musicStatsControllerProvider.overrideWith(() => _FixedStats(stats)),
          librarySupplementalTracksProvider.overrideWithValue([outside]),
          trackArtworkProvider.overrideWith((ref, id) async => null),
          trackLyricsProvider.overrideWith((ref, id) async => null),
          appLanguageProvider.overrideWith(_English.new),
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
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      final rows = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_LibraryTrackRow',
      );
      expect(rows, findsNWidgets(2));
      expect(find.text('Gyakko'), findsAtLeastNWidgets(1));
      expect(find.text('STAY AWAY'), findsAtLeastNWidgets(1));
      expect(
        find.textContaining('Supplemental · 3 plays (minimum)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 library tracks · 1 supplemental history tracks'),
        findsOneWidget,
      );
      final supplementalRow = find.ancestor(
        of: find.text('STAY AWAY').first,
        matching: rows,
      );
      expect(
        find.descendant(
          of: supplementalRow,
          matching: find.byTooltip('Open or search in Apple Music'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: supplementalRow, matching: find.byTooltip('Play')),
        findsNothing,
      );
      expect(container.read(libraryRecentOverviewProvider).totalPlayCount, 8);
      expect(container.read(libraryRecentOverviewProvider).totalSkipCount, 3);

      await tester.enterText(find.byType(TextField).first, 'STAY');
      await tester.pumpAndSettle();
      expect(rows, findsOneWidget);
      expect(find.text('STAY AWAY'), findsAtLeastNWidgets(1));
      expect(
        find.descendant(of: rows, matching: find.text('Gyakko')),
        findsNothing,
      );
    },
  );
}

LibraryTrack _track(
  String id,
  String title, {
  required int plays,
  required int skips,
  DateTime? at,
}) => LibraryTrack(
  id: id,
  title: title,
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(minutes: 3),
  playCount: plays,
  skipCount: skips,
  isCloudItem: false,
  lastPlayedAt: at,
);

class _FixedStats extends MusicStatsController {
  _FixedStats(this.stats);
  final MusicStatsState stats;
  @override
  Future<MusicStatsState> build() async => stats;
}

class _English extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}
