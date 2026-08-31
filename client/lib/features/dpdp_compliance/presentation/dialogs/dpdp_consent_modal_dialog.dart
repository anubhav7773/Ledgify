import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/dpdp_purpose.dart';

/// Statutory Indian DPDP Act 2023 Consent Modal Bottom Sheet with plain-language disclosures.
class DpdpConsentModalDialog extends StatelessWidget {
  final DpdpPurpose purpose;

  const DpdpConsentModalDialog({
    super.key,
    required this.purpose,
  });

  static Future<bool?> show(BuildContext context, {required DpdpPurpose purpose}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DpdpConsentModalDialog(purpose: purpose),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Shield Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security, size: 28, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Data Processing Consent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('डेटा उपयोग की सहमति (DPDP Act 2023)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Purpose Title Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purpose.titleEnglish, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(purpose.titleHindi, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Plain Language Statutory Notice (English & Hindi)
          Text(
            purpose.descriptionEnglish,
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            purpose.descriptionHindi,
            style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // User Rights Disclosure
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.debitGreenLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.debitGreen.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.debitGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your Rights: You can withdraw this consent anytime in Settings. Data is never sold or used for public AI training.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.debitGreen.withOpacity(0.9), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons (48dp Touch Targets)
          SizedBox(
            height: AppColors.minTouchTargetSize,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Accept & Continue / स्वीकारें और आगे बढ़ें',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: AppColors.minTouchTargetSize,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.surfaceVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Decline / अस्वीकार करें'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
