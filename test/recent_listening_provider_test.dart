import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';
import 'package:songbrief/src/features/home/recent_listening_provider.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';

LibraryTrack song(
  String id, {
  String title = 'Gyakko',
  String? storeId,
  int count = 12,
  int skips = 2,
  DateTime? at,
}) => LibraryTrack(
  id: id,
  title: title,
  artist: 'Artist',
  albumTitle: 'Album',
  appleMusicStoreId: storeId,
  duration: const Duration(minutes: 4),
  playCount: count,
  skipCount: skips,
  isCloudItem: false,
  lastPlayedAt: at,
);

LibraryOverview overview(List<LibraryTrack> tracks) =>
    LibraryOverview.fromTracks(tracks, isDemo: false);

DailyLibrarySnapshot snapshot(
  DateTime at,
  List<LibraryTrack> tracks, {
  String source = 'background',
  String? signature,
}) => DailyLibrarySnapshot.fromOverview(
  overview(tracks),
  capturedAt: at,
  source: source,
  filterSignature: signature,
);

void main() {
  final old = DateTime(2026, 10, 28, 20);
  final yesterday = DateTime(2026, 10, 29, 21);
  final today = DateTime(2026, 10, 30, 14);

  test('5500 tracks and 90 detailed days use bounded indexed projection', () {
    final tracks = [
      for (var id = 0; id < 5500; id++) song('$id', title: 'Song $id'),
    ];
    final counters = tracks.map(TrackCounterSnapshot.fromTrack).toList();
    final updated = tracks
        .map(
          (track) =>
              TrackCounterSnapshot.fromTrack(track.copyWith(playCount: 13)),
        )
        .toList();
    final history = SnapshotHistory(
      snapshots: [
        for (var day = 0; day < 90; day++)
          DailyLibrarySnapshot(
            dateKey: snapshotDateKey(today.subtract(Duration(days: 89 - day))),
            capturedAt: today.subtract(Duration(days: 89 - day)),
            source: 'background',
            trackCount: tracks.length,
            totalPlayCount: tracks.length * (day == 89 ? 13 : 12),
            totalSkipCount: 0,
            totalListeningSeconds: 0,
            tracks: day == 89 ? updated : counters,
          ),
      ],
    );
    final native = overview(tracks);
    final timer = Stopwatch()..start();
    final result = buildRecentListeningEvidence(
      nativeOverview: native,
      snapshotHistory: history,
    );
    timer.stop();
    // Diagnostic output avoids a machine-speed-dependent timing assertion.
    // ignore: avoid_print
    print(
      '5500 tracks / 90 snapshots projection: ${timer.elapsedMilliseconds}ms',
    );
    expect(result.tracks, hasLength(5500));
    expect(result.tracks.every((track) => track.lastPlayedAt == today), isTrue);
    expect(result.libraryOverview.totalPlayCount, native.totalPlayCount);
  });

  test('positive daily native counter evidence repairs stale recency only', () {
    final native = song('native', at: old);
    final original = overview([native]);
    final history = SnapshotHistory(
      snapshots: [
        snapshot(yesterday, [native.copyWith(playCount: 11)]),
        snapshot(today, [native], source: 'cloud'),
      ],
    );
    final result = buildRecentListeningEvidence(
      nativeOverview: original,
      snapshotHistory: history,
    );
    final row = result.tracks.single;
    expect(row.lastPlayedAt, today);
    expect(row.lastPlayedAtIsObservation, isTrue);
    expect(row.playCount, 12);
    expect(row.skipCount, 2);
    expect(
      result.libraryOverview.totalListeningSeconds,
      original.totalListeningSeconds,
    );
    expect(native.lastPlayedAt, old);
    expect(history.latest!.tracks.single.lastPlayedAt, old);
  });

  test(
    'newer real timestamps win and matching history keeps native metadata',
    () {
      final native = song('native', storeId: '123', at: old);
      final actual = today.add(const Duration(hours: 1));
      final result = buildRecentListeningEvidence(
        nativeOverview: overview([native]),
        recentTracks: [
          song(
            'service',
            title: 'Different metadata',
            storeId: '123',
            count: 0,
            at: actual,
          ),
        ],
        snapshotHistory: SnapshotHistory(
          snapshots: [
            snapshot(yesterday, [native.copyWith(playCount: 11)]),
            snapshot(today, [native]),
          ],
        ),
      );
      expect(result.tracks.single.id, 'native');
      expect(result.tracks.single.title, 'Gyakko');
      expect(result.tracks.single.playCount, 12);
      expect(result.tracks.single.lastPlayedAt, actual);
      expect(result.tracks.single.lastPlayedAtIsObservation, isFalse);
    },
  );

  test('fresh exact playback within a daily interval beats capture time', () {
    final actual = today.subtract(const Duration(hours: 2));
    final native = song('native', at: old);
    final result = buildRecentListeningEvidence(
      nativeOverview: overview([native]),
      snapshotHistory: SnapshotHistory(
        snapshots: [
          snapshot(yesterday, [native.copyWith(playCount: 11)]),
          snapshot(today, [native.copyWith(lastPlayedAt: actual)]),
        ],
      ),
    );
    expect(result.tracks.single.lastPlayedAt, actual);
    expect(result.tracks.single.lastPlayedAtIsObservation, isFalse);
    final missing = song('native');
    final fallback = buildRecentListeningEvidence(
      nativeOverview: overview([missing]),
      snapshotHistory: SnapshotHistory(
        snapshots: [
          snapshot(yesterday, [missing.copyWith(playCount: 11)]),
          snapshot(today, [missing]),
        ],
      ),
    );
    expect(fallback.tracks.single.lastPlayedAt, today);
    expect(fallback.tracks.single.lastPlayedAtIsObservation, isTrue);
  });

  test('skip-only, resets, unmatched additions, gaps and filter changes invent no dates', () {
    final native = song('native');
    for (final history in [
      SnapshotHistory(
        snapshots: [
          snapshot(yesterday, [native]),
          snapshot(today, [native.copyWith(skipCount: 9)]),
        ],
      ),
      SnapshotHistory(
        snapshots: [
          snapshot(yesterday, [native]),
          snapshot(today, [native.copyWith(playCount: 1)]),
        ],
      ),
      SnapshotHistory(
        snapshots: [
          snapshot(yesterday, [song('other')]),
          snapshot(today, [native]),
        ],
      ),
      SnapshotHistory(
        snapshots: [
          snapshot(old, [native]),
          snapshot(today, [native.copyWith(playCount: 13)]),
        ],
      ),
      SnapshotHistory(
        snapshots: [
          snapshot(yesterday, [native], signature: 'a'),
          snapshot(today, [native.copyWith(playCount: 13)], signature: 'b'),
        ],
      ),
    ]) {
      final result = buildRecentListeningEvidence(
        nativeOverview: overview([native]),
        snapshotHistory: history,
      );
      expect(result.tracks, isEmpty);
      expect(result.libraryOverview.tracks.single.lastPlayedAt, isNull);
    }
  });

  test(
    'observations require timestamps; ledger and real times retain precision',
    () {
      final native = song('native', at: old);
      final observed = song('observed', at: today);
      final result = buildRecentListeningEvidence(
        nativeOverview: overview([native]),
        recentTracks: [song('undated')],
        observedTracks: [observed],
      );
      expect(result.tracks.single.id, 'native');
      expect(result.tracks.single.lastPlayedAt, today);
      expect(result.tracks.single.lastPlayedAtIsObservation, isTrue);
      final ledger = buildRecentListeningEvidence(
        nativeOverview: overview([native]),
        supplementalEvents: [
          SupplementalListeningEvent(track: song('service'), playedAt: today),
        ],
      );
      expect(ledger.tracks.single.lastPlayedAt, today);
      expect(ledger.tracks.single.lastPlayedAtIsObservation, isFalse);
    },
  );

  test(
    'outside rows keep supplemental counts, observation flags and API order',
    () {
      final observed = song('outside', title: 'Outside', at: today, count: 1);
      final result = buildRecentListeningEvidence(
        nativeOverview: overview([song('native', at: old)]),
        visibleOutsideTracks: [
          observed,
          song('undated', title: 'Undated', count: 3),
        ],
        observedTracks: [observed],
      );
      expect(result.libraryOverview.totalTracks, 1);
      expect(result.tracks.map((track) => track.id), [
        'outside',
        'native',
        'undated',
      ]);
      expect(result.tracks.first.playCount, 1);
      expect(result.tracks.first.lastPlayedAtIsObservation, isTrue);
      expect(result.tracks.last.lastPlayedAt, isNull);
    },
  );

  test('unfiltered library matches suppress excluded rows without outside fallback', () {
    final excluded = song('native', storeId: '123');
    final catalog = LibraryTrackCatalog()..replace([excluded]);
    final alias = song('service', storeId: '123', at: today);
    final result = buildRecentListeningEvidence(
      nativeOverview: overview([]),
      recentTracks: [alias],
      visibleOutsideTracks: [alias],
      libraryTrackMatching: catalog.match,
      filters: LibraryFilterPreferences(excludedKeywords: ['Gyakko']),
    );
    expect(result.libraryOverview.tracks, isEmpty);
    expect(result.tracks, isEmpty);
  });

  test(
    'all detailed history is usable and actual evidence wins timestamp ties',
    () {
      final native = song('native', at: old);
      final result = buildRecentListeningEvidence(
        nativeOverview: overview([native]),
        snapshotHistory: SnapshotHistory(
          snapshots: [
            snapshot(yesterday, [native.copyWith(playCount: 11)]),
            snapshot(today, [native]),
            for (var day = 1; day <= 90; day++)
              snapshot(today.add(Duration(days: day)), [native]),
          ],
        ),
        recentTracks: [song('service', at: today)],
        observedTracks: [song('observed', at: today)],
      );
      expect(result.tracks.single.lastPlayedAt, today);
      expect(result.tracks.single.lastPlayedAtIsObservation, isFalse);
    },
  );
}
