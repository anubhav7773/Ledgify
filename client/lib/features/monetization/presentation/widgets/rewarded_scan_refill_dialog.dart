import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../data/services/admob_service.dart';
import '../screens/subscription_paywall_screen.dart';

/// Modal dialog offering rewarded ad view for bonus AI bill scans when free limit is exhausted.
class RewardedScanRefillDialog extends StatefulWidget {
  final VoidCallback onRefillSuccess;

  const RewardedScanRefillDialog({
    super.key,
    required this.onRefillSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRefillSuccess,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => RewardedScanRefillDialog(onRefillSuccess: onRefillSuccess),
    );
  }

  @override
  State<RewardedScanRefillDialog> createState() => _RewardedScanRefillDialogState();
}

class _RewardedScanRefillDialogState extends State<RewardedScanRefillDialog> {
  final AdMobService _adMobService = AdMobService();
  bool _isLoadingAd = false;

  void _watchAdForBonus() {
    setState(() => _isLoadingAd = true);

    _adMobService.showRewardedScanRefillAd(
      onRewarded: () {
        if (mounted) {
          setState(() => _isLoadingAd = false);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('+2 Bonus AI Scans Added! / 2 बोनस स्कैन जोड़े गए!'),
              backgroundColor: LedgifyColors.debitGreen,
            ),
          );
          widget.onRefillSuccess();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _isLoadingAd = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load ad: $err'), backgroundColor: LedgifyColors.creditRed),
          );
        }
      },
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LedgifyColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.document_scanner_outlined, size: 36, color: LedgifyColors.primaryBlue),
          ),
          const SizedBox(height: 14),

          Text(
            'Monthly AI Limit Reached\nमासिक स्कैन सीमा समाप्त',
            textAlign: TextAlign.center,
            style: LedgifyTypography.cardHeader.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 8),

          const Text(
            'You have used all 30 free AI invoice scans for this month. Watch a short video to get +2 instant scans or upgrade to Pro for 500 scans.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: LedgifyColors.secondarySlate),
          ),
          const SizedBox(height: 20),

          // Option 1: Watch Ad for +2 scans (48dp Touch Target)
          SizedBox(
            height: LedgifyColors.minTouchTargetSize,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LedgifyColors.debitGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isLoadingAd
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_circle_outline),
              label: Text(
                _isLoadingAd ? 'Loading Video...' : 'Watch Ad for +2 Scans / विज्ञापन देखें',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: _isLoadingAd ? null : _watchAdForBonus,
            ),
          ),
          const SizedBox(height: 10),

          // Option 2: Upgrade to Pro (48dp Touch Target)
          SizedBox(
            height: LedgifyColors.minTouchTargetSize,
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: LedgifyColors.primaryBlue,
                side: const BorderSide(color: LedgifyColors.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Upgrade to Pro (500 Scans)', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
