import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/settings/library_filter_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  test('copyWith preserves existing rule groups unless replaced', () {
    final filters = LibraryFilterPreferences(
      excludedPlaylists: ['Focus'],
      excludedGenres: ['Rock'],
      excludedKeywords: ['demo'],
    );

    final changed = filters.copyWith(excludedGenres: ['Ambient']);

    expect(changed.excludedPlaylists, ['Focus']);
    expect(changed.excludedGenres, ['Ambient']);
    expect(changed.excludedKeywords, ['demo']);
    expect(changed.isEmpty, isFalse);
  });

  test('snapshot signature is normalized and changes with the rules', () {
    final first = LibraryFilterPreferences(
      excludedPlaylists: [' Focus ', 'Daily'],
      excludedGenres: ['Ambient'],
      excludedKeywords: ['Secret'],
    );
    final equivalent = LibraryFilterPreferences(
      excludedPlaylists: ['daily', 'focus'],
      excludedGenres: ['ambient'],
      excludedKeywords: ['secret'],
    );
    final changed = equivalent.copyWith(excludedKeywords: ['different']);

    expect(first.snapshotSignature, equivalent.snapshotSignature);
    expect(changed.snapshotSignature, isNot(first.snapshotSignature));
    expect(first.snapshotSignature, hasLength(8));
  });

  test('returns the original track list when there are no filter rules', () {
    final filters = LibraryFilterPreferences();
    final tracks = [
      _track(
        id: '1',
        title: 'Visible Song',
        artist: 'Nami',
        albumTitle: 'Night Transit',
        genre: 'Pop',
        playlistNames: ['Daily'],
      ),
    ];

    expect(identical(filters.apply(tracks), tracks), isTrue);
    expect(filters.apply(const []), isEmpty);
  });

  test('controller restores, updates, persists, and clears rules', () async {
    SharedPreferences.setMockInitialValues({
      'songbrief_excluded_playlists_v1': ['Focus'],
      'songbrief_excluded_genres_v1': ['Ambient'],
      'songbrief_excluded_keywords_v1': ['secret'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(libraryFilterPreferencesProvider);
    await container.read(libraryFilterPreferencesProvider.notifier).restored;

    expect(container.read(libraryFilterPreferencesProvider).excludedPlaylists, [
      'Focus',
    ]);
    expect(container.read(libraryFilterPreferencesProvider).excludedGenres, [
      'Ambient',
    ]);
    expect(container.read(libraryFilterPreferencesProvider).excludedKeywords, [
      'secret',
    ]);

    final controller = container.read(
      libraryFilterPreferencesProvider.notifier,
    );
    controller.addExcludedPlaylist('Favorites');
    controller.removeExcludedPlaylist('Focus');
    controller.addExcludedGenre('Rock');
    controller.removeExcludedGenre('Ambient');
    controller.addExcludedKeyword('demo');
    controller.removeExcludedKeyword('secret');
    await _drainPreferenceRestore();

    final updated = container.read(libraryFilterPreferencesProvider);
    expect(updated.excludedPlaylists, ['Favorites']);
    expect(updated.excludedGenres, ['Rock']);
    expect(updated.excludedKeywords, ['demo']);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('songbrief_excluded_playlists_v1'), [
      'Favorites',
    ]);
    expect(preferences.getStringList('songbrief_excluded_genres_v1'), ['Rock']);
    expect(preferences.getStringList('songbrief_excluded_keywords_v1'), [
      'demo',
    ]);

    controller.clearAll();
    await _drainPreferenceRestore();

    expect(container.read(libraryFilterPreferencesProvider).isEmpty, isTrue);
    expect(
      preferences.getStringList('songbrief_excluded_playlists_v1'),
      isEmpty,
    );
    expect(preferences.getStringList('songbrief_excluded_genres_v1'), isEmpty);
    expect(
      preferences.getStringList('songbrief_excluded_keywords_v1'),
      isEmpty,
    );
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

Future<void> _drainPreferenceRestore() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
