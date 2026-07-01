import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'monetization_config.dart';

enum PlatformAdLoadState { loading, loaded, failed }

typedef PlatformAdPlaceholderBuilder =
    Widget Function(BuildContext context, PlatformAdLoadState state);

const _androidTestBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const _iosTestBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

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
  await MobileAds.instance.initialize();
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
