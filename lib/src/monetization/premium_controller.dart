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

final premiumPurchasesEnabledProvider = Provider<bool>(
  (ref) => MonetizationConfig.premiumPurchasesEnabled,
);

final purchaseClientFactoryProvider = Provider<PurchaseClient Function()>(
  (ref) => createPurchaseClient,
);

class PremiumState {
  const PremiumState({
    required this.entitled,
    required this.productId,
    this.storeSupported = false,
    this.productLoaded = false,
    this.productTitle,
    this.productDescription,
    this.price,
    this.busy = false,
    this.message,
    this.errorMessage,
  });

  final bool entitled;
  final String productId;
  final bool storeSupported;
  final bool productLoaded;
  final String? productTitle;
  final String? productDescription;
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
    String? productTitle,
    bool clearProductTitle = false,
    String? productDescription,
    bool clearProductDescription = false,
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
      productTitle: clearProductTitle
          ? null
          : productTitle ?? this.productTitle,
      productDescription: clearProductDescription
          ? null
          : productDescription ?? this.productDescription,
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
  final _pendingUpdates = <List<PurchaseUpdate>>[];
  var _buildFinished = false;
  Future<void> _updateQueue = Future<void>.value();

  @override
  Future<PremiumState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEntitlement = prefs.getBool(_premiumEntitlementKey) ?? false;
    final entitled =
        MonetizationConfig.premiumUnlockedAtLaunch || storedEntitlement;

    final base = PremiumState(
      entitled: entitled,
      productId: MonetizationConfig.premiumProductId,
      storeSupported: false,
      message: MonetizationConfig.premiumUnlockedAtLaunch
          ? 'Premium is unlocked by launch mode.'
          : null,
    );

    if (!ref.read(premiumPurchasesEnabledProvider)) {
      return base;
    }

    final client = ref.read(purchaseClientFactoryProvider)();
    _client = client;
    _buildFinished = false;
    _pendingUpdates.clear();
    _subscription = client.updates.listen(_handleUpdates);
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      client.dispose();
    });

    final purchaseBase = base.copyWith(storeSupported: client.isSupported);

    var result = (entitled || !client.isSupported)
        ? purchaseBase
        : await _queryProduct(purchaseBase);

    // Updates that the store re-delivers at launch can arrive before the
    // product has loaded. Apply them here so the returned state includes them.
    while (_pendingUpdates.isNotEmpty) {
      final batch = _pendingUpdates.removeAt(0);
      result = await _applyUpdates(client, result, batch);
    }
    _buildFinished = true;
    // Live batches start after an event-loop turn, by which time Riverpod has
    // published the returned state, so they never observe a null state.
    _updateQueue = Future<void>(() {});
    return result;
  }

  Future<void> reloadProduct() async {
    final current = state.value;
    if (current == null || current.entitled || current.busy) {
      return;
    }
    state = AsyncData(
      current.copyWith(busy: true, message: null, errorMessage: null),
    );
    state = AsyncData(await _queryProduct(current.copyWith(busy: false)));
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

  void _handleUpdates(List<PurchaseUpdate> updates) {
    if (!_buildFinished) {
      _pendingUpdates.add(updates);
      return;
    }
    // Batches run one at a time so each reads the state left by the previous
    // batch. A failed batch must not stop later ones, and any transaction it
    // did not complete stays queued for the store to deliver again.
    _updateQueue = _updateQueue
        .then((_) => _processLiveUpdates(updates))
        .catchError((Object _) {});
  }

  Future<void> _processLiveUpdates(List<PurchaseUpdate> updates) async {
    final client = _client;
    final current = state.value;
    if (client == null || current == null) {
      return;
    }

    final next = await _applyUpdates(client, current, updates);
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(next);
  }

  Future<PremiumState> _applyUpdates(
    PurchaseClient client,
    PremiumState current,
    List<PurchaseUpdate> updates,
  ) async {
    var next = current;
    for (final update in updates) {
      // A transaction is completed only after its result is saved, so a
      // failed save is redelivered by the store on the next launch.
      var canComplete = true;
      if (update.productId == current.productId) {
        switch (update.status) {
          case PurchaseUpdateStatus.purchased:
          case PurchaseUpdateStatus.restored:
            canComplete = await _saveEntitlement();
            next = canComplete
                ? next.copyWith(
                    entitled: true,
                    busy: false,
                    message: 'Premium is active. Ads are removed.',
                    errorMessage: null,
                  )
                : next.copyWith(
                    busy: false,
                    message: null,
                    errorMessage:
                        'Premium could not be saved. Try again later.',
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
      }

      final completionKey = update.completionKey;
      if (completionKey != null && canComplete) {
        await client.completePurchase(completionKey);
      }
    }
    return next;
  }

  Future<bool> _saveEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_premiumEntitlementKey, true);
    } on Object {
      return false;
    }
  }

  Future<PremiumState> _queryProduct(PremiumState base) async {
    final client = _client;
    if (client == null || !client.isSupported) {
      return base.copyWith(
        storeSupported: false,
        productLoaded: false,
        clearProductTitle: true,
        clearProductDescription: true,
        clearPrice: true,
      );
    }

    final storeAvailable = await client.isAvailable();
    if (!storeAvailable) {
      return base.copyWith(
        storeSupported: false,
        productLoaded: false,
        clearProductTitle: true,
        clearProductDescription: true,
        clearPrice: true,
        message: 'Store is not available.',
      );
    }

    final product = await client.queryProduct(base.productId);
    return base.copyWith(
      storeSupported: true,
      productLoaded: product != null,
      productTitle: product?.title,
      clearProductTitle: product == null,
      productDescription: product?.description,
      clearProductDescription: product == null,
      price: product?.price,
      clearPrice: product == null,
      message: product == null
          ? 'Configure the premium product in App Store Connect.'
          : null,
    );
  }
}
