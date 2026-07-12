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
    expect(track.releaseDate, DateTime(2020, 1, 2));
    expect(track.lyrics, 'line one\nline two\nline three');
    expect(track.playlistNames, ['Focus', 'Recently Played']);
  });
}
