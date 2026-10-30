import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_track.dart';

void main() {
  group('LibraryOverview.withSupplementalTracks', () {
    test(
      '5500 native songs retain their ranking entries across history updates',
      () {
        final native = LibraryOverview.fromTracks([
          for (var index = 0; index < 5500; index++)
            _track(
              id: 'native-$index',
              title: 'Song $index',
              artist: 'Artist ${index % 100}',
              albumTitle: 'Album ${index % 300}',
              albumArtist: 'Artist ${index % 100}',
              plays: index % 50,
              skips: 0,
              playlists: const ['Library'],
            ),
        ], isDemo: false);
        final nativeEntries = {
          for (final entry in native.topTracks)
            entry.representativeTrackId: entry,
        };
        for (var count = 1; count <= 5; count++) {
          final merged = native.withSupplementalTracks([
            _track(
              id: 'outside',
              title: 'Outside',
              artist: 'Outside Artist',
              albumTitle: 'Outside Album',
              albumArtist: 'Outside Artist',
              plays: count,
              skips: 0,
              playlists: const [],
            ),
          ]);
          expect(merged.totalTracks, 5501);
          expect(merged.totalPlayCount, native.totalPlayCount + count);
          for (final entry in merged.topTracks) {
            if (entry.representativeTrackId == 'outside') continue;
            expect(
              identical(entry, nativeEntries[entry.representativeTrackId]),
              isTrue,
            );
          }
          expect(
            identical(
              merged.tracksForPlaylist('Library'),
              native.tracksForPlaylist('Library'),
            ),
            isTrue,
          );
          expect(() => merged.topArtists.clear(), throwsUnsupportedError);
        }
      },
    );

    test('returns the same overview when there are no supplemental tracks', () {
      final native = LibraryOverview.fromTracks([
        _track(
          id: 'native',
          title: 'Native',
          artist: 'Artist',
          albumTitle: 'Album',
          albumArtist: 'Album Artist',
          plays: 1,
          skips: 0,
          playlists: const [],
        ),
      ], isDemo: true);

      expect(
        identical(native.withSupplementalTracks(const []), native),
        isTrue,
      );
    });

    test('matches a combined build across rankings, indexes, and search', () {
      final nativeTracks = [
        _track(
          id: 'n-tie',
          title: 'Tie Native',
          artist: 'Shared Artist',
          albumTitle: 'Shared Album',
          albumArtist: 'Shared Album Artist',
          plays: 10,
          skips: 2,
          date: DateTime.utc(2025, 1, 1),
          genre: 'Native Genre',
          playlists: const ['Shared List', 'Native List'],
        ),
        _track(
          id: 'n-low',
          title: 'Low Native',
          artist: 'Shared Artist',
          albumTitle: 'Shared Album',
          albumArtist: 'Shared Album Artist',
          plays: 3,
          skips: 8,
          date: DateTime.utc(2024, 1, 1),
          genre: 'Shared Genre',
          playlists: const ['Shared List'],
        ),
        _track(
          id: 'n-other-album-artist',
          title: 'Other Album Artist',
          artist: 'Other Artist',
          albumTitle: 'Same Album Name',
          albumArtist: 'Album Artist A',
          plays: 2,
          skips: 1,
          genre: 'Shared Genre',
          playlists: const [],
        ),
        _track(
          id: 'n-unaffected',
          title: 'Unaffected',
          artist: 'Solo Artist',
          albumTitle: 'Solo Album',
          albumArtist: 'Solo Album Artist',
          plays: 1,
          skips: 0,
          genre: 'Unchanged Genre',
          playlists: const ['Unchanged List'],
        ),
        _track(
          id: 'n-tie-only',
          title: 'Native Tie',
          artist: 'Tied Artist',
          albumTitle: 'Tied Album',
          albumArtist: 'Tied Album Artist',
          plays: 6,
          skips: 1,
          genre: 'Native Genre',
          playlists: const [],
        ),
      ];
      final supplemental = [
        // Equal play/listening totals must keep the native representative first.
        _track(
          id: 's-tie',
          title: 'Tie Supplemental',
          artist: 'Shared Artist',
          albumTitle: 'Shared Album',
          albumArtist: 'Shared Album Artist',
          plays: 10,
          skips: 4,
          date: DateTime.utc(2026, 1, 1),
          genre: 'Supplemental Genre',
          playlists: const ['Shared List'],
        ),
        _track(
          id: 's-high',
          title: 'High Supplemental',
          artist: 'Shared Artist',
          albumTitle: 'Shared Album',
          albumArtist: 'Shared Album Artist',
          plays: 15,
          skips: 3,
          date: DateTime.utc(2025, 6, 1),
          genre: 'Shared Genre',
          playlists: const ['Shared List', 'New List'],
        ),
        _track(
          id: 's-other-album-artist',
          title: 'Second Album Artist',
          artist: 'Other Artist',
          albumTitle: 'Same Album Name',
          albumArtist: 'Album Artist B',
          plays: 7,
          skips: 5,
          genre: 'Supplemental Genre',
          playlists: const ['New List'],
        ),
        _track(
          id: 's-no-date',
          title: 'No Date',
          artist: 'Fresh Artist',
          albumTitle: 'Fresh Album',
          albumArtist: 'Fresh Album Artist',
          plays: 5,
          skips: 9,
          genre: null,
          playlists: const [],
        ),
        _track(
          id: 's-tie-only',
          title: 'Supplemental Tie',
          artist: 'Tied Artist',
          albumTitle: 'Tied Album',
          albumArtist: 'Tied Album Artist',
          plays: 6,
          skips: 3,
          genre: 'Supplemental Genre',
          playlists: const [],
        ),
      ];
      final native = LibraryOverview.fromTracks(nativeTracks, isDemo: true);
      final beforeTracks = List<LibraryTrack>.of(native.tracks);
      final beforeTrackRanking = List<RankingEntry>.of(native.topTracks);
      final beforeSoloGenre = native.tracksForGenre('Unchanged Genre');
      final beforeSoloPlaylist = native.tracksForPlaylist('Unchanged List');

      final merged = native.withSupplementalTracks(supplemental);
      final rebuilt = LibraryOverview.fromTracks([
        ...nativeTracks,
        ...supplemental,
      ], isDemo: native.isDemo);

      expect(merged.totalTracks, rebuilt.totalTracks);
      expect(merged.totalArtists, rebuilt.totalArtists);
      expect(merged.totalAlbums, rebuilt.totalAlbums);
      expect(merged.totalPlayCount, rebuilt.totalPlayCount);
      expect(merged.totalSkipCount, rebuilt.totalSkipCount);
      expect(merged.totalListeningSeconds, rebuilt.totalListeningSeconds);
      expect(merged.isDemo, rebuilt.isDemo);
      expect(_ranking(merged.topTracks), _ranking(rebuilt.topTracks));
      expect(_ranking(merged.topArtists), _ranking(rebuilt.topArtists));
      expect(_ranking(merged.topAlbums), _ranking(rebuilt.topAlbums));
      expect(_ranking(merged.recentTracks), _ranking(rebuilt.recentTracks));
      expect(_ids(merged.recentTrackDetails), _ids(rebuilt.recentTrackDetails));
      expect(_ids(merged.tracksByRecent), _ids(rebuilt.tracksByRecent));
      expect(_ids(merged.tracksByPlayCount), _ids(rebuilt.tracksByPlayCount));
      expect(_ids(merged.tracksBySkipCount), _ids(rebuilt.tracksBySkipCount));
      expect(_ids(merged.tracksByTitle), _ids(rebuilt.tracksByTitle));

      expect(
        merged.trackById('s-high')?.title,
        rebuilt.trackById('s-high')?.title,
      );
      expect(merged.trackById('missing'), isNull);
      expect(
        _ids(merged.tracksForArtist('Shared Artist')),
        _ids(rebuilt.tracksForArtist('Shared Artist')),
      );
      expect(
        _ids(merged.tracksForAlbumArtist('Shared Album Artist')),
        _ids(rebuilt.tracksForAlbumArtist('Shared Album Artist')),
      );
      expect(
        _ids(merged.tracksForAlbumArtist('Album Artist A')),
        _ids(rebuilt.tracksForAlbumArtist('Album Artist A')),
      );
      expect(
        _ids(merged.tracksForAlbumArtist('Album Artist B')),
        _ids(rebuilt.tracksForAlbumArtist('Album Artist B')),
      );
      expect(
        _ids(merged.tracksForAlbum(nativeTracks[0])),
        _ids(rebuilt.tracksForAlbum(nativeTracks[0])),
      );
      expect(
        _ids(merged.tracksForAlbum(supplemental[2])),
        _ids(rebuilt.tracksForAlbum(supplemental[2])),
      );
      expect(
        _ids(merged.tracksForGenre('Shared Genre')),
        _ids(rebuilt.tracksForGenre('Shared Genre')),
      );
      expect(
        _ids(merged.tracksForGenre('Supplemental Genre')),
        _ids(rebuilt.tracksForGenre('Supplemental Genre')),
      );
      expect(
        _ids(merged.tracksForPlaylist('Shared List')),
        _ids(rebuilt.tracksForPlaylist('Shared List')),
      );
      expect(
        _ids(merged.tracksForPlaylist('New List')),
        _ids(rebuilt.tracksForPlaylist('New List')),
      );
      expect(
        _ids(merged.filteredTracks('shared')),
        _ids(rebuilt.filteredTracks('shared')),
      );
      expect(
        _ids(merged.filteredTracks('new list')),
        _ids(rebuilt.filteredTracks('new list')),
      );

      // Merging is additive and leaves the original snapshot and ranking intact.
      expect(_ids(native.tracks), _ids(beforeTracks));
      expect(native.tracks, orderedEquals(beforeTracks));
      expect(native.topTracks, orderedEquals(beforeTrackRanking));

      // Groups untouched by supplemental tracks retain their indexed lists.
      expect(
        identical(merged.tracksForGenre('Unchanged Genre'), beforeSoloGenre),
        isTrue,
      );
      expect(
        identical(
          merged.tracksForPlaylist('Unchanged List'),
          beforeSoloPlaylist,
        ),
        isTrue,
      );

      final sharedArtist = merged.topArtists.singleWhere(
        (entry) => entry.title == 'Shared Artist',
      );
      expect(sharedArtist.representativeTrackId, 's-high');
      final tiedArtist = merged.topArtists.singleWhere(
        (entry) => entry.title == 'Tied Artist',
      );
      expect(tiedArtist.representativeTrackId, 'n-tie-only');
      final tiedAlbum = merged.topAlbums.singleWhere(
        (entry) => entry.title == 'Shared Album Artist - Shared Album',
      );
      expect(tiedAlbum.representativeTrackId, 's-high');
      final otherAlbumGroups = merged.topAlbums
          .where((entry) => entry.title.endsWith('Same Album Name'))
          .toList();
      expect(
        otherAlbumGroups.map((entry) => entry.title),
        containsAll([
          'Album Artist A - Same Album Name',
          'Album Artist B - Same Album Name',
        ]),
      );
    });
  });
}

List<String> _ids(Iterable<LibraryTrack> tracks) =>
    tracks.map((track) => track.id).toList();

List<String> _ranking(Iterable<RankingEntry> entries) =>
    (entries
        .map(
          (entry) =>
              '${entry.kind}|${entry.title}|${entry.subtitle}|${entry.playCount}|'
              '${entry.skipCount}|${entry.listeningSeconds}|${entry.representativeTrackId}|'
              '${entry.lastPlayedAt?.toIso8601String()}',
        )
        .toList()
      ..sort());

LibraryTrack _track({
  required String id,
  required String title,
  required String artist,
  required String albumTitle,
  required String albumArtist,
  required int plays,
  required int skips,
  DateTime? date,
  String? genre,
  required List<String> playlists,
}) {
  return LibraryTrack(
    id: id,
    title: title,
    artist: artist,
    albumTitle: albumTitle,
    albumArtist: albumArtist,
    genre: genre,
    duration: const Duration(minutes: 3),
    playCount: plays,
    skipCount: skips,
    lastPlayedAt: date,
    isCloudItem: false,
    playlistNames: playlists,
  );
}
