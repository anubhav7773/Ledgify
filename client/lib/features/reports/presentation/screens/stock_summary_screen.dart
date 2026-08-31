import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../domain/models/stock_summary_model.dart';
import '../domain/services/statutory_registers_service.dart';

/// Screen presenting the Inventory Valuation and Stock Summary report.
class StockSummaryScreen extends StatefulWidget {
  final StatutoryRegistersService? service;

  const StockSummaryScreen({super.key, this.service});

  @override
  State<StockSummaryScreen> createState() => _StockSummaryScreenState();
}

class _StockSummaryScreenState extends State<StockSummaryScreen> {
  late final StatutoryRegistersService _service;
  bool _isLoading = true;
  StockSummaryReportModel? _report;
  DateTime _asOfDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StatutoryRegistersService();
    _loadStockSummary();
  }

  Future<void> _loadStockSummary() async {
    setState(() => _isLoading = true);
    try {
      final report = await _service.fetchStockSummary(asOfDate: _asOfDate);
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Summary / स्टॉक सारांश', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStockSummary,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Selector Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: LedgifyColors.surfaceCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'As on: ${_asOfDate.day}/${_asOfDate.month}/${_asOfDate.year}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change Date'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _asOfDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _asOfDate = picked);
                        _loadStockSummary();
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue)))
            else if (_report == null || _report!.totalItems == 0)
              const Expanded(child: Center(child: Text('No stock items found.')))
            else ...[
              // Total Inventory Value Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: LedgifyColors.primaryContainer.withOpacity(0.4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Stock Items: ${_report!.totalItems}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      'Valuation: ₹${_report!.totalInventoryValue.toStringAsFixed(2)}',
                      style: LedgifyTypography.financialAmount.copyWith(fontSize: 15, color: LedgifyColors.primaryBlue),
                    ),
                  ],
                ),
              ),

              // Stock Items List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _report!.items.length,
                  itemBuilder: (context, index) {
                    final item = _report!.items[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: LedgifyColors.surfaceVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(item.stockItemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ),
                                Text(
                                  '₹${item.closingVal.toStringAsFixed(2)}',
                                  style: LedgifyTypography.financialAmount.copyWith(fontSize: 15, color: LedgifyColors.primaryBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Text(
                              'Group: ${item.groupName ?? "Primary"} • HSN: ${item.hsnOrSacCode ?? "N/A"}',
                              style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate),
                            ),
                            const Divider(height: 14),

                            // Quantity & Rate Split Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Closing Qty: ${item.closingQty.toStringAsFixed(2)} ${item.uomSymbol}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('@ ₹${item.closingRate.toStringAsFixed(2)} / ${item.uomSymbol}', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
