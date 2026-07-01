enum AdLaunchMode {
  off,
  admobTest,
  admobLive;

  bool get showsAdSlots => this != AdLaunchMode.off;

  bool get usesLiveAdUnits => this == AdLaunchMode.admobLive;
}

class MonetizationConfig {
  const MonetizationConfig._();

  static const rawAdMode = String.fromEnvironment(
    'SONGBRIEF_AD_MODE',
    defaultValue: 'off',
  );

  static const premiumUnlockedAtLaunch = bool.fromEnvironment(
    'SONGBRIEF_PREMIUM_UNLOCKED',
  );

  static const premiumProductId = String.fromEnvironment(
    'SONGBRIEF_PREMIUM_PRODUCT_ID',
    defaultValue: 'songbrief_premium_lifetime',
  );

  static const androidBannerAdUnitId = String.fromEnvironment(
    'SONGBRIEF_ADMOB_ANDROID_BANNER_AD_UNIT_ID',
  );

  static const iosBannerAdUnitId = String.fromEnvironment(
    'SONGBRIEF_ADMOB_IOS_BANNER_AD_UNIT_ID',
  );

  static AdLaunchMode get adMode {
    final normalized = rawAdMode.trim().toLowerCase().replaceAll('-', '');
    return switch (normalized) {
      'test' || 'admobtest' => AdLaunchMode.admobTest,
      'live' || 'admoblive' => AdLaunchMode.admobLive,
      _ => AdLaunchMode.off,
    };
  }
}
