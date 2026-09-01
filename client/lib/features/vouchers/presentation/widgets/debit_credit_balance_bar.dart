import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';

/// Live balancing indicator bar for double-entry voucher entry screens.
/// Visually asserts the mathematical invariant: \sum Debits == \sum Credits.
class DebitCreditBalanceBar extends StatelessWidget {
  final double totalDebit;
  final double totalCredit;

  const DebitCreditBalanceBar({
    super.key,
    required this.totalDebit,
    required this.totalCredit,
  });

  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.001 && totalDebit > 0;
  double get difference => (totalDebit - totalCredit).abs();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isBalanced ? LedgifyColors.debitGreenBg : LedgifyColors.creditRedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBalanced ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Debits
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Debit (Dr)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: LedgifyColors.secondarySlate),
              ),
              Text(
                '₹${totalDebit.toStringAsFixed(2)}',
                style: LedgifyTypography.financialAmount.copyWith(
                  color: LedgifyColors.debitGreen,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          // Balance Indicator Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isBalanced ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  isBalanced ? 'Balanced' : 'Diff: ₹${difference.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Total Credits
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Total Credit (Cr)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: LedgifyColors.secondarySlate),
              ),
              Text(
                '₹${totalCredit.toStringAsFixed(2)}',
                style: LedgifyTypography.financialAmount.copyWith(
                  color: LedgifyColors.creditRed,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
