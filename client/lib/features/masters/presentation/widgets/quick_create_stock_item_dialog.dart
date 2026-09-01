import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../models/stock_item_model.dart';
import '../services/inventory_matching_service.dart';

/// Modal dialog for rapid on-the-fly stock item creation during OCR bill ingestion.
class QuickCreateStockItemDialog extends StatefulWidget {
  final String initialName;
  final String? initialHsn;
  final double initialGstRate;
  final String initialUqc;
  final String? businessId;
  final InventoryMatchingService? service;

  const QuickCreateStockItemDialog({
    super.key,
    required this.initialName,
    this.initialHsn,
    this.initialGstRate = 18.00,
    this.initialUqc = 'NOS',
    this.businessId,
    this.service,
  });

  static Future<StockItemModel?> show(
    BuildContext context, {
    required String initialName,
    String? initialHsn,
    double initialGstRate = 18.00,
    String initialUqc = 'NOS',
    String? businessId,
    InventoryMatchingService? service,
  }) {
    return showDialog<StockItemModel>(
      context: context,
      builder: (ctx) => QuickCreateStockItemDialog(
        initialName: initialName,
        initialHsn: initialHsn,
        initialGstRate: initialGstRate,
        initialUqc: initialUqc,
        businessId: businessId,
        service: service,
      ),
    );
  }

  @override
  State<QuickCreateStockItemDialog> createState() => _QuickCreateStockItemDialogState();
}

class _QuickCreateStockItemDialogState extends State<QuickCreateStockItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final InventoryMatchingService _service;

  late final TextEditingController _nameController;
  late final TextEditingController _hsnController;
  late double _selectedGstRate;
  late String _selectedUqc;
  bool _isCreating = false;

  final List<double> _gstSlabs = [0.0, 0.1, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0];
  final List<String> _uqcList = ['NOS', 'KGS', 'BOX', 'PCS', 'MTR', 'LTR', 'SET', 'BAG'];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? InventoryMatchingService();
    _nameController = TextEditingController(text: widget.initialName);
    _hsnController = TextEditingController(text: widget.initialHsn ?? '998311');
    _selectedGstRate = _gstSlabs.contains(widget.initialGstRate) ? widget.initialGstRate : 18.0;
    _selectedUqc = _uqcList.contains(widget.initialUqc.toUpperCase()) ? widget.initialUqc.toUpperCase() : 'NOS';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hsnController.dispose();
    super.dispose();
  }

  Future<void> _createStockItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final created = await _service.quickCreateItem(
        name: _nameController.text.trim(),
        hsnCode: _hsnController.text.trim(),
        gstRate: _selectedGstRate,
        uqc: _selectedUqc,
      );

      if (mounted) {
        Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create item: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Quick Create Stock Item / नया स्टॉक बनाएं', style: LedgifyTypography.cardHeader),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _hsnController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'HSN / SAC Code *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().length < 4 ? 'Min 4 digits' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      value: _selectedGstRate,
                      decoration: const InputDecoration(labelText: 'GST Slab', border: OutlineInputBorder()),
                      items: _gstSlabs.map((rate) {
                        return DropdownMenuItem(value: rate, child: Text('$rate%'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGstRate = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUqc,
                      decoration: const InputDecoration(labelText: 'Unit (UQC)', border: OutlineInputBorder()),
                      items: _uqcList.map((unit) {
                        return DropdownMenuItem(value: unit, child: Text(unit));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUqc = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LedgifyColors.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, LedgifyColors.minTouchTargetSize),
          ),
          onPressed: _isCreating ? null : _createStockItem,
          child: Text(_isCreating ? 'Saving...' : 'Create & Use / बनाएं'),
        ),
      ],
    );
  }
}
