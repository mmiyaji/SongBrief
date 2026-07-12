// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SongBrief';

  @override
  String get appLockedTitle => 'SongBrief 已锁定';

  @override
  String get appLockedSubtitle => '请使用设备认证解锁。';

  @override
  String get authenticationFailed => '认证失败。';

  @override
  String get unlockSongBriefReason => '解锁 SongBrief。';

  @override
  String get unlock => '解锁';

  @override
  String get sponsoredPlacement => '广告位';

  @override
  String get sponsored => '广告';

  @override
  String get adLoadingSmallBanner => '正在加载小横幅广告';

  @override
  String get adLoaded => '广告已加载';

  @override
  String get adMissingLiveUnit => '发布前请设置正式的 AdMob 广告单元 ID';

  @override
  String get adPreviewForLaunchMode => '当前启动模式的广告预览';

  @override
  String get adTemporarilyUnavailable => '广告暂时不可用';

  @override
  String get premiumUnlockedByLaunchMode => '当前启动模式已解锁高级版。';

  @override
  String get premiumPurchaseWaiting => '正在等待商店确认购买。';

  @override
  String get premiumRestoreRequestSent => '已向商店发送恢复请求。';

  @override
  String get premiumActiveAdsRemoved => '高级版已启用，广告已移除。';

  @override
  String get premiumPurchasePending => '购买处理中。';

  @override
  String get premiumPurchaseFailed => '购买失败。';

  @override
  String get premiumStoreUnavailable => '商店当前不可用。';

  @override
  String get premiumConfigureProduct => '在 App Store Connect 中设置非消耗型商品后即可购买。';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => 'SongBrief';

  @override
  String get appLockedTitle => 'SongBrief 已锁定';

  @override
  String get appLockedSubtitle => '请使用设备认证解锁。';

  @override
  String get authenticationFailed => '认证失败。';

  @override
  String get unlockSongBriefReason => '解锁 SongBrief。';

  @override
  String get unlock => '解锁';

  @override
  String get sponsoredPlacement => '广告位';

  @override
  String get sponsored => '广告';

  @override
  String get adLoadingSmallBanner => '正在加载小横幅广告';

  @override
  String get adLoaded => '广告已加载';

  @override
  String get adMissingLiveUnit => '发布前请设置正式的 AdMob 广告单元 ID';

  @override
  String get adPreviewForLaunchMode => '当前启动模式的广告预览';

  @override
  String get adTemporarilyUnavailable => '广告暂时不可用';

  @override
  String get premiumUnlockedByLaunchMode => '当前启动模式已解锁高级版。';

  @override
  String get premiumPurchaseWaiting => '正在等待商店确认购买。';

  @override
  String get premiumRestoreRequestSent => '已向商店发送恢复请求。';

  @override
  String get premiumActiveAdsRemoved => '高级版已启用，广告已移除。';

  @override
  String get premiumPurchasePending => '购买处理中。';

  @override
  String get premiumPurchaseFailed => '购买失败。';

  @override
  String get premiumStoreUnavailable => '商店当前不可用。';

  @override
  String get premiumConfigureProduct => '在 App Store Connect 中设置非消耗型商品后即可购买。';
}
