import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_runtime.dart';
import 'monetization_config.dart';
import 'premium_controller.dart';

String _adText(BuildContext context, String en, String ja) {
  return Localizations.localeOf(context).languageCode == 'ja' ? ja : en;
}

final adDisplayConfigProvider = Provider<AdDisplayConfig>((ref) {
  final premium = ref.watch(premiumControllerProvider);
  final premiumState = premium.value;
  final mode = MonetizationConfig.adMode;
  final adUnitId = bannerAdUnitIdFor(mode);
  final premiumEntitled =
      premiumState?.entitled ?? MonetizationConfig.premiumUnlockedAtLaunch;

  return AdDisplayConfig(
    mode: mode,
    premiumReady: premium.hasValue,
    premiumEntitled: premiumEntitled,
    platformCanLoadAds: adRuntimeCanLoadAds,
    bannerAdUnitId: adUnitId,
  );
});

final adSdkInitializationProvider = FutureProvider<void>((ref) {
  final config = ref.watch(adDisplayConfigProvider);
  if (!config.canLoadPlatformAd) {
    return Future<void>.value();
  }
  return initializeAdSdkIfSupported(config.mode);
});

class AdDisplayConfig {
  const AdDisplayConfig({
    required this.mode,
    required this.premiumReady,
    required this.premiumEntitled,
    required this.platformCanLoadAds,
    required this.bannerAdUnitId,
  });

  final AdLaunchMode mode;
  final bool premiumReady;
  final bool premiumEntitled;
  final bool platformCanLoadAds;
  final String? bannerAdUnitId;

  bool get shouldShowSlot =>
      premiumReady && mode.showsAdSlots && !premiumEntitled;

  bool get canLoadPlatformAd =>
      shouldShowSlot && platformCanLoadAds && bannerAdUnitId != null;

  bool get missingLiveAdUnit =>
      shouldShowSlot && mode.usesLiveAdUnits && bannerAdUnitId == null;
}

class AdBannerSlot extends ConsumerWidget {
  const AdBannerSlot({required this.placement, super.key});

  final String placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(adDisplayConfigProvider);
    if (!config.shouldShowSlot) {
      return const SizedBox.shrink();
    }

    if (config.canLoadPlatformAd) {
      final initialization = ref.watch(adSdkInitializationProvider);
      return initialization.when(
        data: (_) => _AdSlotFrame(
          placement: placement,
          child: PlatformBannerAdView(
            adUnitId: config.bannerAdUnitId!,
            placeholderBuilder: (context, state) =>
                _AdPlaceholder(state: state, config: config),
          ),
        ),
        loading: () => _AdSlotFrame(
          placement: placement,
          child: _AdPlaceholder(
            state: PlatformAdLoadState.loading,
            config: config,
          ),
        ),
        error: (_, _) => _AdSlotFrame(
          placement: placement,
          child: _AdPlaceholder(
            state: PlatformAdLoadState.failed,
            config: config,
          ),
        ),
      );
    }

    return _AdSlotFrame(
      placement: placement,
      child: _AdPlaceholder(state: PlatformAdLoadState.failed, config: config),
    );
  }
}

class _AdSlotFrame extends StatelessWidget {
  const _AdSlotFrame({required this.placement, required this.child});

  final String placement;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: _adText(context, 'Sponsored placement', '広告枠'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.42,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.ads_click_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _adText(context, 'Sponsored', '広告'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    placement,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.72,
                      ),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder({required this.state, required this.config});

  final PlatformAdLoadState state;
  final AdDisplayConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (state) {
      PlatformAdLoadState.loading => _adText(
        context,
        'Loading a small banner ad',
        '小さなバナー広告を読み込み中',
      ),
      PlatformAdLoadState.loaded => _adText(context, 'Ad loaded', '広告を読み込みました'),
      PlatformAdLoadState.failed when config.missingLiveAdUnit => _adText(
        context,
        'Set a live AdMob ad unit ID before release',
        '公開前に本番のAdMob広告ユニットIDを設定してください',
      ),
      PlatformAdLoadState.failed when !config.platformCanLoadAds => _adText(
        context,
        'Ad preview for this launch mode',
        'この起動モードの広告プレビュー',
      ),
      PlatformAdLoadState.failed => _adText(
        context,
        'Ad is temporarily unavailable',
        '広告を一時的に表示できません',
      ),
    };

    return SizedBox(
      height: 50,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
