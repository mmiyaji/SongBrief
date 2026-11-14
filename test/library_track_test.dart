import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_track.dart';

void main() {
  test('reads lyrics and playlist names from platform metadata', () {
    final track = LibraryTrack.fromPlatformMap({
      'id': '42',
      'title': 'Metadata Song',
      'artist': 'Metadata Artist',
      'albumTitle': 'Metadata Album',
      'durationSeconds': 180,
      'playCount': 12,
      'skipCount': 1,
      'isCloudItem': false,
      'appleMusicStoreId': '123456789',
      'releaseDateMillis': DateTime(2020, 1, 2).millisecondsSinceEpoch,
      'lyrics': '  line one\r\nline two\rline three  ',
      'playlistNames': ['Focus', '', 'Recently Played', 'Focus', 99],
    });

    expect(track.appleMusicStoreId, '123456789');
    expect(track.appleMusicUrl, isNull);
    expect(track.releaseDate, DateTime(2020, 1, 2));
    expect(track.lyrics, 'line one\nline two\nline three');
    expect(track.playlistNames, ['Focus', 'Recently Played']);
  });

  test('reads and preserves Apple Music URL from platform metadata', () {
    const url = 'https://music.apple.com/us/song/example/123456789';
    final track = LibraryTrack.fromPlatformMap({
      'id': '42',
      'title': 'Song',
      'artist': 'Artist',
      'albumTitle': 'Album',
      'appleMusicUrl': url,
    });

    expect(track.appleMusicUrl, url);
    expect(track.copyWith(playCount: 2).appleMusicUrl, url);
    expect(
      track
          .copyWith(appleMusicUrl: 'https://music.apple.com/song/other/2')
          .appleMusicUrl,
      'https://music.apple.com/song/other/2',
    );
  });
}
