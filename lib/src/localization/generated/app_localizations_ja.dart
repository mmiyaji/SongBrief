// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'SongBrief';

  @override
  String get appLockedTitle => 'SongBriefはロック中です';

  @override
  String get appLockedSubtitle => '端末認証でロックを解除してください。';

  @override
  String get authenticationFailed => '認証に失敗しました。';

  @override
  String get unlockSongBriefReason => 'SongBriefのロックを解除します。';

  @override
  String get unlock => 'ロック解除';

  @override
  String get sponsoredPlacement => '広告枠';

  @override
  String get sponsored => '広告';

  @override
  String get adLoadingSmallBanner => '小さなバナー広告を読み込み中';

  @override
  String get adLoaded => '広告を読み込みました';

  @override
  String get adMissingLiveUnit => '公開前に本番のAdMob広告ユニットIDを設定してください';

  @override
  String get adPreviewForLaunchMode => 'この起動モードの広告プレビュー';

  @override
  String get adTemporarilyUnavailable => '広告を一時的に表示できません';

  @override
  String get premiumUnlockedByLaunchMode => '起動モードによりプレミアムが有効です。';

  @override
  String get premiumPurchaseWaiting => 'ストアの購入確認を待っています。';

  @override
  String get premiumRestoreRequestSent => 'ストアへ復元リクエストを送信しました。';

  @override
  String get premiumActiveAdsRemoved => 'プレミアムが有効です。広告は表示されません。';

  @override
  String get premiumPurchasePending => '購入処理が保留中です。';

  @override
  String get premiumPurchaseFailed => '購入に失敗しました。';

  @override
  String get premiumStoreUnavailable => 'ストアを利用できません。';

  @override
  String get premiumConfigureProduct =>
      'App Store Connectで非消耗型の商品を設定すると購入が有効になります。';
}
