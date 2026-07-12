import 'library_overview.dart';
import 'library_snapshot.dart';
import 'music_library_authorization.dart';

class MusicStatsState {
  const MusicStatsState({
    required this.authorizationStatus,
    required this.overview,
    required this.snapshotHistory,
    this.snapshotRecordingEnabled = true,
    this.lastDataRefreshAt,
  });

  final MusicLibraryAuthorizationStatus authorizationStatus;
  final LibraryOverview overview;
  final SnapshotHistory snapshotHistory;
  final bool snapshotRecordingEnabled;
  final DateTime? lastDataRefreshAt;

  bool get isDemo => overview.isDemo;

  MusicStatsState withSnapshotHistory(SnapshotHistory snapshotHistory) {
    return MusicStatsState(
      authorizationStatus: authorizationStatus,
      overview: overview,
      snapshotHistory: snapshotHistory,
      snapshotRecordingEnabled: snapshotRecordingEnabled,
      lastDataRefreshAt: lastDataRefreshAt,
    );
  }
}
