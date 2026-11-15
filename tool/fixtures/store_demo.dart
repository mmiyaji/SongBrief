// Fictional, deterministic data for screenshots of the production app.
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';

final websiteDemoDate = DateTime.now().subtract(const Duration(minutes: 5));

const websiteDemoArtwork = [
  'skyline_echo',
  'late_bloom',
  'north_line',
  'signal_blue',
  'glass_harbor',
  'midnight_arcade',
  'subway_light',
  'tableau',
];

MusicStatsState websiteDemoState() {
  const titles = [
    'Skyline Echo',
    'Late Bloom',
    'North Line',
    'Signal Blue',
    'Glass Harbor',
    'Midnight Arcade',
    'Subway Light',
    'Tableau',
    'Paper Moon',
    'Velvet Morning',
    'Quiet Current',
    'Golden Hour',
    'After the Rain',
    'Neon Garden',
    'Window Seat',
    'Soft Landing',
    'Blue Hour',
    'Slow Orbit',
    'Wildflower',
    'Northern Lights',
    'Open Water',
    'Sunroom',
    'Parallel Lines',
    'First Light',
    'Evening Tide',
    'Daybreak Radio',
    'Silver Lining',
    'Night Walk',
    'Coastal Road',
    'Small Hours',
    'Warm Static',
    'Sunday Letters',
    'Amber Sky',
    'Riverbed',
    'Hidden Path',
    'Endless Summer',
    'Still Life',
    'Distant Shore',
    'Lunar Phase',
    'Homeward',
  ];
  const artists = [
    'Aoi',
    'Mika',
    'Haru',
    'Sora',
    'Lumen',
    'Nagi',
    'Yuno',
    'Rei',
  ];
  const albums = [
    'Skyline Echo',
    'Late Bloom',
    'North Line',
    'Signal Blue',
    'Glass Harbor',
    'Midnight Arcade',
    'Subway Light',
    'Tableau',
    'Coastal Notes',
    'Small Hours',
    'Morning Letters',
    'Quiet Cities',
  ];
  const genres = ['Indie Pop', 'Alternative', 'Electronic', 'Jazz', 'Ambient'];
  const favorites = [640, 470, 350, 280, 220, 180, 150, 125];
  final counts = List.generate(
    titles.length,
    (i) => i < favorites.length ? favorites[i] : 130 - i * 2,
  );
  final lastPlayed = List.generate(
    titles.length,
    (i) => websiteDemoDate.subtract(Duration(days: 100 + i)),
  );
  final skips = List.generate(titles.length, (i) => 2 + i % 9);
  List<LibraryTrack> tracks() => List.generate(titles.length, (i) {
    final album = i % albums.length;
    return LibraryTrack(
      id: 'website-demo-$i',
      title: titles[i],
      artist: artists[album % artists.length],
      albumArtist: artists[album % artists.length],
      albumTitle: albums[album],
      genre: genres[album % genres.length],
      artworkAsset: 'assets/demo_art/${websiteDemoArtwork[album % 8]}.png',
      releaseDate: DateTime(2014 + album, 2 + i % 10, 10),
      duration: Duration(seconds: 184 + (i * 17) % 142),
      playCount: counts[i],
      skipCount: skips[i],
      lastPlayedAt: lastPlayed[i],
      isCloudItem: i % 5 == 4,
      playlistNames: [
        if (i % 3 == 0) 'Morning Focus',
        if (i % 2 == 0) 'City Walk',
        if (i % 4 == 1) 'After Hours',
      ],
      lyrics:
          'Streetlights fade into the morning\n'
          'We follow rivers through the town\n'
          'A quiet song beyond the window\n'
          'The skyline keeps our echoes now\n\n'
          'Original fictional lyrics for the SongBrief demo.',
    );
  });

  final snapshots = <DailyLibrarySnapshot>[];
  // Every change is derived from these same cumulative counters. The last
  // snapshot and the displayed library therefore agree exactly.
  for (var day = 100; day >= 0; day--) {
    final date = DateTime(
      websiteDemoDate.year,
      websiteDemoDate.month,
      websiteDemoDate.day,
    ).subtract(Duration(days: day));
    final activity = (date.weekday == DateTime.sunday ? 8 : 4) + day % 7;
    for (var play = 0; play < activity; play++) {
      final index = (day * 7 + play * 3) % titles.length;
      counts[index] += 1 + (play == 0 ? day % 3 : 0);
      if ((day + play) % 11 == 0) skips[index]++;
      lastPlayed[index] = day == 0
          ? websiteDemoDate.subtract(Duration(minutes: activity - play))
          : date.add(Duration(hours: 8 + play % 3, minutes: 12));
    }
    snapshots.add(
      DailyLibrarySnapshot.fromOverview(
        LibraryOverview.fromTracks(tracks(), isDemo: true),
        capturedAt: day == 0
            ? websiteDemoDate
            : date.add(const Duration(hours: 11, minutes: 30)),
      ),
    );
  }
  return MusicStatsState(
    authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
    overview: LibraryOverview.fromTracks(tracks(), isDemo: true),
    snapshotHistory: SnapshotHistory(snapshots: snapshots),
    lastDataRefreshAt: websiteDemoDate,
  );
}
