import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';

void main() {
  test('excludes tracks by playlist, genre, and keyword', () {
    final filters = LibraryFilterPreferences(
      excludedPlaylists: ['Focus'],
      excludedGenres: ['Ambient'],
      excludedKeywords: ['secret'],
    );

    final tracks = [
      _track(
        id: '1',
        title: 'Visible Song',
        artist: 'Nami',
        albumTitle: 'Night Transit',
        genre: 'Pop',
        playlistNames: ['Daily'],
      ),
      _track(
        id: '2',
        title: 'Playlist Song',
        artist: 'Nami',
        albumTitle: 'Night Transit',
        genre: 'Pop',
        playlistNames: ['Focus'],
      ),
      _track(
        id: '3',
        title: 'Genre Song',
        artist: 'Kite',
        albumTitle: 'Drift',
        genre: 'Ambient',
        playlistNames: ['Daily'],
      ),
      _track(
        id: '4',
        title: 'Secret Demo',
        artist: 'Mika',
        albumTitle: 'Small Signals',
        genre: 'Pop',
        playlistNames: ['Daily'],
      ),
    ];

    expect(filters.apply(tracks).map((track) => track.id), ['1']);
  });

  test('normalizes duplicate rules and ignores empty input', () {
    final filters = LibraryFilterPreferences(
      excludedPlaylists: [' Focus ', 'focus', ''],
      excludedGenres: ['Rock', ' rock '],
      excludedKeywords: [' demo ', 'DEMO'],
    );

    expect(filters.excludedPlaylists, ['Focus']);
    expect(filters.excludedGenres, ['Rock']);
    expect(filters.excludedKeywords, ['demo']);
    expect(filters.ruleCount, 3);
  });
}

LibraryTrack _track({
  required String id,
  required String title,
  required String artist,
  required String albumTitle,
  required String genre,
  required List<String> playlistNames,
}) {
  return LibraryTrack(
    id: id,
    title: title,
    artist: artist,
    albumTitle: albumTitle,
    genre: genre,
    duration: const Duration(minutes: 3),
    playCount: 1,
    skipCount: 0,
    isCloudItem: false,
    playlistNames: playlistNames,
  );
}
