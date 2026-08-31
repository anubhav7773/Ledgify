import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/reports/domain/models/stock_summary_model.dart';
import 'package:ledgify/features/reports/domain/services/statutory_registers_service.dart';

/// Screen presenting the Inventory Valuation and Stock Summary report (Google Stitch UI).
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Stock Summary', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Report',
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
              color: AppColors.surfaceCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'As on: ${_asOfDate.day.toString().padLeft(2, '0')}/${_asOfDate.month.toString().padLeft(2, '0')}/${_asOfDate.year}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: const Text('Change Date', style: TextStyle(fontWeight: FontWeight.w700)),
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
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_report == null || _report!.totalItems == 0)
              const Expanded(
                child: Center(
                  child: Text('No stock items found in inventory.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else ...[
              // Total Inventory Value Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Inventory Value',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_report!.totalItems} Stock Items',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      '₹${_report!.totalInventoryValue.toStringAsFixed(2)}',
                      style: AppTypography.currencyText.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Stock Items List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _report!.items.length,
                  itemBuilder: (context, index) {
                    final item = _report!.items[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                        side: const BorderSide(color: AppColors.border),
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
                                  child: Text(
                                    item.stockItemName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  '₹${item.closingVal.toStringAsFixed(2)}',
                                  style: AppTypography.currencyText.copyWith(fontSize: 15, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Text(
                              'Group: ${item.groupName ?? "Primary"} • HSN: ${item.hsnOrSacCode ?? "N/A"}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const Divider(height: 16),

                            // Quantity & Rate Split Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Closing Qty: ${item.closingQty.toStringAsFixed(2)} ${item.uomSymbol}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '@ ₹${item.closingRate.toStringAsFixed(2)} / ${item.uomSymbol}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
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
