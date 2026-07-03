import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/apple_music_link.dart';
import 'package:songbrief/src/domain/library_track.dart';

void main() {
  test('builds a direct Apple Music song URL when a catalog id exists', () {
    final track = _track(
      title: 'Blinding Lights',
      appleMusicStoreId: '1488408568',
    );

    expect(hasAppleMusicSongLink(track), isTrue);
    expect(
      appleMusicUrlForTrack(track).toString(),
      'https://music.apple.com/song/blinding-lights/1488408568',
    );
  });

  test('falls back to Apple Music search when a catalog id is missing', () {
    final track = _track(title: 'Local Song');
    final url = appleMusicUrlForTrack(track);

    expect(hasAppleMusicSongLink(track), isFalse);
    expect(url.path, '/search');
    expect(url.queryParameters['term'], 'Local Song Artist Album');
  });

  test('treats zero catalog ids as missing', () {
    final track = _track(title: 'Unknown Store Song', appleMusicStoreId: '0');

    expect(hasAppleMusicSongLink(track), isFalse);
    expect(appleMusicUrlForTrack(track).path, '/search');
  });
}

LibraryTrack _track({required String title, String? appleMusicStoreId}) {
  return LibraryTrack(
    id: 'track-$title',
    title: title,
    artist: 'Artist',
    albumTitle: 'Album',
    appleMusicStoreId: appleMusicStoreId,
    duration: const Duration(minutes: 3),
    playCount: 1,
    skipCount: 0,
    isCloudItem: false,
  );
}
