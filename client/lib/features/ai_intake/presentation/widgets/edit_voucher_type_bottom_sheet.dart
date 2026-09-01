import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Modal bottom sheet for switching the inferred accounting voucher type (Google Stitch UI).
class EditVoucherTypeBottomSheet extends StatelessWidget {
  final String currentType;

  const EditVoucherTypeBottomSheet({
    super.key,
    required this.currentType,
  });

  static Future<String?> show(
    BuildContext context, {
    required String currentType,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => EditVoucherTypeBottomSheet(currentType: currentType),
    );
  }

  static const List<Map<String, dynamic>> _types = [
    {'name': 'Purchase', 'icon': Icons.shopping_cart_outlined},
    {'name': 'Sales', 'icon': Icons.point_of_sale_outlined},
    {'name': 'Payment', 'icon': Icons.arrow_outward_rounded},
    {'name': 'Receipt', 'icon': Icons.call_received_rounded},
    {'name': 'Contra', 'icon': Icons.swap_horiz_rounded},
    {'name': 'Journal', 'icon': Icons.book_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Voucher Type', style: AppTypography.cardHeader),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: _types.length,
              itemBuilder: (context, index) {
                final type = _types[index];
                final isSelected = type['name'].toString().toLowerCase() == currentType.toLowerCase();

                return InkWell(
                  onTap: () => Navigator.pop(context, type['name'] as String),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryLight : AppColors.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.5),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textPrimary, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          type['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
