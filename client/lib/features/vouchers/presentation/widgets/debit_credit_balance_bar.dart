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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isBalanced ? LedgifyColors.debitGreenBg : LedgifyColors.creditRedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBalanced ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Total Debits
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total Debit (Dr)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LedgifyColors.secondarySlate),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹${totalDebit.toStringAsFixed(2)}',
                    style: LedgifyTypography.financialAmount.copyWith(
                      color: LedgifyColors.debitGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Balance Indicator Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isBalanced ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  isBalanced ? 'Balanced' : 'Diff: ₹${difference.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Total Credits
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total Credit (Cr)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LedgifyColors.secondarySlate),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₹${totalCredit.toStringAsFixed(2)}',
                    style: LedgifyTypography.financialAmount.copyWith(
                      color: LedgifyColors.creditRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
