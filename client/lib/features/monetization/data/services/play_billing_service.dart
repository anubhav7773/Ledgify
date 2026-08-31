import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Service managing native Google Play Billing 7.0+ subscription lifecycle in Flutter.
class PlayBillingService {
  final InAppPurchase _inAppPurchase;
  StreamSubscription<List<PurchaseDetails>>? _subscriptionStream;

  static const Set<String> subscriptionProductIds = {
    'ledgify_pro_monthly',
    'ledgify_pro_annual',
    'ledgify_enterprise_annual',
  };

  PlayBillingService({InAppPurchase? inAppPurchase})
      : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  /// Initializes the billing connection and attaches purchase stream listener
  void initialize({
    required Function(PurchaseDetails) onPurchaseSuccess,
    required Function(String) onPurchaseError,
  }) {
    _subscriptionStream = _inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _handlePurchaseUpdates(
          purchaseDetailsList,
          onPurchaseSuccess: onPurchaseSuccess,
          onPurchaseError: onPurchaseError,
        );
      },
      onDone: () => _subscriptionStream?.cancel(),
      onError: (error) => onPurchaseError(error.toString()),
    );
  }

  /// Fetches available subscription products from Google Play
  Future<List<ProductDetails>> fetchAvailableSubscriptions() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) return [];

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(subscriptionProductIds);

    if (response.error != null) {
      return [];
    }

    return response.productDetails;
  }

  /// Initiates subscription purchase flow
  Future<bool> buySubscription(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restores previous user purchases
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList, {
    required Function(PurchaseDetails) onPurchaseSuccess,
    required Function(String) onPurchaseError,
  }) async {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // Pending state (e.g. UPI payment processing)
      } else if (purchase.status == PurchaseStatus.error) {
        onPurchaseError(purchase.error?.message ?? 'Purchase failed');
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        onPurchaseSuccess(purchase);
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      }
    }
  }

  void dispose() {
    _subscriptionStream?.cancel();
  }
}
