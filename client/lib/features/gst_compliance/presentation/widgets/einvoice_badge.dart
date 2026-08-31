import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';

/// Visual badge showing statutory E-Invoice generation status.
class EInvoiceBadge extends StatelessWidget {
  final String? irn;
  final bool isCancelled;

  const EInvoiceBadge({
    super.key,
    this.irn,
    this.isCancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: LedgifyColors.creditRedBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: LedgifyColors.creditRed, width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 12, color: LedgifyColors.creditRed),
            SizedBox(width: 4),
            Text(
              'IRN Cancelled',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LedgifyColors.creditRed),
            ),
          ],
        ),
      );
    }

    if (irn != null && irn!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: LedgifyColors.debitGreenBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: LedgifyColors.debitGreen, width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, size: 12, color: LedgifyColors.debitGreen),
            SizedBox(width: 4),
            Text(
              'IRN Active',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LedgifyColors.debitGreen),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LedgifyColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'E-Invoice Pending',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LedgifyColors.secondarySlate),
      ),
    );
  }
}
