import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../domain/models/gst_split_result.dart';

/// Interactive UI widget rendering a complete statutory GST Tax breakdown card.
/// Visually highlights Intra-State vs Inter-State supply categorization.
class GstTaxSummaryCard extends StatelessWidget {
  final double taxableValue;
  final GstSplitResult taxSplit;
  final double roundOffAmount;

  const GstTaxSummaryCard({
    super.key,
    required this.taxableValue,
    required this.taxSplit,
    this.roundOffAmount = 0.00,
  });

  @override
  Widget build(BuildContext context) {
    final bool isInterState = taxSplit.isInterState;
    final double finalInvoiceTotal = taxSplit.totalAmount + roundOffAmount;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
        side: const BorderSide(color: LedgifyColors.surfaceVariant),
      ),
      color: LedgifyColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(LedgifyColors.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: GST Category Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tax Summary / कर सारांश',
                  style: LedgifyTypography.cardHeader,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isInterState
                        ? LedgifyColors.secondaryContainer
                        : LedgifyColors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isInterState ? 'Inter-State (IGST)' : 'Intra-State (CGST + SGST)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isInterState ? LedgifyColors.secondarySlate : LedgifyColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Assessable / Taxable Value
            _buildRow(
              labelEn: 'Taxable Amount',
              labelHi: 'कर योग्य राशि',
              value: '₹${taxableValue.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),

            // Intra-State: CGST & SGST Split
            if (!isInterState) ...[
              _buildRow(
                labelEn: 'CGST',
                labelHi: 'केंद्रीय कर',
                value: taxSplit.formattedCgst,
                valueColor: LedgifyColors.secondarySlate,
              ),
              const SizedBox(height: 8),
              _buildRow(
                labelEn: 'SGST / UTGST',
                labelHi: 'राज्य कर',
                value: taxSplit.formattedSgst,
                valueColor: LedgifyColors.secondarySlate,
              ),
            ] else ...[
              // Inter-State: IGST
              _buildRow(
                labelEn: 'Integrated Tax (IGST)',
                labelHi: 'एकीकृत कर',
                value: taxSplit.formattedIgst,
                valueColor: LedgifyColors.primaryBlue,
              ),
            ],

            if (taxSplit.cess > 0) ...[
              const SizedBox(height: 8),
              _buildRow(
                labelEn: 'Compensation Cess',
                labelHi: 'उपकर',
                value: '₹${taxSplit.cess.toStringAsFixed(2)}',
              ),
            ],

            if (roundOffAmount.abs() > 0.001) ...[
              const SizedBox(height: 8),
              _buildRow(
                labelEn: 'Round-Off Adjustment',
                labelHi: 'राउंड-ऑफ',
                value: '${roundOffAmount > 0 ? "+" : ""}₹${roundOffAmount.toStringAsFixed(2)}',
                valueColor: LedgifyColors.secondarySlate,
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Total Invoice Value
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('कुल चालान राशि', style: TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                  ],
                ),
                Text(
                  '₹${finalInvoiceTotal.toStringAsFixed(2)}',
                  style: LedgifyTypography.displayTitle.copyWith(
                    color: LedgifyColors.debitGreen,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required String labelEn,
    required String labelHi,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$labelEn / $labelHi', style: LedgifyTypography.bilingualLabel),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
