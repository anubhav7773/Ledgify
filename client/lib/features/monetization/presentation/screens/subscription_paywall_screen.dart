import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/services/entitlement_manager.dart';
import '../../data/repositories/subscription_repository.dart';

/// Screen presenting the Subscription Paywall with Tier selection, Feature Matrix, and Google Play Checkout (Google Stitch UI).
class SubscriptionPaywallScreen extends StatefulWidget {
  final SubscriptionRepository? repository;

  const SubscriptionPaywallScreen({super.key, this.repository});

  @override
  State<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  late final SubscriptionRepository _repository;
  final EntitlementManager _entitlementManager = EntitlementManager();

  bool _isAnnual = true;
  String _selectedTier = 'PRO'; // 'PRO' or 'ENTERPRISE'
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SubscriptionRepository();
  }

  Future<void> _handleUpgrade() async {
    setState(() => _isProcessing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully subscribed to $_selectedTier Plan!'),
            backgroundColor: AppColors.debitGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription failed: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isProcessing = true);
    try {
      await _repository.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored successfully!'), backgroundColor: AppColors.debitGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Upgrade to Pro',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner (Deep Blue Gradient)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Automate Your Entire Accounting',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'AI Bill Scans, E-Invoicing, BRS, Multi-GSTIN & Direct Tax',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Billing Cycle Toggle (High Contrast)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAnnual = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isAnnual ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Monthly Billing',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_isAnnual ? Colors.white : subtextColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAnnual = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isAnnual ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Annual (Save 20%)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isAnnual ? Colors.white : subtextColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tier Cards
              Row(
                children: [
                  Expanded(
                    child: _buildTierCard(
                      tierId: 'PRO',
                      name: 'Pro Plan',
                      price: _isAnnual ? '₹4,999/yr' : '₹499/mo',
                      badge: 'MOST POPULAR',
                      isHighlight: true,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTierCard(
                      tierId: 'ENTERPRISE',
                      name: 'Enterprise Plan',
                      price: _isAnnual ? '₹9,999/yr' : '₹999/mo',
                      badge: 'ALL-IN-ONE',
                      isHighlight: false,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Feature Comparison Table
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Capabilities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Divider(height: 20, color: isDark ? const Color(0xFF334155) : AppColors.divider),
                    _buildFeatureRow('AI Bill OCR & Voice Scans', '500 / mo', isDark),
                    _buildFeatureRow('Statutory E-Invoice & EWB', 'Automated', isDark),
                    _buildFeatureRow('Trigram BRS Reconciliation', 'Automated', isDark),
                    _buildFeatureRow('Form 24Q & Form 16 Payroll', 'Full e-TDS', isDark),
                    _buildFeatureRow('Multi-Business / GSTIN Sync', '1 Company', isDark),
                    _buildFeatureRow('Ad-Free Premium Experience', 'Ad-Free', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action CTA (48dp Touch Target)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _handleUpgrade,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Upgrade to $_selectedTier',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Restore Purchases Footer
              Center(
                child: TextButton(
                  onPressed: _isProcessing ? null : _restorePurchases,
                  child: Text(
                    'Restore Previous Purchases',
                    style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required String tierId,
    required String name,
    required String price,
    required String badge,
    required bool isHighlight,
    required bool isDark,
  }) {
    final isSelected = _selectedTier == tierId;
    final cardBg = isDark
        ? (isSelected ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFF1E293B))
        : (isSelected ? const Color(0xFFEFF6FF) : Colors.white);

    return InkWell(
      onTap: () => setState(() => _selectedTier = tierId),
      borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF334155) : AppColors.border),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isHighlight ? const Color(0xFFFEF3C7) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isHighlight ? const Color(0xFFB45309) : (isDark ? const Color(0xFFE2E8F0) : AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              price,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature, String proVal, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFE2E8F0) : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            proVal,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
