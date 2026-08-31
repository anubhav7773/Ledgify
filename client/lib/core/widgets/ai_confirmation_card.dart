import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// High-Trust AI Confirmation Card displaying extracted document details, confidence score badge,
/// line-items breakdown, and interactive tap-to-edit zones.
/// Adheres strictly to docs/10_ui_ux_design_system_tokens.md and docs/06_gemini_ai_multimodal_pipeline.md.
class AiConfirmationCard extends StatelessWidget {
  final String voucherType;
  final String voucherNumber;
  final String voucherDate;
  final String partyName;
  final String? partyGstin;
  final double totalAmount;
  final double taxableAmount;
  final double taxAmount;
  final double confidenceScore;
  final List<Map<String, dynamic>>? lineItems;
  final VoidCallback onConfirm;
  final VoidCallback? onEditParty;
  final VoidCallback? onEditAmount;
  final VoidCallback? onEditVoucherType;
  final VoidCallback? onEditFullVoucher;
  final bool isSubmitting;

  const AiConfirmationCard({
    super.key,
    required this.voucherType,
    required this.voucherNumber,
    required this.voucherDate,
    required this.partyName,
    this.partyGstin,
    required this.totalAmount,
    required this.taxableAmount,
    required this.taxAmount,
    this.confidenceScore = 0.95,
    this.lineItems,
    required this.onConfirm,
    this.onEditParty,
    this.onEditAmount,
    this.onEditVoucherType,
    this.onEditFullVoucher,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (confidenceScore * 100).round().clamp(0, 100);
    final Color confidenceColor = confidenceScore >= 0.85
        ? AppColors.debitGreen
        : (confidenceScore >= 0.60 ? AppColors.warningAmber : AppColors.creditRed);

    final String confidenceLabel = confidenceScore >= 0.85
        ? 'High Accuracy / उच्च सटीकता ($confidencePercent%)'
        : (confidenceScore >= 0.60
            ? 'Review Suggested / समीक्षा आवश्यक ($confidencePercent%)'
            : 'Low Confidence / कृपया जांचें ($confidencePercent%)');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.surfaceVariant),
      ),
      color: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar with AI Model Badge & Confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Gemini 2.5 Flash',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: confidenceColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    confidenceLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: confidenceColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Document Header & Voucher Type (Tap to Edit)
            InkWell(
              onTap: onEditVoucherType,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              voucherType.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                          ],
                        ),
                        Text('Doc: #$voucherNumber • Date: $voucherDate', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Party Details Row (Tap to Edit)
            InkWell(
              onTap: onEditParty,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(partyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
                            ],
                          ),
                          if (partyGstin != null && partyGstin!.isNotEmpty)
                            Text('GSTIN: $partyGstin', style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 18),

            // Line Items Mini-Preview
            if (lineItems != null && lineItems!.isNotEmpty) ...[
              const Text('Line Items / वस्तु सूची', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              ...lineItems!.take(3).map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['description'] ?? 'Item',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${((item['total'] ?? item['amount'] ?? 0) as num).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 18),
            ],

            // Amount & Tax Breakdown (Tap to Edit)
            InkWell(
              onTap: onEditAmount,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Invoice Amount / कुल राशि', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        Text('Taxable: ₹${taxableAmount.toStringAsFixed(2)} • Tax: ₹${taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.formatInr(totalAmount),
                          style: AppTypography.currencyText.copyWith(fontSize: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons (48dp Touch Targets)
            SizedBox(
              height: AppColors.minTouchTargetSize,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  isSubmitting ? 'Posting Voucher...' : 'Confirm & Post Voucher / पुष्टि करें',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: isSubmitting ? null : onConfirm,
              ),
            ),
            const SizedBox(height: 8),

            if (onEditFullVoucher != null)
              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onEditFullVoucher,
                  child: const Text('Edit Full Voucher / पूरा वाउचर संपादित करें', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
