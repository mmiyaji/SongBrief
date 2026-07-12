import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_track.dart';

void main() {
  test('indexes library tracks for drilldown and repeated search', () {
    final overview = LibraryOverview.fromTracks([
      _track(
        id: '1',
        title: 'First Song',
        artist: 'Artist A',
        albumTitle: 'Album One',
        playCount: 4,
        playlists: const ['Focus'],
      ),
      _track(
        id: '2',
        title: 'Second Song',
        artist: 'Artist A',
        albumTitle: 'Album One',
        playCount: 12,
        playlists: const ['Focus', 'Favorites'],
      ),
      _track(
        id: '3',
        title: 'Third Song',
        artist: 'Artist B',
        albumTitle: 'Album Two',
        playCount: 8,
        playlists: const ['Favorites'],
      ),
    ], isDemo: true);

    expect(overview.totalTracks, 3);
    expect(overview.totalArtists, 2);
    expect(overview.totalAlbums, 2);
    expect(overview.trackById('2')?.title, 'Second Song');
    expect(overview.tracksForArtist('Artist A').map((track) => track.id), [
      '2',
      '1',
    ]);
    expect(overview.tracksForPlaylist('Favorites').map((track) => track.id), [
      '2',
      '3',
    ]);

    final firstSearch = overview.filteredTracks('focus');
    final secondSearch = overview.filteredTracks('focus');

    expect(firstSearch.map((track) => track.id), ['1', '2']);
    expect(identical(firstSearch, secondSearch), isTrue);
  });
}

LibraryTrack _track({
  required String id,
  required String title,
  required String artist,
  required String albumTitle,
  required int playCount,
  required List<String> playlists,
}) {
  return LibraryTrack(
    id: id,
    title: title,
    artist: artist,
    albumTitle: albumTitle,
    albumArtist: artist,
    duration: const Duration(minutes: 3),
    playCount: playCount,
    skipCount: 0,
    isCloudItem: false,
    playlistNames: playlists,
  );
}
