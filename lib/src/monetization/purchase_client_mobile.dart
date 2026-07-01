import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

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
  final InAppPurchase _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _products = {};
  final Map<String, PurchaseDetails> _pendingCompletions = {};

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Stream<List<PurchaseUpdate>> get updates {
    if (!isSupported) {
      return const Stream.empty();
    }
    return _iap.purchaseStream.map(
      (details) => details.map(_toUpdate).toList(growable: false),
    );
  }

  Future<bool> isAvailable() async {
    if (!isSupported) {
      return false;
    }
    return _iap.isAvailable();
  }

  Future<PurchaseProduct?> queryProduct(String productId) async {
    if (!await isAvailable()) {
      return null;
    }
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) {
      return null;
    }

    final detail = response.productDetails.first;
    _products[detail.id] = detail;
    return PurchaseProduct(
      id: detail.id,
      title: detail.title,
      description: detail.description,
      price: detail.price,
    );
  }

  Future<void> buyNonConsumable(String productId) async {
    final detail = _products[productId];
    if (detail == null) {
      throw StateError('Product details are not loaded.');
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: detail),
    );
  }

  Future<void> restorePurchases() {
    if (!isSupported) {
      throw UnsupportedError('In-app purchases are not available here.');
    }
    return _iap.restorePurchases();
  }

  Future<void> completePurchase(String completionKey) async {
    final detail = _pendingCompletions.remove(completionKey);
    if (detail == null) {
      return;
    }
    await _iap.completePurchase(detail);
  }

  void dispose() {
    _pendingCompletions.clear();
  }

  PurchaseUpdate _toUpdate(PurchaseDetails detail) {
    final completionKey = detail.pendingCompletePurchase
        ? (detail.purchaseID ?? '${detail.productID}:${detail.status.name}')
        : null;
    if (completionKey != null) {
      _pendingCompletions[completionKey] = detail;
    }

    return PurchaseUpdate(
      productId: detail.productID,
      status: switch (detail.status) {
        PurchaseStatus.purchased => PurchaseUpdateStatus.purchased,
        PurchaseStatus.restored => PurchaseUpdateStatus.restored,
        PurchaseStatus.pending => PurchaseUpdateStatus.pending,
        PurchaseStatus.error ||
        PurchaseStatus.canceled => PurchaseUpdateStatus.error,
      },
      completionKey: completionKey,
      errorMessage: detail.error?.message,
    );
  }
}
