import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../domain/services/entitlement_manager.dart';
import '../../data/repositories/subscription_repository.dart';

/// Screen presenting the Subscription Paywall with Tier selection, Feature Matrix, and Google Play Checkout.
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
      // Simulate Google Play Billing checkout flow
      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully subscribed to $_selectedTier Plan!'),
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription failed: $e'), backgroundColor: LedgifyColors.creditRed),
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
          const SnackBar(content: Text('Purchases restored successfully!'), backgroundColor: LedgifyColors.debitGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Ledgify / प्लान अपग्रेड करें', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LedgifyColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium, color: Color(0xFFFBBF24), size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'Automate Your Entire Accounting\nअपना पूरा हिसाब-किताब ऑटोमेट करें',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'AI Bill Scans, E-Invoicing, BRS, Multi-GSTIN & Direct Tax',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Billing Cycle Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Monthly / मासिक'),
                    selected: !_isAnnual,
                    onSelected: (val) => setState(() => _isAnnual = false),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Annual / वार्षिक (Save 20%)'),
                    selected: _isAnnual,
                    onSelected: (val) => setState(() => _isAnnual = true),
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
                      hindiName: 'प्रो प्लान',
                      price: _isAnnual ? '₹4,999/yr' : '₹499/mo',
                      badge: 'MOST POPULAR',
                      isHighlight: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTierCard(
                      tierId: 'ENTERPRISE',
                      name: 'Enterprise',
                      hindiName: 'एंटरप्राइज',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: LedgifyColors.surfaceVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Plan Capabilities / सुविधाएं', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                height: LedgifyColors.minTouchTargetSize,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LedgifyColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _handleUpgrade,
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Upgrade to $_selectedTier / अभी सदस्यता लें',
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
                    'Restore Purchases / सदस्यता पुनर्स्थापित करें',
                    style: TextStyle(color: LedgifyColors.secondarySlate, fontSize: 12),
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
    required String hindiName,
    required String price,
    required String badge,
    required bool isHighlight,
  }) {
    final isSelected = _selectedTier == tierId;

    return InkWell(
      onTap: () => setState(() => _selectedTier = tierId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? LedgifyColors.primaryContainer.withOpacity(0.4) : LedgifyColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? LedgifyColors.primaryBlue : LedgifyColors.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isHighlight ? const Color(0xFFFEF3C7) : LedgifyColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isHighlight ? const Color(0xFFB45309) : LedgifyColors.secondarySlate,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(hindiName, style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
            const SizedBox(height: 8),

            Text(price, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: LedgifyColors.primaryBlue)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature, String freeVal, String proVal, String entVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text(feature, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(proVal, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue))),
        ],
      ),
    );
  }
}
