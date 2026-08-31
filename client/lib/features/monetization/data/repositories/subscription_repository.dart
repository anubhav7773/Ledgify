import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../../domain/models/subscription_model.dart';
import '../../domain/services/entitlement_manager.dart';
import '../services/play_billing_service.dart';

/// Repository managing user subscriptions, Google Play billing, and backend entitlement sync.
class SubscriptionRepository {
  final SupabaseClient _client;
  final PlayBillingService _billingService;
  final EntitlementManager _entitlementManager;

  SubscriptionRepository({
    SupabaseClient? client,
    PlayBillingService? billingService,
    EntitlementManager? entitlementManager,
  })  : _client = client ?? SupabaseClientService.client,
        _billingService = billingService ?? PlayBillingService(),
        _entitlementManager = entitlementManager ?? EntitlementManager();

  /// Fetches current active subscription & entitlement
  Future<SubscriptionModel> fetchUserSubscription() async {
    return await executeSafely<SubscriptionModel>(() async {
      final user = _client.auth.currentUser;
      if (user == null) {
        return const SubscriptionModel(userId: '');
      }

      final response = await _client.rpc(
        'get_user_entitlement',
        params: {'p_user_id': user.id},
      );

      final model = SubscriptionModel.fromJson(Map<String, dynamic>.from(response as Map));
      _entitlementManager.updateSubscription(model);
      return model;
    });
  }

  /// Records verified client purchase token on the backend
  Future<SubscriptionModel> recordClientPurchase({
    required PurchaseDetails purchaseDetails,
    required String tier, // 'PRO' or 'ENTERPRISE'
  }) async {
    return await executeSafely<SubscriptionModel>(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final response = await _client.rpc(
        'record_subscription_purchase',
        params: {
          'p_user_id': user.id,
          'p_product_id': purchaseDetails.productID,
          'p_purchase_token': purchaseDetails.verificationData.serverVerificationData,
          'p_order_id': purchaseDetails.purchaseID ?? '',
          'p_tier': tier,
        },
      );

      final model = SubscriptionModel.fromJson(Map<String, dynamic>.from(response as Map));
      _entitlementManager.updateSubscription(model);
      return model;
    });
  }

  /// Fetches available Google Play store subscriptions
  Future<List<ProductDetails>> fetchAvailablePlans() async {
    return await _billingService.fetchAvailableSubscriptions();
  }

  /// Initiates subscription purchase
  Future<bool> purchasePlan(ProductDetails productDetails) async {
    return await _billingService.buySubscription(productDetails);
  }

  /// Restores user purchases
  Future<void> restorePurchases() async {
    await _billingService.restorePurchases();
    await fetchUserSubscription();
  }
}
