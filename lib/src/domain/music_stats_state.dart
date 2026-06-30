import 'library_overview.dart';
import 'music_library_authorization.dart';

class MusicStatsState {
  const MusicStatsState({
    required this.authorizationStatus,
    required this.overview,
  });

  final MusicLibraryAuthorizationStatus authorizationStatus;
  final LibraryOverview overview;

  bool get isDemo => overview.isDemo;

  MusicStatsState markTrackPlayed(String trackId) {
    return MusicStatsState(
      authorizationStatus: authorizationStatus,
      overview: overview.markTrackPlayed(trackId),
    );
  }
}
