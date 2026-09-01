import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// Financial amount card with semantic Dr/Cr color coding.
class FinancialCard extends StatelessWidget {
  final String title;
  final String bilingualSubtitle;
  final double amount;
  final String? entryType; // 'Dr' or 'Cr'
  final VoidCallback? onTap;

  const FinancialCard({
    super.key,
    required this.title,
    required this.bilingualSubtitle,
    required this.amount,
    this.entryType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color amountColor = AppColors.primary;
    if (entryType != null) {
      amountColor = entryType == 'Dr' ? AppColors.debitGreen : AppColors.creditRed;
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
              if (bilingualSubtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  bilingualSubtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.formatInr(amount),
                        style: AppTypography.currencyText.copyWith(
                          fontSize: 18,
                          color: amountColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (entryType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: entryType == 'Dr' ? AppColors.debitGreenLight : AppColors.creditRedLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entryType!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: amountColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
