import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';

/// Modal bottom sheet for interactive adjustment of invoice total amount and tax re-calculation.
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Edit Invoice Amount / राशि बदलें', style: AppTypography.cardHeader),
              IconButton(
                icon: const Icon(Icons.close),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Taxable Value (कर योग्य मूल्य):', style: TextStyle(fontSize: 12)),
                    Text(CurrencyFormatter.formatInr(_taxable), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated GST (18%):', style: TextStyle(fontSize: 12)),
                    Text(CurrencyFormatter.formatInr(_tax), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Net Amount:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(CurrencyFormatter.formatInr(_total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
              child: const Text('Update Amount / राशि लागू करें', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
