import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../screens/subscription_paywall_screen.dart';

/// Modal dialog intercepting restricted actions on Free Tier and prompting an upgrade.
class TierFeatureGateModal extends StatelessWidget {
  final String featureName;
  final String featureDescription;

  const TierFeatureGateModal({
    super.key,
    required this.featureName,
    required this.featureDescription,
  });

  static Future<void> show(
    BuildContext context, {
    required String featureName,
    required String featureDescription,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => TierFeatureGateModal(
        featureName: featureName,
        featureDescription: featureDescription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LedgifyColors.warningOrange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, size: 36, color: LedgifyColors.warningOrange),
          ),
          const SizedBox(height: 14),

          Text(
            'Pro Feature / प्रो सुविधा',
            style: LedgifyTypography.cardHeader.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          Text(
            featureName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: LedgifyColors.primaryBlue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            featureDescription,
            style: const TextStyle(fontSize: 12.5, color: LedgifyColors.secondarySlate),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Upgrade Button (48dp Touch Target)
          SizedBox(
            height: LedgifyColors.minTouchTargetSize,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LedgifyColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.star, size: 18),
              label: const Text('Upgrade to Pro / अपग्रेड करें', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later / बाद में'),
          ),
        ],
      ),
    );
  }
}
