import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/monetization/monetization_config.dart';
import 'package:songbrief/src/monetization/premium_controller.dart';
import 'package:songbrief/src/monetization/purchase_client.dart';

const _entitlementKey = 'songbrief_premium_entitled_v1';
const _productId = MonetizationConfig.premiumProductId;

void main() {
  test(
    'applies purchases re-delivered before the product has loaded',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = _FakePurchaseClient();
      final container = _createContainer(client);
      addTearDown(container.dispose);

      container.read(premiumControllerProvider);
      await client.listened;
      // The store is still loading the product here, so the controller's state
      // has no value yet when this update is delivered.
      client.emit([
        _update(_productId, PurchaseUpdateStatus.restored, 'launch'),
      ]);
      client.releaseStore();

      final state = await container.read(premiumControllerProvider.future);

      expect(state.entitled, isTrue);
      expect(client.completedKeys, ['launch']);
      expect(client.entitlementAtCompletion, [true]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_entitlementKey), isTrue);
    },
  );

  test(
    'completes updates for other products without granting premium',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = _FakePurchaseClient()..releaseStore();
      final container = _createContainer(client);
      addTearDown(container.dispose);
      await container.read(premiumControllerProvider.future);

      client.emit([
        _update('other_product', PurchaseUpdateStatus.purchased, 'other'),
      ]);
      await _pumpUntil(() => client.completedKeys.isNotEmpty);

      expect(client.completedKeys, ['other']);
      final state = container.read(premiumControllerProvider).requireValue;
      expect(state.entitled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_entitlementKey), isNull);
    },
  );

  test('records store errors and completes the failed transaction', () async {
    SharedPreferences.setMockInitialValues({});
    final client = _FakePurchaseClient()..releaseStore();
    final container = _createContainer(client);
    addTearDown(container.dispose);
    await container.read(premiumControllerProvider.future);

    client.emit([
      const PurchaseUpdate(
        productId: _productId,
        status: PurchaseUpdateStatus.error,
        completionKey: 'failed',
        errorMessage: 'Store rejected the purchase.',
      ),
    ]);
    await _pumpUntil(() => client.completedKeys.isNotEmpty);

    expect(client.completedKeys, ['failed']);
    final state = container.read(premiumControllerProvider).requireValue;
    expect(state.entitled, isFalse);
    expect(state.errorMessage, 'Store rejected the purchase.');
  });

  test('keeps an earlier purchase when a pending batch follows it', () async {
    SharedPreferences.setMockInitialValues({});
    final client = _FakePurchaseClient()..releaseStore();
    final container = _createContainer(client);
    addTearDown(container.dispose);
    await container.read(premiumControllerProvider.future);

    client.emit([_update(_productId, PurchaseUpdateStatus.purchased, 'first')]);
    client.emit([_update(_productId, PurchaseUpdateStatus.pending, 'second')]);
    await _pumpUntil(() => client.completedKeys.length == 2);

    expect(client.completedKeys, ['first', 'second']);
    final state = container.read(premiumControllerProvider).requireValue;
    expect(state.entitled, isTrue);
    expect(state.message, 'Purchase is pending.');
  });
}

ProviderContainer _createContainer(_FakePurchaseClient client) {
  return ProviderContainer(
    overrides: [
      premiumPurchasesEnabledProvider.overrideWithValue(true),
      purchaseClientFactoryProvider.overrideWithValue(() => client),
    ],
  );
}

PurchaseUpdate _update(
  String productId,
  PurchaseUpdateStatus status,
  String completionKey,
) {
  return PurchaseUpdate(
    productId: productId,
    status: status,
    completionKey: completionKey,
  );
}

Future<void> _pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakePurchaseClient implements PurchaseClient {
  final _updates = StreamController<List<PurchaseUpdate>>();
  final _listenedCompleter = Completer<void>();
  final _storeReady = Completer<void>();
  final completedKeys = <String>[];
  final entitlementAtCompletion = <bool>[];

  Future<void> get listened => _listenedCompleter.future;

  void emit(List<PurchaseUpdate> updates) => _updates.add(updates);

  void releaseStore() {
    if (!_storeReady.isCompleted) {
      _storeReady.complete();
    }
  }

  @override
  bool get isSupported => true;

  @override
  Stream<List<PurchaseUpdate>> get updates {
    if (!_listenedCompleter.isCompleted) {
      _listenedCompleter.complete();
    }
    return _updates.stream;
  }

  @override
  Future<bool> isAvailable() async {
    await _storeReady.future;
    return true;
  }

  @override
  Future<PurchaseProduct?> queryProduct(String productId) async {
    return PurchaseProduct(
      id: productId,
      title: 'SongBrief Premium',
      description: 'Removes ads.',
      price: '\$2.99',
    );
  }

  @override
  Future<void> buyNonConsumable(String productId) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(String completionKey) async {
    final prefs = await SharedPreferences.getInstance();
    entitlementAtCompletion.add(prefs.getBool(_entitlementKey) ?? false);
    completedKeys.add(completionKey);
  }

  @override
  void dispose() {
    unawaited(_updates.close());
  }
}
