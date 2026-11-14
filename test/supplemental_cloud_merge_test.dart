import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';

LibraryTrack row({
  String id = 'library',
  String title = 'Song',
  String album = 'Album',
  String? storeId = '123',
  DateTime? playedAt,
  String? url,
}) => LibraryTrack(
  id: id,
  title: title,
  artist: 'Artist',
  albumTitle: album,
  duration: const Duration(minutes: 3),
  playCount: 500,
  skipCount: 90,
  isCloudItem: true,
  appleMusicStoreId: storeId,
  appleMusicUrl: url,
  lastPlayedAt: playedAt,
);

void main() {
  final t1 = DateTime.utc(2026, 1, 1);
  final t2 = DateTime.utc(2026, 1, 2);

  test('same event on two devices counts once and distinct dates add', () {
    final first = const SupplementalListeningHistory.empty().ingest([
      row(id: 'device-a', playedAt: t1),
    ]);
    final second = const SupplementalListeningHistory.empty().ingest([
      row(id: 'device-b', playedAt: t1),
      row(id: 'device-b', playedAt: t2),
    ]);
    final merged = first.merge(second);
    expect(merged.totalPlayCount, 2);
    expect(merged.datedEvents.map((e) => e.playedAt).toSet(), {t1, t2});
    expect(merged.merge(first).encode(), merged.encode());
  });

  test(
    'merge is commutative, idempotent, associative, and native counts vanish',
    () {
      final a = const SupplementalListeningHistory.empty().ingest([
        row(id: 'a', playedAt: t1),
      ]);
      final b = const SupplementalListeningHistory.empty().ingest([
        row(id: 'b', playedAt: t2),
      ]);
      final c = const SupplementalListeningHistory.empty().observe(
        row(id: 'c', storeId: null),
        at: t2.add(const Duration(days: 1)),
      );
      expect(a.merge(b).encode(), b.merge(a).encode());
      expect(a.merge(a).encode(), a.encode());
      expect(a.merge(b).merge(c).encode(), a.merge(b.merge(c)).encode());
      expect(a.merge(b).tracks.single.playCount, 2);
      expect(a.merge(b).tracks.single.skipCount, 0);
    },
  );

  test('observations merge to earliest timestamp and exact playback replaces fallback', () {
    final earlier = const SupplementalListeningHistory.empty().observe(
      row(storeId: null),
      at: t1,
    );
    final later = const SupplementalListeningHistory.empty().observe(
      row(id: 'other', storeId: null),
      at: t2,
    );
    final mergedObservations = later.merge(earlier);
    expect(mergedObservations.totalPlayCount, 1);
    expect(mergedObservations.observedEvents.single.playedAt, t1);

    final exact = const SupplementalListeningHistory.empty().ingest([
      row(id: 'catalog', playedAt: t2),
    ]);
    final merged = earlier.merge(exact);
    expect(merged.totalPlayCount, 1);
    expect(merged.datedEvents.single.playedAt, t2);
    expect(merged.observedEvents, isEmpty);
  });

  test('merge(self) preserves first observation proof on dated entries', () {
    var ledger = const SupplementalListeningHistory.empty().observe(
      row(storeId: null),
      at: t1,
    );
    ledger = ledger.ingest([row(playedAt: t2)]);
    expect(ledger.observedEvents, isEmpty);
    expect(ledger.merge(ledger).encode(), ledger.encode());
  });

  test('aliases and URL survive catalog enrichment across devices', () {
    const url = 'https://music.apple.com/us/song/123';
    final player = const SupplementalListeningHistory.empty().ingest([
      row(id: 'player', title: 'Song', storeId: null, playedAt: t1),
    ]);
    final catalog = const SupplementalListeningHistory.empty().ingest([
      row(id: 'catalog', playedAt: t2, url: url),
    ]);
    final merged = player.merge(catalog);
    final enriched = merged.ingest([row(id: 'again', storeId: null)]);
    expect(enriched.tracks, hasLength(1));
    expect(enriched.totalPlayCount, 2);
    expect(enriched.tracks.single.appleMusicUrl, url);
  });

  test('distinct catalog IDs and albums remain separate', () {
    final left = const SupplementalListeningHistory.empty().ingest([
      row(storeId: '111', album: 'First'),
      row(storeId: '222', album: 'Second'),
    ]);
    final merged = left.merge(
      const SupplementalListeningHistory.empty().ingest([
        row(id: 'third', storeId: '333', album: 'Unknown Album'),
      ]),
    );
    expect(merged.tracks, hasLength(3));
  });

  test(
    'same catalog evidence is order-independent with URL and renamed metadata',
    () {
      final first = const SupplementalListeningHistory.empty().ingest([
        row(id: 'first', title: 'Song', playedAt: t1),
      ]);
      final second = const SupplementalListeningHistory.empty().ingest([
        row(
          id: 'second',
          title: 'Renamed Song',
          playedAt: t1,
          url: 'https://music.apple.com/song/123',
        ),
      ]);
      expect(first.merge(second).encode(), second.merge(first).encode());
      expect(
        first.merge(second).tracks.single.appleMusicUrl,
        'https://music.apple.com/song/123',
      );
    },
  );

  test(
    'stored aliases reconnect metadata-only device rows after catalog rename',
    () {
      var catalog = const SupplementalListeningHistory.empty().ingest([
        row(id: 'catalog', title: 'Old Name', playedAt: t1),
      ]);
      catalog = catalog.ingest([
        row(id: 'catalog', title: 'New Name', playedAt: t2),
      ]);
      final offline = const SupplementalListeningHistory.empty().ingest([
        row(id: 'offline', title: 'Old Name', storeId: null, playedAt: t1),
      ]);
      final merged = catalog.merge(offline);
      expect(merged.tracks, hasLength(1));
      expect(merged.totalPlayCount, 2);
      expect(merged.tracks.single.appleMusicStoreId, '123');
    },
  );
}
