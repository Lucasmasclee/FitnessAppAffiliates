import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Eenvoudige service om abonnementen te beheren.
///
/// LET OP: zonder backend-verificatie is dit alleen geschikt als basis
/// en niet waterdicht tegen misbruik.
class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService instance = SubscriptionService._internal();

  static const String _monthlyId = 'new_monthly_subscription';
  static const String _yearlyId = 'new_yearly_subscription';
  static const String _prefsKeyHasSubscription = 'has_active_subscription_v1';

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _initialized = false;
  bool _hasActiveSubscription = false;

  bool get hasActiveSubscription => _hasActiveSubscription;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _hasActiveSubscription = prefs.getBool(_prefsKeyHasSubscription) ?? false;

    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('IAP niet beschikbaar op dit device.');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription.cancel(),
      onError: (Object error) {
        debugPrint('Fout in purchaseStream: $error');
      },
    );
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _subscription.cancel();
      _initialized = false;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    bool anyActive = _hasActiveSubscription;
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == _monthlyId ||
            purchase.productID == _yearlyId) {
          anyActive = true;
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    if (anyActive != _hasActiveSubscription) {
      _hasActiveSubscription = anyActive;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyHasSubscription, _hasActiveSubscription);
      debugPrint('Subscription status gewijzigd: $_hasActiveSubscription');
    }
  }

  Future<ProductDetailsResponse> loadProducts() {
    const ids = {_monthlyId, _yearlyId};
    return _iap.queryProductDetails(ids);
  }

  /// Vraag de store om eerdere aankopen te herstellen.
  /// Op Android/iOS zal dit via [purchaseStream] gerapporteerd worden.
  Future<void> restorePurchases() async {
    final available = await _iap.isAvailable();
    if (!available) return;
    await _iap.restorePurchases();
  }

  Future<String?> startPurchase(ProductDetails product) async {
    final available = await _iap.isAvailable();
    if (!available) return 'Store is niet beschikbaar.';

    final param = PurchaseParam(productDetails: product);
    final ok = await _iap.buyNonConsumable(purchaseParam: param);
    if (!ok) {
      return 'Aankoop kon niet gestart worden.';
    }
    return null;
  }
}

