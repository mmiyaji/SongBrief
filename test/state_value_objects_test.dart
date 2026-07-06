import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_overview.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/music_library_authorization.dart';
import 'package:songbrief/src/domain/music_stats_state.dart';
import 'package:songbrief/src/monetization/ad_consent_state.dart';
import 'package:songbrief/src/monetization/monetization_config.dart';

void main() {
  test('maps platform authorization values and access capabilities', () {
    expect(
      MusicLibraryAuthorizationStatus.fromPlatformValue('authorized'),
      MusicLibraryAuthorizationStatus.authorized,
    );
    expect(
      MusicLibraryAuthorizationStatus.fromPlatformValue('denied'),
      MusicLibraryAuthorizationStatus.denied,
    );
    expect(
      MusicLibraryAuthorizationStatus.fromPlatformValue('restricted'),
      MusicLibraryAuthorizationStatus.restricted,
    );
    expect(
      MusicLibraryAuthorizationStatus.fromPlatformValue('notDetermined'),
      MusicLibraryAuthorizationStatus.notDetermined,
    );
    expect(
      MusicLibraryAuthorizationStatus.fromPlatformValue('unknown'),
      MusicLibraryAuthorizationStatus.unsupported,
    );

    expect(MusicLibraryAuthorizationStatus.authorized.canReadLibrary, isTrue);
    expect(MusicLibraryAuthorizationStatus.denied.canReadLibrary, isFalse);
    expect(
      MusicLibraryAuthorizationStatus.notDetermined.canAskForAccess,
      isTrue,
    );
    expect(MusicLibraryAuthorizationStatus.denied.canAskForAccess, isTrue);
    expect(MusicLibraryAuthorizationStatus.restricted.canAskForAccess, isTrue);
    expect(
      MusicLibraryAuthorizationStatus.unsupported.canAskForAccess,
      isFalse,
    );
  });

  test('copies snapshot history while preserving stats metadata', () {
    final overview = LibraryOverview.fromTracks([
      LibraryTrack(
        id: 'track-1',
        title: 'SongBrief Song',
        artist: 'SongBrief Artist',
        albumTitle: 'SongBrief Album',
        duration: const Duration(minutes: 3),
        playCount: 7,
        skipCount: 1,
        isCloudItem: false,
      ),
    ], isDemo: true);
    final state = MusicStatsState(
      authorizationStatus: MusicLibraryAuthorizationStatus.unsupported,
      overview: overview,
      snapshotHistory: SnapshotHistory.empty,
      snapshotRecordingEnabled: false,
    );
    final snapshot = DailyLibrarySnapshot.fromOverview(
      overview,
      capturedAt: DateTime(2026, 7, 7),
    );

    final copied = state.withSnapshotHistory(
      SnapshotHistory.empty.withSnapshot(snapshot),
    );

    expect(state.isDemo, isTrue);
    expect(copied.authorizationStatus, state.authorizationStatus);
    expect(copied.overview, same(overview));
    expect(copied.snapshotRecordingEnabled, isFalse);
    expect(copied.snapshotHistory.snapshotCount, 1);
  });

  test('describes unsupported ad consent and launch modes', () {
    const unsupported = PlatformAdConsentResult.unsupported();
    const supported = PlatformAdConsentResult(
      supported: true,
      canRequestAds: true,
      privacyOptionsRequired: true,
      errorMessage: 'test error',
    );

    expect(unsupported.supported, isFalse);
    expect(unsupported.canRequestAds, isFalse);
    expect(unsupported.privacyOptionsRequired, isFalse);
    expect(unsupported.errorMessage, isNull);
    expect(supported.supported, isTrue);
    expect(supported.canRequestAds, isTrue);
    expect(supported.privacyOptionsRequired, isTrue);
    expect(supported.errorMessage, 'test error');

    expect(AdLaunchMode.off.showsAdSlots, isFalse);
    expect(AdLaunchMode.admobTest.showsAdSlots, isTrue);
    expect(AdLaunchMode.admobTest.usesLiveAdUnits, isFalse);
    expect(AdLaunchMode.admobLive.usesLiveAdUnits, isTrue);
    expect(MonetizationConfig.adMode, AdLaunchMode.off);
    expect(
      MonetizationConfig.productionIosBannerAdUnitId,
      'ca-app-pub-5321136982470738/2315074663',
    );
    expect(
      MonetizationConfig.iosBannerAdUnitId,
      MonetizationConfig.productionIosBannerAdUnitId,
    );
  });
}
