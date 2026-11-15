import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/library_snapshot_store_channel.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelSnapshotStore.channelName);
  const store = MethodChannelSnapshotStore(channel: channel);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'loads summaries and recent detailed snapshots from native storage',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'loadLocalSnapshotHistory');
            expect(call.arguments, {
              'detailedLimit': detailedSnapshotHistoryEntries,
            });
            return <Object?>[
              _snapshotJson(
                capturedAt: DateTime(2026, 7, 2, 8),
                playCount: 2,
                includeTracks: false,
              ),
              _snapshotJson(
                capturedAt: DateTime(2026, 7, 3, 8),
                playCount: 3,
                includeTracks: true,
              ),
            ];
          });

      final history = await store.loadHistory();

      expect(history.snapshotCount, 2);
      expect(history.snapshots.first.dateKey, '2026-07-02');
      expect(history.snapshots.first.tracks, isEmpty);
      expect(history.latest?.dateKey, '2026-07-03');
      expect(history.latest?.tracks.single.id, 'track-1');
    },
  );

  test(
    'decodes large detailed history off-isolate and preserves its data',
    () async {
      final rawSnapshots = <Object?>[
        for (var index = 79; index >= 0; index--) _detailedSnapshot(index),
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => rawSnapshots);

      final history = await store.loadHistory();

      expect(history.snapshotCount, 80);
      expect(history.snapshots.first.dateKey, snapshotDateKey(DateTime(2026)));
      expect(
        history.latest?.dateKey,
        snapshotDateKey(DateTime(2026).add(const Duration(days: 79))),
      );
      expect(history.latest?.tracks.single.title, '夜の音楽 🎵 79');
      expect(history.latest?.tracks.single.artist, 'アーティスト');
      expect(history.latest?.tracks.single.playCount, 82);
      expect(history.latest?.tracks.single.skipCount, 79);
      expect(
        history.latest?.tracks.single.lastPlayedAt,
        DateTime(2026).add(const Duration(days: 79)),
      );
      expect(history.latest?.filterSignature, 'profile-日本語');
    },
  );

  test('offloads large track detail even with only two snapshots', () async {
    final rawSnapshots = <Object?>[
      _snapshotWithManyTracks(0, 350),
      _snapshotWithManyTracks(1, 350),
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => rawSnapshots);

    final history = await store.loadHistory();

    expect(history.snapshotCount, 2);
    expect(history.snapshots.first.tracks, hasLength(350));
    expect(history.snapshots.last.tracks, hasLength(350));
    expect(history.snapshots.last.tracks.first.title, '曲 🎼 0');
    expect(history.snapshots.last.tracks.first.playCount, 3);
    expect(
      history.snapshots.last.tracks.first.lastPlayedAt,
      DateTime(2026, 7, 3),
    );
  });

  test(
    'delegates write, cutoff deletion, and clear to native storage',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      final snapshot = DailyLibrarySnapshot.fromJson(
        _snapshotJson(
          capturedAt: DateTime(2026, 7, 3, 8),
          playCount: 3,
          includeTracks: true,
        ),
      );

      await store.writeSnapshot(snapshot);
      await store.deleteSnapshotsOlderThan(DateTime(2026, 7, 2, 23));
      await store.clearHistory();

      expect(calls.map((call) => call.method), [
        'writeLocalSnapshot',
        'deleteLocalSnapshots',
        'clearLocalSnapshotHistory',
      ]);
      final writeArguments = calls[0].arguments as Map<Object?, Object?>;
      expect(
        (writeArguments['snapshot'] as Map<Object?, Object?>)['dateKey'],
        '2026-07-03',
      );
      expect(calls[1].arguments, {'olderThanDateKey': '2026-07-02'});
      expect(calls[2].arguments, isNull);
    },
  );

  test('reports a failed native mutation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);

    await expectLater(
      store.clearHistory(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'snapshot_store_failed',
        ),
      ),
    );
  });
}

Map<String, Object?> _detailedSnapshot(int index) {
  final capturedAt = DateTime(2026).add(Duration(days: index));
  return <String, Object?>{
    'dateKey': snapshotDateKey(capturedAt),
    'capturedAtMillis': capturedAt.millisecondsSinceEpoch,
    'source': 'foreground',
    'trackCount': 1,
    'totalPlayCount': index + 3,
    'totalSkipCount': index,
    'totalListeningSeconds': (index + 3) * 201,
    'filterSignature': 'profile-日本語',
    'tracks': <Object?>[
      <String, Object?>{
        'id': 'track-$index',
        'title': '夜の音楽 🎵 $index',
        'artist': 'アーティスト',
        'albumTitle': 'Album 漢字',
        'playCount': index + 3,
        'skipCount': index,
        'listeningSeconds': (index + 3) * 201,
        'lastPlayedAtMillis': capturedAt.millisecondsSinceEpoch,
      },
    ],
  };
}

Map<String, Object?> _snapshotWithManyTracks(int dayOffset, int trackCount) {
  final capturedAt = DateTime(2026, 7, 2 + dayOffset);
  return <String, Object?>{
    'dateKey': snapshotDateKey(capturedAt),
    'capturedAtMillis': capturedAt.millisecondsSinceEpoch,
    'source': 'foreground',
    'trackCount': trackCount,
    'totalPlayCount': trackCount * 3,
    'totalSkipCount': 0,
    'totalListeningSeconds': trackCount * 540,
    'tracks': <Object?>[
      for (var index = 0; index < trackCount; index++)
        <String, Object?>{
          'id': 'large-$dayOffset-$index',
          'title': '曲 🎼 $index',
          'artist': '歌手',
          'albumTitle': 'アルバム',
          'playCount': 3,
          'skipCount': index,
          'listeningSeconds': 540,
          'lastPlayedAtMillis': capturedAt.millisecondsSinceEpoch,
        },
    ],
  };
}

Map<String, Object?> _snapshotJson({
  required DateTime capturedAt,
  required int playCount,
  required bool includeTracks,
}) {
  return <String, Object?>{
    'dateKey': snapshotDateKey(capturedAt),
    'capturedAtMillis': capturedAt.millisecondsSinceEpoch,
    'source': 'foreground',
    'trackCount': 1,
    'totalPlayCount': playCount,
    'totalSkipCount': 0,
    'totalListeningSeconds': playCount * 180,
    if (includeTracks)
      'tracks': <Object?>[
        <String, Object?>{
          'id': 'track-1',
          'title': 'Track',
          'artist': 'Artist',
          'albumTitle': 'Album',
          'playCount': playCount,
          'skipCount': 0,
          'listeningSeconds': playCount * 180,
        },
      ],
    'filterSignature': 'profile-a',
  };
}
