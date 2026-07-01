import 'package:flutter/widgets.dart';

import 'monetization_config.dart';

enum PlatformAdLoadState { loading, loaded, failed }

typedef PlatformAdPlaceholderBuilder =
    Widget Function(BuildContext context, PlatformAdLoadState state);

bool get adRuntimeCanLoadAds => false;

String? bannerAdUnitIdFor(AdLaunchMode mode) {
  return null;
}

Future<void> initializeAdSdkIfSupported(AdLaunchMode mode) async {}

class PlatformBannerAdView extends StatelessWidget {
  const PlatformBannerAdView({
    required this.adUnitId,
    required this.placeholderBuilder,
    super.key,
  });

  final String adUnitId;
  final PlatformAdPlaceholderBuilder placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    return placeholderBuilder(context, PlatformAdLoadState.failed);
  }
}
