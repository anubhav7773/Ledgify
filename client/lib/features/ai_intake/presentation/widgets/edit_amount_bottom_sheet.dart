import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';

/// Modal bottom sheet for interactive adjustment of invoice total amount and tax re-calculation (Google Stitch UI).
class EditAmountBottomSheet extends StatefulWidget {
  final double initialAmount;
  final double initialTaxable;
  final double initialTax;

  const EditAmountBottomSheet({
    super.key,
    required this.initialAmount,
    required this.initialTaxable,
    required this.initialTax,
  });

  static Future<Map<String, double>?> show(
    BuildContext context, {
    required double initialAmount,
    required double initialTaxable,
    required double initialTax,
  }) {
    return showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => EditAmountBottomSheet(
        initialAmount: initialAmount,
        initialTaxable: initialTaxable,
        initialTax: initialTax,
      ),
    );
  }

  @override
  State<EditAmountBottomSheet> createState() => _EditAmountBottomSheetState();
}

class _EditAmountBottomSheetState extends State<EditAmountBottomSheet> {
  late final TextEditingController _amountController;
  late double _taxable;
  late double _tax;
  late double _total;

  @override
  void initState() {
    super.initState();
    _total = widget.initialAmount;
    _taxable = widget.initialTaxable;
    _tax = widget.initialTax;
    _amountController = TextEditingController(text: _total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val.replaceAll(',', '').trim()) ?? 0.0;
    setState(() {
      _total = parsed;
      // Default standard 18% GST auto-split approximation
      _taxable = double.parse((_total / 1.18).toStringAsFixed(2));
      _tax = double.parse((_total - _taxable).toStringAsFixed(2));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 12,
          left: 20,
          right: 20,
        ),
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
                Text('Edit Invoice Amount', style: AppTypography.cardHeader),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input Field
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.currencyText.copyWith(fontSize: 22, color: AppColors.primary),
              decoration: const InputDecoration(
                labelText: 'Total Grand Amount (₹) *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              onChanged: _onAmountChanged,
            ),
            const SizedBox(height: 16),

            // Real-time Tax Split Breakdown Preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Taxable Value:', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.formatInr(_taxable), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated GST (18%):', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.formatInr(_tax), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Net Amount:', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text(CurrencyFormatter.formatInr(_total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Confirm Button (48dp Touch Target)
            SizedBox(
              height: AppColors.minTouchTargetSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    'total': _total,
                    'taxable': _taxable,
                    'tax': _tax,
                  });
                },
                child: const Text('Update Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
