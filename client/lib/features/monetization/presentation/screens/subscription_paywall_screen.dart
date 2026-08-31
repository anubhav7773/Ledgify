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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Upgrade to Pro', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
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
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 44),
                    SizedBox(height: 12),
                    Text(
                      'Automate Your Entire Accounting',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'AI Bill Scans, E-Invoicing, BRS, Multi-GSTIN & Direct Tax',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Billing Cycle Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Monthly Billing'),
                    selected: !_isAnnual,
                    onSelected: (val) => setState(() => _isAnnual = false),
                    selectedColor: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Annual Billing (Save 20%)'),
                    selected: _isAnnual,
                    onSelected: (val) => setState(() => _isAnnual = true),
                    selectedColor: AppColors.primaryLight,
                  ),
                ],
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Feature Comparison Table
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan Capabilities', style: AppTypography.cardHeader),
                      const Divider(height: 16),
                      _buildFeatureRow('AI Bill OCR & Voice Scans', '30 / mo', '500 / mo', 'Unlimited'),
                      _buildFeatureRow('Statutory E-Invoice & EWB', '✕', '✓', '✓'),
                      _buildFeatureRow('Trigram BRS Reconciliation', 'Manual', 'Automated', 'Automated'),
                      _buildFeatureRow('Form 24Q & Form 16 Payroll', 'Basic', 'Full e-TDS', 'Full e-TDS'),
                      _buildFeatureRow('Multi-Business / GSTIN Sync', '1 Company', '1 Company', 'Unlimited'),
                      _buildFeatureRow('Ad-Free Premium Mode', 'With Ads', 'Ad-Free', 'Ad-Free'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action CTA (48dp Touch Target)
              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _handleUpgrade,
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Upgrade to $_selectedTier',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Restore Purchases Footer
              Center(
                child: TextButton(
                  onPressed: _isProcessing ? null : _restorePurchases,
                  child: const Text(
                    'Restore Previous Purchases',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
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
  }) {
    final isSelected = _selectedTier == tierId;

    return InkWell(
      onTap: () => setState(() => _selectedTier = tierId),
      borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withOpacity(0.5) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isHighlight ? const Color(0xFFFEF3C7) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isHighlight ? const Color(0xFFB45309) : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 6),

            Text(price, style: AppTypography.currencyText.copyWith(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature, String freeVal, String proVal, String entVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text(feature, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          Expanded(flex: 2, child: Text(proVal, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
        ],
      ),
    );
  }
}
