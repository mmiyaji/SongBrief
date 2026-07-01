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
      'lyrics': '  line one\nline two  ',
      'playlistNames': ['Focus', '', 'Recently Played', 'Focus', 99],
    });

    expect(track.lyrics, 'line one\nline two');
    expect(track.playlistNames, ['Focus', 'Recently Played']);
  });
}
