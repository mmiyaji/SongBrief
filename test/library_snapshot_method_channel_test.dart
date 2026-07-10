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
