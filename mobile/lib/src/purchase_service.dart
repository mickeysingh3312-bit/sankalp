import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static const productId = 'sankalp_premium_monthly';

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? product;

  Future<bool> initialize(
    Future<void> Function(PurchaseDetails purchase) onVerified,
  ) async {
    await _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await onVerified(purchase);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }, onError: (_) {});
    if (!await _iap.isAvailable()) return false;
    final response = await _iap.queryProductDetails({productId});
    product = response.productDetails.isEmpty ? null : response.productDetails.first;
    return product != null;
  }

  Future<void> buy() async {
    final item = product;
    if (item == null) throw StateError('Premium is not available yet.');
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: item));
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> dispose() async => _subscription?.cancel();
}
