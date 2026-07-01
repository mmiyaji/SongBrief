import 'dart:async';

enum PurchaseUpdateStatus { purchased, restored, pending, error }

class PurchaseProduct {
  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });

  final String id;
  final String title;
  final String description;
  final String price;
}

class PurchaseUpdate {
  const PurchaseUpdate({
    required this.productId,
    required this.status,
    this.completionKey,
    this.errorMessage,
  });

  final String productId;
  final PurchaseUpdateStatus status;
  final String? completionKey;
  final String? errorMessage;
}

PurchaseClient createPurchaseClient() => PurchaseClient();

class PurchaseClient {
  bool get isSupported => false;

  Stream<List<PurchaseUpdate>> get updates => const Stream.empty();

  Future<bool> isAvailable() async => false;

  Future<PurchaseProduct?> queryProduct(String productId) async => null;

  Future<void> buyNonConsumable(String productId) async {
    throw UnsupportedError('In-app purchases are not available here.');
  }

  Future<void> restorePurchases() async {
    throw UnsupportedError('In-app purchases are not available here.');
  }

  Future<void> completePurchase(String completionKey) async {}

  void dispose() {}
}
