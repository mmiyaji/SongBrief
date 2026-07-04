import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SongBrief'**
  String get appTitle;

  /// No description provided for @appLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'SongBrief is locked'**
  String get appLockedTitle;

  /// No description provided for @appLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your device authentication.'**
  String get appLockedSubtitle;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed.'**
  String get authenticationFailed;

  /// No description provided for @unlockSongBriefReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock SongBrief.'**
  String get unlockSongBriefReason;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @sponsoredPlacement.
  ///
  /// In en, this message translates to:
  /// **'Sponsored placement'**
  String get sponsoredPlacement;

  /// No description provided for @sponsored.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get sponsored;

  /// No description provided for @adLoadingSmallBanner.
  ///
  /// In en, this message translates to:
  /// **'Loading a small banner ad'**
  String get adLoadingSmallBanner;

  /// No description provided for @adLoaded.
  ///
  /// In en, this message translates to:
  /// **'Ad loaded'**
  String get adLoaded;

  /// No description provided for @adMissingLiveUnit.
  ///
  /// In en, this message translates to:
  /// **'Set a live AdMob ad unit ID before release'**
  String get adMissingLiveUnit;

  /// No description provided for @adPreviewForLaunchMode.
  ///
  /// In en, this message translates to:
  /// **'Ad preview for this launch mode'**
  String get adPreviewForLaunchMode;

  /// No description provided for @adTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Ad is temporarily unavailable'**
  String get adTemporarilyUnavailable;

  /// No description provided for @premiumUnlockedByLaunchMode.
  ///
  /// In en, this message translates to:
  /// **'Premium is unlocked by launch mode.'**
  String get premiumUnlockedByLaunchMode;

  /// No description provided for @premiumPurchaseWaiting.
  ///
  /// In en, this message translates to:
  /// **'Purchase is waiting for store confirmation.'**
  String get premiumPurchaseWaiting;

  /// No description provided for @premiumRestoreRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Restore request sent to the store.'**
  String get premiumRestoreRequestSent;

  /// No description provided for @premiumActiveAdsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Premium is active. Ads are removed.'**
  String get premiumActiveAdsRemoved;

  /// No description provided for @premiumPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Purchase is pending.'**
  String get premiumPurchasePending;

  /// No description provided for @premiumPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed.'**
  String get premiumPurchaseFailed;

  /// No description provided for @premiumStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store is not available.'**
  String get premiumStoreUnavailable;

  /// No description provided for @premiumConfigureProduct.
  ///
  /// In en, this message translates to:
  /// **'Configure the premium product in App Store Connect.'**
  String get premiumConfigureProduct;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
