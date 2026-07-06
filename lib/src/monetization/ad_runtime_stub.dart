import 'package:flutter/widgets.dart';

import 'ad_consent_state.dart';
import 'monetization_config.dart';

enum PlatformAdLoadState { waitingForConsent, loading, loaded, failed }

typedef PlatformAdPlaceholderBuilder =
    Widget Function(BuildContext context, PlatformAdLoadState state);

bool get adRuntimeCanLoadAds => false;

String? bannerAdUnitIdFor(AdLaunchMode mode) {
  return null;
}

Future<void> initializeAdSdkIfSupported(AdLaunchMode mode) async {}

Future<PlatformAdConsentResult> updateAdConsentIfSupported() async {
  return const PlatformAdConsentResult.unsupported();
}

Future<PlatformAdConsentResult> showAdPrivacyOptionsIfSupported() async {
  return const PlatformAdConsentResult.unsupported();
}

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
