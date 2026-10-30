import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/app_preferences.dart';

void main() {
  testWidgets(
    'trend reuses historical counters across ranges and player events',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final track = LibraryTrack(
        id: 'trend-track',
        title: 'Cached Trend Song',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: const Duration(minutes: 3),
        playCount: 10,
        skipCount: 0,
        lastPlayedAt: now,
        isCloudItem: false,
      );
      final counters = _CountingCounters([
        TrackCounterSnapshot.fromTrack(track.copyWith(playCount: 7)),
      ]);
      final previousDate = now.subtract(const Duration(days: 1));
      final stats = MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: LibraryOverview.fromTracks([track], isDemo: false),
        snapshotHistory: SnapshotHistory(
          snapshots: [
            DailyLibrarySnapshot(
              dateKey: snapshotDateKey(previousDate),
              capturedAt: previousDate,
              source: 'foreground',
              trackCount: 1,
              totalPlayCount: 7,
              totalSkipCount: 0,
              totalListeningSeconds: 1260,
              tracks: counters,
            ),
          ],
        ),
        snapshotRecordingEnabled: true,
      );
      final container = ProviderContainer(
        overrides: [
          musicStatsControllerProvider.overrideWith(
            () => _StatsController(stats),
          ),
          appLanguageProvider.overrideWith(_EnglishController.new),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SongBriefApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Listening trend'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      final initialReads = counters.reads;
      expect(initialReads, greaterThan(0));

      final selector = tester.widget<SegmentedButton<TrendRange>>(
        find.byType(SegmentedButton<TrendRange>),
      );
      selector.onSelectionChanged!({TrendRange.year});
      await tester.pumpAndSettle();
      expect(counters.reads, initialReads);

      container.read(playbackControllerProvider.notifier).state = PlaybackState(
        activeTrackId: track.id,
        nowPlaying: track,
        isPlaying: true,
      );
      await tester.pumpAndSettle();
      expect(counters.reads, initialReads);
      expect(find.text('3'), findsWidgets);
      final updatedCounters = _CountingCounters([
        TrackCounterSnapshot.fromTrack(track.copyWith(playCount: 9)),
      ]);
      final previousSnapshot = stats.snapshotHistory.snapshots.single;
      final updatedHistory = SnapshotHistory(
        snapshots: [
          DailyLibrarySnapshot(
            dateKey: previousSnapshot.dateKey,
            capturedAt: previousSnapshot.capturedAt,
            source: previousSnapshot.source,
            trackCount: 1,
            totalPlayCount: 9,
            totalSkipCount: 0,
            totalListeningSeconds: 1620,
            tracks: updatedCounters,
          ),
        ],
      );
      container.read(musicStatsControllerProvider.notifier).state = AsyncData(
        stats.withSnapshotHistory(updatedHistory),
      );
      await tester.pumpAndSettle();
      expect(updatedCounters.reads, greaterThan(0));
      expect(find.text('1'), findsWidgets);
      expect(find.text('3'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}

class _StatsController extends MusicStatsController {
  _StatsController(this.stats);
  final MusicStatsState stats;
  @override
  Future<MusicStatsState> build() async => stats;
}

class _EnglishController extends AppLanguageController {
  @override
  AppLanguage build() => AppLanguage.english;
}

class _CountingCounters extends ListBase<TrackCounterSnapshot> {
  _CountingCounters(this.values);
  final List<TrackCounterSnapshot> values;
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  TrackCounterSnapshot operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, TrackCounterSnapshot value) =>
      throw UnsupportedError('immutable');
}
