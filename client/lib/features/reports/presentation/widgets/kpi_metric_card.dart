import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';

/// Material 3 Expressive KPI summary metric card with trend chip.
class KpiMetricCard extends StatelessWidget {
  final String title;
  final String bilingualSubtitle;
  final String value;
  final String? changePercent;
  final bool isPositive;
  final IconData icon;
  final Color? color;

  const KpiMetricCard({
    super.key,
    required this.title,
    required this.bilingualSubtitle,
    required this.value,
    this.changePercent,
    this.isPositive = true,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? LedgifyColors.primaryBlue;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
        side: const BorderSide(color: LedgifyColors.surfaceVariant),
      ),
      color: LedgifyColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: themeColor),
                ),
                if (changePercent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPositive ? LedgifyColors.debitGreenBg : LedgifyColors.creditRedBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      changePercent!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: LedgifyTypography.financialAmount.copyWith(
                    fontSize: 18,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                Text(
                  bilingualSubtitle,
                  style: const TextStyle(fontSize: 10.5, color: LedgifyColors.secondarySlate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
