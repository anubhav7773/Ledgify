/// Domain model representing a user's subscription entitlement state.
/// Adheres strictly to docs/09_monetization_play_billing_and_admob.md.
class SubscriptionModel {
  final String userId;
  final String tier; // 'FREE', 'PRO', 'ENTERPRISE'
  final bool hasActiveSubscription;
  final bool isInGracePeriod;
  final DateTime? currentPeriodEnd;
  final int maxAiScansPerMonth;
  final bool isMultiBusinessEnabled;
  final bool isEInvoiceEnabled;

  const SubscriptionModel({
    required this.userId,
    this.tier = 'FREE',
    this.hasActiveSubscription = false,
    this.isInGracePeriod = false,
    this.currentPeriodEnd,
    this.maxAiScansPerMonth = 30,
    this.isMultiBusinessEnabled = false,
    this.isEInvoiceEnabled = false,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      userId: json['user_id'] as String? ?? '',
      tier: json['tier'] as String? ?? 'FREE',
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? false,
      isInGracePeriod: json['is_in_grace_period'] as bool? ?? false,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      maxAiScansPerMonth: json['max_ai_scans_per_month'] as int? ?? 30,
      isMultiBusinessEnabled: json['is_multi_business_enabled'] as bool? ?? false,
      isEInvoiceEnabled: json['is_e_invoice_enabled'] as bool? ?? false,
    );
  }

  factory SubscriptionModel.free(String userId) {
    return SubscriptionModel(
      userId: userId,
      tier: 'FREE',
      hasActiveSubscription: false,
      maxAiScansPerMonth: 30,
      isMultiBusinessEnabled: false,
      isEInvoiceEnabled: false,
    );
  }

  bool get isProOrEnterprise => tier == 'PRO' || tier == 'ENTERPRISE';
  bool get isEnterprise => tier == 'ENTERPRISE';

  int? get daysRemaining {
    if (currentPeriodEnd == null) return null;
    return currentPeriodEnd!.difference(DateTime.now()).inDays;
  }
}
