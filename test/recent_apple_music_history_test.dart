import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/features/home/home_controller.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';
import 'package:songbrief/src/settings/music_data_preferences_storage.dart';

LibraryTrack song(
  String id, {
  String title = 'Outside',
  int count = 0,
  String album = 'Album',
}) => LibraryTrack(
  id: id,
  title: title,
  artist: 'Artist',
  albumTitle: album,
  duration: const Duration(minutes: 3),
  playCount: count,
  skipCount: count,
  isCloudItem: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'platform maps all returned pages without inventing dates or counters',
    () async {
      const channel = MethodChannel('app.songbrief/music_library');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'fetchRecentlyPlayedTracks');
            return [
              for (var i = 0; i < 120; i++)
                {
                  'id': 'musickit:$i',
                  'title': 'Song $i',
                  'artist': 'Artist',
                  'playCount': 99,
                  'skipCount': 4,
                  if (i == 0) 'lastPlayedAtMillis': 1760000000000,
                },
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final tracks = await const PlatformMusicLibraryClient()
          .fetchRecentlyPlayedTracks();
      expect(tracks, hasLength(120));
      expect(tracks.every((t) => t.playCount == 0 && t.skipCount == 0), isTrue);
      expect(tracks.first.lastPlayedAt, isNotNull);
      expect(tracks.last.lastPlayedAt, isNull);
    },
  );

  test(
    'requests coalesce and throttle; metadata dedupes with zero counters',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = HistoryRepository();
      final container = ProviderContainer(
        overrides: [
          musicStatsRepositoryProvider.overrideWithValue(repository),
          musicDataSharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(recentAppleMusicPlaysProvider.notifier);
      final first = controller.refresh();
      final second = controller.refresh();
      expect(identical(first, second), isTrue);
      expect(repository.requests, 1);
      repository.pending.complete([
        song('musickit:1', count: 99),
        song('other-id'),
        song('different-album', album: 'Second Album'),
      ]);
      await first;
      await controller.refresh();
      expect(repository.requests, 1);
      final tracks = container.read(recentAppleMusicPlaysProvider);
      expect(tracks, hasLength(2));
      expect(tracks.every((t) => t.playCount == 0 && t.skipCount == 0), isTrue);
      expect(tracks.every((t) => t.lastPlayedAt == null), isTrue);
      final stored = jsonDecode(
        preferences.getString(recentAppleMusicPlaysPreferenceKey)!,
      );
      expect(stored.first['lastPlayedAtMillis'], isNull);

      // Reopening restores the independent cache; failed requests retain it.
      final reopened = ProviderContainer(
        overrides: [
          musicStatsRepositoryProvider.overrideWithValue(repository),
          musicDataSharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(reopened.dispose);
      repository.pending = Completer<List<LibraryTrack>>();
      final restored = reopened.read(recentAppleMusicPlaysProvider.notifier);
      expect(reopened.read(recentAppleMusicPlaysProvider), hasLength(2));
      final failed = restored.refresh();
      repository.pending.completeError(
        PlatformException(code: 'music_kit_not_configured'),
      );
      await failed;
      expect(reopened.read(recentAppleMusicPlaysProvider), hasLength(2));
      expect(restored.lastError, isA<PlatformException>());
    },
  );

  test('newer service date supersedes an older observed duplicate', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = HistoryRepository();
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container
        .read(outsideLibraryPlaysProvider.notifier)
        .record(song('observed'), at: DateTime(2025));
    final request = container
        .read(recentAppleMusicPlaysProvider.notifier)
        .refresh();
    repository.pending.complete([
      song('musickit:newer').copyWith(lastPlayedAt: DateTime(2026)),
    ]);
    await request;
    expect(
      container.read(visibleOutsideLibraryPlaysProvider).single.id,
      'musickit:newer',
    );
    await container.read(musicStatsControllerProvider.future);
  });

  test('library and excluded history stay out; observed duplicates merge and stats stay unchanged', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = HistoryRepository();
    final catalog = LibraryTrackCatalog()
      ..replace([song('library', title: 'Library', count: 8)]);
    repository.catalog = catalog;
    final container = ProviderContainer(
      overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(musicStatsControllerProvider.future);
    container
        .read(libraryFilterPreferencesProvider.notifier)
        .addExcludedKeyword('Blocked');
    container
        .read(outsideLibraryPlaysProvider.notifier)
        .record(song('observed'));
    final controller = container.read(recentAppleMusicPlaysProvider.notifier);
    final pending = controller.refresh();
    repository.pending.complete([
      song('musickit:library', title: 'Library'),
      song('musickit:outside', count: 99),
      song('musickit:blocked', title: 'Blocked song'),
    ]);
    await pending;
    final visible = container.read(visibleOutsideLibraryPlaysProvider);
    expect(visible.map((t) => t.id), ['observed']);
    final stats = container.read(musicStatsControllerProvider).requireValue;
    expect(stats.overview.totalTracks, 1);
    expect(stats.overview.totalPlayCount, 8);
    expect(stats.snapshotHistory.snapshots, isEmpty);
  });
}

class HistoryRepository extends MusicStatsRepository {
  HistoryRepository()
    : super(const PlatformMusicLibraryClient(), LibrarySnapshotRepository());
  var requests = 0;
  var pending = Completer<List<LibraryTrack>>();
  LibraryTrackCatalog? catalog;
  @override
  Future<List<LibraryTrack>> fetchRecentlyPlayedTracks() {
    requests++;
    return pending.future;
  }

  @override
  LibraryTrack? libraryTrackMatching(LibraryTrack track) =>
      catalog?.match(track);
  @override
  Future<MusicStatsState> load({bool requestAccess = false}) async =>
      MusicStatsState(
        authorizationStatus: MusicLibraryAuthorizationStatus.authorized,
        overview: LibraryOverview.fromTracks([
          song('library', title: 'Library', count: 8),
        ], isDemo: false),
        snapshotHistory: SnapshotHistory.empty,
      );
  @override
  Future<SnapshotSyncResult?> syncCloudSnapshots() async => null;
  @override
  Future<MusicPlaybackSnapshot?> currentPlayback() async => null;
  @override
  Stream<MusicPlaybackSnapshot> playbackEvents() => const Stream.empty();
}
