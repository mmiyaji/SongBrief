// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SongBrief';

  @override
  String get appLockedTitle => 'SongBrief is locked';

  @override
  String get appLockedSubtitle => 'Unlock with your device authentication.';

  @override
  String get authenticationFailed => 'Authentication failed.';

  @override
  String get unlockSongBriefReason => 'Unlock SongBrief.';

  @override
  String get unlock => 'Unlock';

  @override
  String get sponsoredPlacement => 'Sponsored placement';

  @override
  String get sponsored => 'Sponsored';

  @override
  String get adLoadingSmallBanner => 'Loading a small banner ad';

  @override
  String get adLoaded => 'Ad loaded';

  @override
  String get adMissingLiveUnit => 'Set a live AdMob ad unit ID before release';

  @override
  String get adPreviewForLaunchMode => 'Ad preview for this launch mode';

  @override
  String get adTemporarilyUnavailable => 'Ad is temporarily unavailable';

  @override
  String get premiumUnlockedByLaunchMode =>
      'Premium is unlocked by launch mode.';

  @override
  String get premiumPurchaseWaiting =>
      'Purchase is waiting for store confirmation.';

  @override
  String get premiumRestoreRequestSent => 'Restore request sent to the store.';

  @override
  String get premiumActiveAdsRemoved => 'Premium is active. Ads are removed.';

  @override
  String get premiumPurchasePending => 'Purchase is pending.';

  @override
  String get premiumPurchaseFailed => 'Purchase failed.';

  @override
  String get premiumStoreUnavailable => 'Store is not available.';

  @override
  String get premiumConfigureProduct =>
      'Configure the premium product in App Store Connect.';
}
