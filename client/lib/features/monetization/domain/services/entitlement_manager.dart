import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';

/// Singleton manager holding and evaluating real-time user entitlements and tier gates.
class EntitlementManager extends ChangeNotifier {
  static final EntitlementManager _instance = EntitlementManager._internal();
  factory EntitlementManager() => _instance;
  EntitlementManager._internal();

  SubscriptionModel _currentSubscription = const SubscriptionModel(userId: '');

  SubscriptionModel get currentSubscription => _currentSubscription;

  void updateSubscription(SubscriptionModel newSubscription) {
    _currentSubscription = newSubscription;
    notifyListeners();
  }

  /// Checks if the user is allowed to perform another AI Bill OCR / Voice scan
  bool canPerformAiScan(int currentMonthScanCount) {
    if (_currentSubscription.maxAiScansPerMonth == -1) return true; // Unlimited
    return currentMonthScanCount < _currentSubscription.maxAiScansPerMonth;
  }

  /// Checks if statutory E-Invoicing & E-Way Bill generation is unlocked
  bool canGenerateEInvoice() {
    return _currentSubscription.isEInvoiceEnabled;
  }

  /// Checks if multiple business entities / GSTINs can be managed
  bool canAccessMultiBusiness() {
    return _currentSubscription.isMultiBusinessEnabled;
  }

  /// Checks if user is on Pro or Enterprise tier
  bool get isProOrEnterprise => _currentSubscription.isProOrEnterprise;

  /// Checks if user is on Free tier
  bool get isFreeTier => !isProOrEnterprise;
}
