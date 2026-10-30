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

  test('prefers a validated official Apple Music track URL', () {
    final track = _track(
      title: 'Local Song',
      appleMusicStoreId: '123',
      appleMusicUrl: 'https://music.apple.com/us/song/song-title/987654321',
    );
    expect(hasAppleMusicSongLink(track), isTrue);
    expect(appleMusicUrlForTrack(track).toString(), track.appleMusicUrl);
  });

  test('accepts Apple Music song and album track canonical URLs', () {
    for (final url in [
      'https://music.apple.com/jp/song/123456789',
      'https://music.apple.com/jp/album/album-title/111111111?i=123456789',
    ]) {
      final track = _track(title: 'Song', appleMusicUrl: url);
      expect(hasAppleMusicSongLink(track), isTrue, reason: url);
      expect(appleMusicUrlForTrack(track).toString(), url);
    }
  });

  test('rejects arbitrary hosts, credentials, and search URLs', () {
    for (final url in [
      'https://evil.example/song/title/123',
      'https://user@music.apple.com/song/title/123',
      'https://music.apple.com/search?term=title',
      'http://music.apple.com/song/title/123',
    ]) {
      final track = _track(title: 'Local Song', appleMusicUrl: url);
      expect(hasAppleMusicSongLink(track), isFalse, reason: url);
      expect(appleMusicUrlForTrack(track).path, '/search', reason: url);
    }
  });

  test('rejects library ids and accepts numeric catalog IDs', () {
    for (final id in ['i.123456', 'musickit:abc', '0', '']) {
      final track = _track(title: 'Local Song', appleMusicStoreId: id);
      expect(hasAppleMusicSongLink(track), isFalse, reason: id);
    }
    final numeric = _track(title: 'Song', appleMusicStoreId: '123456');
    expect(hasAppleMusicSongLink(numeric), isTrue);
    expect(appleMusicUrlForTrack(numeric).path, '/song/song/123456');
    final padded = _track(title: 'Song', appleMusicStoreId: '000123456');
    expect(appleMusicUrlForTrack(padded).path, '/song/song/123456');
  });
}

LibraryTrack _track({
  required String title,
  String? appleMusicStoreId,
  String? appleMusicUrl,
}) {
  return LibraryTrack(
    id: 'track-$title',
    title: title,
    artist: 'Artist',
    albumTitle: 'Album',
    appleMusicStoreId: appleMusicStoreId,
    appleMusicUrl: appleMusicUrl,
    duration: const Duration(minutes: 3),
    playCount: 1,
    skipCount: 0,
    isCloudItem: false,
  );
}
