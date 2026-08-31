import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Modal bottom sheet for switching the inferred accounting voucher type.
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => EditVoucherTypeBottomSheet(currentType: currentType),
    );
  }

  static const List<Map<String, dynamic>> _types = [
    {'name': 'Purchase', 'hindi': 'खरीद', 'icon': Icons.shopping_cart_outlined},
    {'name': 'Sales', 'hindi': 'बिक्री', 'icon': Icons.point_of_sale_outlined},
    {'name': 'Payment', 'hindi': 'भुगतान', 'icon': Icons.arrow_outward},
    {'name': 'Receipt', 'hindi': 'रसीद', 'icon': Icons.call_received},
    {'name': 'Contra', 'hindi': 'कॉन्ट्रा', 'icon': Icons.swap_horiz},
    {'name': 'Journal', 'hindi': 'जर्नल', 'icon': Icons.book_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Voucher Type / प्रकार चुनें', style: AppTypography.cardHeader),
              IconButton(
                icon: const Icon(Icons.close),
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
              childAspectRatio: 1.1,
            ),
            itemCount: _types.length,
            itemBuilder: (context, index) {
              final type = _types[index];
              final isSelected = type['name'].toString().toLowerCase() == currentType.toLowerCase();

              return InkWell(
                onTap: () => Navigator.pop(context, type['name'] as String),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryLight : AppColors.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(type['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textPrimary, size: 24),
                      const SizedBox(height: 6),
                      Text(type['name'] as String, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                      Text(type['hindi'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
