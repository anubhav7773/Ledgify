import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Material 3 Expressive KPI summary metric card with trend chip (Google Stitch UI).
class KpiMetricCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final String? changePercent;
  final bool isPositive;
  final IconData icon;
  final Color? color;

  const KpiMetricCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.changePercent,
    this.isPositive = true,
    required this.icon,
    this.color,
    String? bilingualSubtitle, // For backwards compatibility
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surfaceCard,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: themeColor),
                ),
                if (changePercent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPositive ? AppColors.debitGreenLight : AppColors.creditRedLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      changePercent!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? AppColors.debitGreen : AppColors.creditRed,
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
                  style: AppTypography.currencyText.copyWith(
                    fontSize: 18,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
