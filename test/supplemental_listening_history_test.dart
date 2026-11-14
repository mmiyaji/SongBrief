import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';

LibraryTrack track({
  String id = 'library',
  String? storeId,
  DateTime? date,
  String title = 'Song',
  String album = 'Album',
}) => LibraryTrack(
  id: id,
  title: title,
  artist: 'Artist',
  albumTitle: album,
  duration: const Duration(seconds: 180),
  playCount: 99,
  skipCount: 4,
  isCloudItem: true,
  appleMusicStoreId: storeId,
  lastPlayedAt: date,
);

void main() {
  final date = DateTime.utc(2026, 10, 1);

  test('official song URL survives enrichment, observation and storage', () {
    const url =
        'https://music.apple.com/jp/album/snow-drop/1536479227?i=1536479228';
    var ledger = const SupplementalListeningHistory.empty().ingest([
      track(storeId: '1536479228', date: date),
    ]);
    ledger = ledger.ingest([
      track(storeId: '1536479228', date: date).copyWith(appleMusicUrl: url),
    ]);
    ledger = ledger.observe(track(), at: date.add(const Duration(days: 1)));
    expect(ledger.totalPlayCount, 1);
    expect(ledger.tracks.single.appleMusicUrl, url);
    expect(
      SupplementalListeningHistory.decode(ledger.encode())
          .tracks
          .single
          .appleMusicUrl,
      url,
    );
  });

  test('repeated polls count each actual song and timestamp once', () {
    var ledger = const SupplementalListeningHistory.empty();
    for (var i = 0; i < 10; i++) {
      ledger = ledger.ingest([track(date: date)]);
    }
    expect(identical(ledger.ingest([track(date: date)]), ledger), isTrue);
    expect(ledger.totalPlayCount, 1);
    expect(ledger.tracks.single.skipCount, 0);
    ledger = ledger.ingest([track(date: date.add(const Duration(hours: 1)))]);
    expect(ledger.totalPlayCount, 2);
    expect(
      ledger.tracks.single.lastPlayedAt,
      date.add(const Duration(hours: 1)),
    );
  });

  test('unknown date proves one minimum play and never invents a date', () {
    var ledger = const SupplementalListeningHistory.empty();
    ledger = ledger.ingest([track(), track()]);
    expect(ledger.totalPlayCount, 1);
    expect(ledger.undatedTrackCount, 1);
    expect(ledger.tracks.single.lastPlayedAt, isNull);
    ledger = SupplementalListeningHistory.decode(ledger.encode());
    expect(ledger.tracks.single.lastPlayedAt, isNull);
    ledger = ledger.ingest([track(date: date), track()]);
    expect(ledger.totalPlayCount, 1);
    expect(ledger.undatedTrackCount, 0);
    expect(ledger.tracks.single.lastPlayedAt, date);
  });

  test('catalog identifier and normalized metadata preserve aliases', () {
    var ledger = const SupplementalListeningHistory.empty().ingest([
      track(id: 'player', title: ' Song  ', storeId: '0', date: date),
      track(id: 'catalog', title: 'song', storeId: '123', date: date),
      track(id: 'changed', title: 'renamed', storeId: '123', date: date),
    ]);
    ledger = SupplementalListeningHistory.decode(ledger.encode())
        .ingest([track(id: 'player-again', date: date)]);
    expect(ledger.tracks.length, 1);
    expect(ledger.totalPlayCount, 1);
    expect(ledger.tracks.single.appleMusicStoreId, '123');
  });

  test(
    'different albums stay distinct without a shared catalog identifier',
    () {
      final ledger = const SupplementalListeningHistory.empty().ingest([
        track(date: date),
        track(album: 'Live Album', date: date),
      ]);
      expect(ledger.tracks.length, 2);
    },
  );

  test('unknown observed album merges with a confirmed catalog play', () {
    final ledger = const SupplementalListeningHistory.empty().ingest([
      track(id: 'observed', album: 'Unknown Album'),
      track(id: 'catalog', storeId: '123', date: date),
    ]);
    expect(ledger.tracks.length, 1);
    expect(ledger.totalPlayCount, 1);
    expect(ledger.undatedTrackCount, 0);
    expect(ledger.tracks.single.appleMusicStoreId, '123');
    expect(ledger.tracks.single.albumTitle, 'Album');
  });

  test('unknown observed album does not add to known dated plays', () {
    var ledger = const SupplementalListeningHistory.empty().ingest([
      track(storeId: '123', date: date),
      track(storeId: '123', date: date.add(const Duration(hours: 1))),
    ]);
    ledger = ledger.ingest([track(id: 'observed', album: '  UNKNOWN  ALBUM ')]);
    expect(ledger.tracks.length, 1);
    expect(ledger.totalPlayCount, 2);
    expect(ledger.datedEvents.length, 2);
    expect(ledger.undatedTrackCount, 0);
  });

  test('unknown albums do not merge distinct valid catalog identifiers', () {
    final ledger = const SupplementalListeningHistory.empty().ingest([
      track(storeId: '123', album: 'Unknown Album', date: date),
      track(storeId: '456', date: date),
    ]);
    expect(ledger.tracks.length, 2);
    expect(ledger.totalPlayCount, 2);
  });

  test('an old unknown alias does not merge different known albums', () {
    final ledger = const SupplementalListeningHistory.empty().ingest([
      track(album: 'Unknown Album'),
      track(storeId: '123', date: date),
      track(album: 'Live Album', date: date),
    ]);
    expect(ledger.tracks.length, 2);
  });

  test(
    'deterministic roundtrip retains all entries and microsecond timestamps',
    () {
      final rows = List.generate(
        75,
        (i) => track(
          id: '$i',
          storeId: '${100 + i}',
          title: 'Song $i',
          date: date.add(Duration(microseconds: i)),
        ),
      );
      final ledger = const SupplementalListeningHistory.empty().ingest(rows);
      final encoded = ledger.encode();
      expect(SupplementalListeningHistory.decode(encoded).encode(), encoded);
      expect(ledger.totalPlayCount, 75);
      expect(
        const SupplementalListeningHistory.empty()
            .ingest(rows.reversed)
            .encode(),
        encoded,
      );
    },
  );

  test('invalid storage restores a safe empty ledger', () {
    expect(SupplementalListeningHistory.decode('bad json').totalPlayCount, 0);
    expect(
      SupplementalListeningHistory.decode('{"version":2}').tracks,
      isEmpty,
    );
  });
}
