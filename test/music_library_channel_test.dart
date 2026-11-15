import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/music_library_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.songbrief/music_library');
  const client = PlatformMusicLibraryClient();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'decodes large track payload off-isolate with metadata intact',
    () async {
      final lastPlayed = DateTime(2026, 7, 3, 8).millisecondsSinceEpoch;
      final rawTracks = <Object?>[
        for (var index = 0; index < 720; index++)
          <String, Object?>{
            'id': 'track-$index',
            'title': '夜の音楽 🎵 $index',
            'artist': 'アーティスト',
            'albumTitle': 'Album 漢字',
            'durationSeconds': 201,
            'playCount': index + 1,
            'skipCount': index % 7,
            'isCloudItem': index.isEven,
            'lastPlayedAtMillis': lastPlayed + index,
            'playlistNames': <String>['お気に入り', 'Playlist $index'],
          },
      ];
      rawTracks.insert(10, 'malformed row is skipped');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'fetchTracks');
            return rawTracks;
          });

      final tracks = await client.fetchTracks();

      expect(tracks, hasLength(720));
      expect(tracks[0].title, '夜の音楽 🎵 0');
      expect(tracks[0].artist, 'アーティスト');
      expect(tracks[0].playCount, 1);
      expect(tracks[0].skipCount, 0);
      expect(
        tracks[0].lastPlayedAt,
        DateTime.fromMillisecondsSinceEpoch(lastPlayed),
      );
      expect(tracks[0].playlistNames, ['Playlist 0', 'お気に入り']);
      expect(tracks.last.id, 'track-719');
    },
  );
}
