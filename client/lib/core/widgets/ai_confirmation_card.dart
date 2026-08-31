import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// High-Trust AI Confirmation Card displaying extracted document details, confidence score badge,
/// line-items breakdown, and interactive tap-to-edit zones.
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
        ? 'High Accuracy ($confidencePercent%)'
        : (confidenceScore >= 0.60
            ? 'Review Suggested ($confidencePercent%)'
            : 'Low Confidence ($confidencePercent%)');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar with AI Model Badge & Confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        'Gemini 2.5 Flash',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidenceColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    confidenceLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: confidenceColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Document Header & Voucher Type (Tap to Edit)
            InkWell(
              onTap: onEditVoucherType,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Doc: #$voucherNumber • Date: $voucherDate',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: Color(0xFF475569)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

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
                              Text(
                                partyName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF475569)),
                            ],
                          ),
                          if (partyGstin != null && partyGstin!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'GSTIN: $partyGstin',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20, color: AppColors.divider),

            // Line Items Mini-Preview
            if (lineItems != null && lineItems!.isNotEmpty) ...[
              const Text(
                'Line Items',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              ...lineItems!.take(4).map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['description'] ?? 'Item',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${((item['total_amount'] ?? item['total'] ?? item['amount'] ?? 0) as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20, color: AppColors.divider),
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
                        const Text(
                          'Total Invoice Amount',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Taxable: ₹${taxableAmount.toStringAsFixed(2)} • Tax: ₹${taxAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.formatInr(totalAmount),
                          style: AppTypography.currencyText.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons (48dp Touch Targets)
            SizedBox(
              height: AppColors.minTouchTargetSize,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  isSubmitting ? 'Posting Voucher...' : 'Confirm & Post Voucher',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: isSubmitting ? null : onConfirm,
              ),
            ),
            const SizedBox(height: 10),

            if (onEditFullVoucher != null)
              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onEditFullVoucher,
                  child: const Text('Edit Full Voucher', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
