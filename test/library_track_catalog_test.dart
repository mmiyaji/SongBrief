import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';
import 'package:songbrief/src/domain/library_track.dart';

LibraryTrack _track(String id, {String? storeId, String? title}) =>
    LibraryTrack(
      id: id,
      title: title ?? 'Song $id',
      artist: 'Artist $id',
      albumTitle: 'Album $id',
      appleMusicStoreId: storeId,
      duration: const Duration(minutes: 3),
      playCount: 4,
      skipCount: 0,
      isCloudItem: true,
    );

void main() {
  test('catalog ID finds library track despite different service metadata', () {
    final libraryTrack = _track('native', storeId: ' 12345 ');
    final catalog = LibraryTrackCatalog()..replace([libraryTrack]);
    expect(
      catalog.match(_track('musickit:12345', storeId: '12345')),
      same(libraryTrack),
    );
  });

  for (final invalidId in <String?>[
    null,
    '',
    '   ',
    '0',
    ' 0 ',
    '000',
    'i.library-song',
    'musickit:123',
  ]) {
    test('invalid catalog ID "$invalidId" does not join unrelated songs', () {
      final catalog = LibraryTrackCatalog()
        ..replace([_track('native', storeId: invalidId)]);
      expect(catalog.match(_track('external', storeId: invalidId)), isNull);
    });
  }

  test('native identity takes precedence over a catalog alias', () {
    final native = _track('native', storeId: '123');
    final other = _track('other', storeId: '456');
    final catalog = LibraryTrackCatalog()..replace([native, other]);
    expect(catalog.match(_track('native', storeId: '456')), same(native));
  });

  test('replacing library clears stale catalog IDs', () {
    final catalog = LibraryTrackCatalog()
      ..replace([_track('native', storeId: '123')]);
    catalog.replace([_track('new', storeId: '456')]);
    expect(catalog.match(_track('external', storeId: '123')), isNull);
  });
}
