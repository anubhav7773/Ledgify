import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'package:ledgify/features/reports/domain/models/trade_register_model.dart';
import 'package:ledgify/features/reports/domain/services/statutory_registers_service.dart';

/// Screen presenting statutory Sales Register and Purchase Register.
class TradeRegisterScreen extends StatefulWidget {
  final StatutoryRegistersService? service;
  final String initialType; // 'SALES' or 'PURCHASE'

  const TradeRegisterScreen({
    super.key,
    this.service,
    this.initialType = 'SALES',
  });

  @override
  State<TradeRegisterScreen> createState() => _TradeRegisterScreenState();
}

class _TradeRegisterScreenState extends State<TradeRegisterScreen> {
  late final StatutoryRegistersService _service;
  late String _registerType;
  bool _isLoading = true;
  TradeRegisterReportModel? _report;

  DateTime _fromDate = DateTime(DateTime.now().year, 4, 1);
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StatutoryRegistersService();
    _registerType = widget.initialType;
    _loadRegister();
  }

  Future<void> _loadRegister() async {
    setState(() => _isLoading = true);
    try {
      final report = _registerType == 'SALES'
          ? await _service.fetchSalesRegister(fromDate: _fromDate, toDate: _toDate)
          : await _service.fetchPurchaseRegister(fromDate: _fromDate, toDate: _toDate);

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
    final isSales = _registerType == 'SALES';

    return Scaffold(
      appBar: AppBar(
        title: Text(isSales ? 'Sales Register' : 'Purchase Register', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export Register',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting Trade Register to Excel...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegister,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Register Toggle Segment
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'SALES', label: Text('Sales Register')),
                  ButtonSegment(value: 'PURCHASE', label: Text('Purchase Register')),
                ],
                selected: {_registerType},
                onSelectionChanged: (val) {
                  setState(() => _registerType = val.first);
                  _loadRegister();
                },
              ),
            ),

            // Date Range Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: LedgifyColors.surfaceCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Period: ${_fromDate.day}/${_fromDate.month} - ${_toDate.day}/${_toDate.month}/${_toDate.year}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change Date'),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                      );
                      if (picked != null) {
                        setState(() {
                          _fromDate = picked.start;
                          _toDate = picked.end;
                        });
                        _loadRegister();
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue)))
            else if (_report == null || _report!.totalCount == 0)
              const Expanded(
                child: Center(
                  child: Text('No register transactions recorded for this period.', style: LedgifyTypography.bilingualLabel),
                ),
              )
            else ...[
              // Turnover Subtotals Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: LedgifyColors.primaryContainer.withOpacity(0.4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Invoices: ${_report!.totalCount}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      'Taxable: ₹${_report!.totalTaxableValue.toStringAsFixed(0)} | Total: ₹${_report!.totalNetAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue),
                    ),
                  ],
                ),
              ),

              // Entries List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _report!.entries.length,
                  itemBuilder: (context, index) {
                    final item = _report!.entries[index];

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
                                Text('${item.voucherDate.day}/${item.voucherDate.month}/${item.voucherDate.year}', style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
                                Text('Inv: ${item.voucherNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(item.partyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                                Text(
                                  '₹${item.netTotal.toStringAsFixed(2)}',
                                  style: LedgifyTypography.financialAmount.copyWith(
                                    fontSize: 16,
                                    color: isSales ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
                                  ),
                                ),
                              ],
                            ),

                            if (item.partyGstin != null) ...[
                              const SizedBox(height: 2),
                              Text('GSTIN: ${item.partyGstin}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: LedgifyColors.secondarySlate)),
                            ],
                            const Divider(height: 14),

                            // Tax Breakdown Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Taxable: ₹${item.taxableValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                                Text('GST Total: ₹${item.totalTax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LedgifyColors.primaryBlue)),
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
