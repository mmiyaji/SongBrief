import 'library_overview.dart';
import 'library_snapshot.dart';
import 'music_library_authorization.dart';

class MusicStatsState {
  const MusicStatsState({
    required this.authorizationStatus,
    required this.overview,
    required this.snapshotHistory,
  });

  final MusicLibraryAuthorizationStatus authorizationStatus;
  final LibraryOverview overview;
  final SnapshotHistory snapshotHistory;

  bool get isDemo => overview.isDemo;

  MusicStatsState markTrackPlayed(String trackId) {
    return MusicStatsState(
      authorizationStatus: authorizationStatus,
      overview: overview.markTrackPlayed(trackId),
      snapshotHistory: snapshotHistory,
    );
  }

  MusicStatsState withSnapshotHistory(SnapshotHistory snapshotHistory) {
    return MusicStatsState(
      authorizationStatus: authorizationStatus,
      overview: overview,
      snapshotHistory: snapshotHistory,
    );
  }
}
