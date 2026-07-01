import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monetization_config.dart';
import 'purchase_client.dart';

const _premiumEntitlementKey = 'songbrief_premium_entitled_v1';

final premiumControllerProvider =
    AsyncNotifierProvider<PremiumController, PremiumState>(
      PremiumController.new,
    );

class PremiumState {
  const PremiumState({
    required this.entitled,
    required this.productId,
    this.storeSupported = false,
    this.productLoaded = false,
    this.price,
    this.busy = false,
    this.message,
    this.errorMessage,
  });

  final bool entitled;
  final String productId;
  final bool storeSupported;
  final bool productLoaded;
  final String? price;
  final bool busy;
  final String? message;
  final String? errorMessage;

  bool get canPurchase => storeSupported && productLoaded && !entitled && !busy;

  bool get canRestore => storeSupported && !entitled && !busy;

  PremiumState copyWith({
    bool? entitled,
    String? productId,
    bool? storeSupported,
    bool? productLoaded,
    String? price,
    bool clearPrice = false,
    bool? busy,
    String? message,
    String? errorMessage,
  }) {
    return PremiumState(
      entitled: entitled ?? this.entitled,
      productId: productId ?? this.productId,
      storeSupported: storeSupported ?? this.storeSupported,
      productLoaded: productLoaded ?? this.productLoaded,
      price: clearPrice ? null : price ?? this.price,
      busy: busy ?? this.busy,
      message: message,
      errorMessage: errorMessage,
    );
  }
}

class PremiumController extends AsyncNotifier<PremiumState> {
  PurchaseClient? _client;
  StreamSubscription<List<PurchaseUpdate>>? _subscription;

  @override
  Future<PremiumState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEntitlement = prefs.getBool(_premiumEntitlementKey) ?? false;
    final entitled =
        MonetizationConfig.premiumUnlockedAtLaunch || storedEntitlement;

    final client = createPurchaseClient();
    _client = client;
    _subscription = client.updates.listen(_handleUpdates);
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      client.dispose();
    });

    final base = PremiumState(
      entitled: entitled,
      productId: MonetizationConfig.premiumProductId,
      storeSupported: client.isSupported,
      message: MonetizationConfig.premiumUnlockedAtLaunch
          ? 'Premium is unlocked by launch mode.'
          : null,
    );

    if (entitled || !client.isSupported) {
      return base;
    }

    final product = await client.queryProduct(
      MonetizationConfig.premiumProductId,
    );
    return base.copyWith(
      storeSupported: await client.isAvailable(),
      productLoaded: product != null,
      price: product?.price,
      message: product == null
          ? 'Configure the premium product in App Store Connect.'
          : null,
    );
  }

  Future<void> purchaseRemoveAds() async {
    final current = state.value;
    final client = _client;
    if (current == null || client == null || !current.canPurchase) {
      return;
    }

    state = AsyncData(
      current.copyWith(busy: true, message: null, errorMessage: null),
    );
    try {
      await client.buyNonConsumable(current.productId);
      state = AsyncData(
        current.copyWith(
          busy: false,
          message: 'Purchase is waiting for store confirmation.',
          errorMessage: null,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(
        current.copyWith(
          busy: false,
          message: null,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> restorePurchases() async {
    final current = state.value;
    final client = _client;
    if (current == null || client == null || !current.canRestore) {
      return;
    }

    state = AsyncData(
      current.copyWith(busy: true, message: null, errorMessage: null),
    );
    try {
      await client.restorePurchases();
      state = AsyncData(
        current.copyWith(
          busy: false,
          message: 'Restore request sent to the store.',
          errorMessage: null,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(
        current.copyWith(
          busy: false,
          message: null,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _handleUpdates(List<PurchaseUpdate> updates) async {
    final current = state.value;
    final client = _client;
    if (current == null || client == null) {
      return;
    }

    var next = current;
    for (final update in updates) {
      if (update.productId != current.productId) {
        continue;
      }

      switch (update.status) {
        case PurchaseUpdateStatus.purchased:
        case PurchaseUpdateStatus.restored:
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_premiumEntitlementKey, true);
          next = next.copyWith(
            entitled: true,
            busy: false,
            message: 'Premium is active. Ads are removed.',
            errorMessage: null,
          );
        case PurchaseUpdateStatus.pending:
          next = next.copyWith(
            busy: false,
            message: 'Purchase is pending.',
            errorMessage: null,
          );
        case PurchaseUpdateStatus.error:
          next = next.copyWith(
            busy: false,
            message: null,
            errorMessage: update.errorMessage ?? 'Purchase failed.',
          );
      }

      final completionKey = update.completionKey;
      if (completionKey != null) {
        await client.completePurchase(completionKey);
      }
    }

    state = AsyncData(next);
  }
}
