import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_track.dart';

LibraryTrack track(String id, String title, String album) => LibraryTrack(
  id: id,
  title: title,
  artist: 'Artist',
  albumTitle: album,
  duration: const Duration(minutes: 3),
  playCount: 0,
  skipCount: 0,
  isCloudItem: true,
);

void main() {
  test(
    'history retains first representatives, album editions and unknown albums',
    () {
      final input = [
        track('1', ' Song ', ' Album '),
        track('alias', 'song', 'album'),
        track('edition', 'song', 'Live'),
        track('unknown', 'SONG', 'Unknown Album'),
        track('2', 'Other', ''),
        track('other-alias', 'other', 'New Album'),
        track('1', 'Changed metadata', 'Other'),
      ];
      expect(uniqueHistoryTracks(input).map((t) => t.id), [
        '1',
        'edition',
        '2',
      ]);
    },
  );

  test('indexed history agrees with metadata matching for mixed input', () {
    final input = List.generate(
      300,
      (i) => track('${i % 71}', 'Song ${i % 19}', switch (i % 4) {
        0 => '',
        1 => 'Unknown Album',
        _ => 'Album ${i % 3}',
      }),
    );
    final expected = <LibraryTrack>[];
    for (final item in input) {
      if (!expected.any((previous) => sameHistoryTrack(previous, item))) {
        expected.add(item);
      }
    }
    expect(uniqueHistoryTracks(input), orderedEquals(expected));
  });

  test('large library retains tail songs and merges catalog duplicates', () {
    final input = List.generate(20000, (i) => track('$i', 'Song $i', 'Album'));
    final result = uniqueHistoryTracks([
      ...input,
      track('musickit:last', 'Song 19999', 'Album'),
      track('musickit:outside', 'Outside', 'Album'),
    ]);
    expect(result, hasLength(20001));
    expect(result[19999].id, '19999');
    expect(result.last.id, 'musickit:outside');
  });
}
