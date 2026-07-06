import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_consent_state.dart';
import 'monetization_config.dart';

enum PlatformAdLoadState { waitingForConsent, loading, loaded, failed }

typedef PlatformAdPlaceholderBuilder =
    Widget Function(BuildContext context, PlatformAdLoadState state);

const _androidTestBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const _iosTestBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

Future<InitializationStatus>? _mobileAdsInitialization;

bool get adRuntimeCanLoadAds => Platform.isAndroid || Platform.isIOS;

String? bannerAdUnitIdFor(AdLaunchMode mode) {
  if (!adRuntimeCanLoadAds || mode == AdLaunchMode.off) {
    return null;
  }

  if (mode == AdLaunchMode.admobTest) {
    return Platform.isAndroid
        ? _androidTestBannerAdUnitId
        : _iosTestBannerAdUnitId;
  }

  final liveUnitId = Platform.isAndroid
      ? MonetizationConfig.androidBannerAdUnitId
      : MonetizationConfig.iosBannerAdUnitId;
  return liveUnitId.trim().isEmpty ? null : liveUnitId.trim();
}

Future<void> initializeAdSdkIfSupported(AdLaunchMode mode) async {
  if (!adRuntimeCanLoadAds || mode == AdLaunchMode.off) {
    return;
  }

  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
  );
  _mobileAdsInitialization ??= MobileAds.instance.initialize();
  await _mobileAdsInitialization;
}

Future<PlatformAdConsentResult> updateAdConsentIfSupported() async {
  if (!adRuntimeCanLoadAds) {
    return const PlatformAdConsentResult.unsupported();
  }

  final requestError = await _requestConsentInfoUpdate();
  FormError? formError;
  if (requestError == null) {
    formError = await _loadAndShowConsentFormIfRequired();
  }
  return _readPlatformConsentResult(requestError ?? formError);
}

Future<PlatformAdConsentResult> showAdPrivacyOptionsIfSupported() async {
  if (!adRuntimeCanLoadAds) {
    return const PlatformAdConsentResult.unsupported();
  }

  final formError = await _showPrivacyOptionsForm();
  return _readPlatformConsentResult(formError);
}

Future<FormError?> _requestConsentInfoUpdate() {
  final completer = Completer<FormError?>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    _consentRequestParameters(),
    () => completer.complete(null),
    completer.complete,
  );
  return completer.future;
}

ConsentRequestParameters _consentRequestParameters() {
  return ConsentRequestParameters(
    tagForUnderAgeOfConsent: false,
    consentDebugSettings: _consentDebugSettings(),
  );
}

ConsentDebugSettings? _consentDebugSettings() {
  if (kReleaseMode) {
    return null;
  }

  if (!MonetizationConfig.umpDebugGeographyEea &&
      MonetizationConfig.umpDebugTestDeviceIds.trim().isEmpty) {
    return null;
  }

  return ConsentDebugSettings(
    debugGeography: MonetizationConfig.umpDebugGeographyEea
        ? DebugGeography.debugGeographyEea
        : null,
    testIdentifiers: _debugTestDeviceIds(),
  );
}

List<String>? _debugTestDeviceIds() {
  final ids = MonetizationConfig.umpDebugTestDeviceIds
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  return ids.isEmpty ? null : ids;
}

Future<FormError?> _loadAndShowConsentFormIfRequired() {
  final completer = Completer<FormError?>();
  ConsentForm.loadAndShowConsentFormIfRequired(completer.complete);
  return completer.future;
}

Future<FormError?> _showPrivacyOptionsForm() {
  final completer = Completer<FormError?>();
  ConsentForm.showPrivacyOptionsForm(completer.complete);
  return completer.future;
}

Future<PlatformAdConsentResult> _readPlatformConsentResult(
  FormError? error,
) async {
  final canRequestAds = await ConsentInformation.instance.canRequestAds();
  final privacyOptionsRequired =
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;
  return PlatformAdConsentResult(
    supported: true,
    canRequestAds: canRequestAds,
    privacyOptionsRequired: privacyOptionsRequired,
    errorMessage: _consentErrorMessage(error),
  );
}

String? _consentErrorMessage(FormError? error) {
  if (error == null) {
    return null;
  }
  return '${error.errorCode}: ${error.message}';
}

class PlatformBannerAdView extends StatefulWidget {
  const PlatformBannerAdView({
    required this.adUnitId,
    required this.placeholderBuilder,
    super.key,
  });

  final String adUnitId;
  final PlatformAdPlaceholderBuilder placeholderBuilder;

  @override
  State<PlatformBannerAdView> createState() => _PlatformBannerAdViewState();
}

class _PlatformBannerAdViewState extends State<PlatformBannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlatformBannerAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId) {
      _load();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load() {
    _ad?.dispose();
    setState(() {
      _ad = null;
      _loaded = false;
      _failed = false;
    });

    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(
        keywords: ['music', 'library', 'statistics'],
        nonPersonalizedAds: true,
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as BannerAd;
            _loaded = true;
            _failed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _ad = null;
            _loaded = false;
            _failed = true;
          });
        },
      ),
    );

    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && _ad != null) {
      return Center(
        child: SizedBox(
          width: AdSize.banner.width.toDouble(),
          height: AdSize.banner.height.toDouble(),
          child: AdWidget(ad: _ad!),
        ),
      );
    }

    return widget.placeholderBuilder(
      context,
      _failed ? PlatformAdLoadState.failed : PlatformAdLoadState.loading,
    );
  }
}
