import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'package:ledgify/features/reports/data/repositories/reports_repository.dart';
import 'package:ledgify/features/reports/domain/models/trial_balance_model.dart';

/// Screen presenting the multi-column Trial Balance report.
class TrialBalanceScreen extends StatefulWidget {
  final ReportsRepository? repository;

  const TrialBalanceScreen({super.key, this.repository});

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  late final ReportsRepository _repository;
  bool _isLoading = true;
  TrialBalanceReportModel? _report;

  DateTime _fromDate = DateTime(DateTime.now().year, 4, 1);
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ReportsRepository();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await _repository.getTrialBalance(fromDate: _fromDate, toDate: _toDate);
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
        title: const Text('Trial Balance / तलपट', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Range Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: LedgifyColors.surfaceCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Period: ${_fromDate.day}/${_fromDate.month}/${_fromDate.year} to ${_toDate.day}/${_toDate.month}/${_toDate.year}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.date_range, size: 16),
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
                        _loadReport();
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue)))
            else if (_report == null)
              const Expanded(child: Center(child: Text('No data found.')))
            else ...[
              // Balance Verification Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _report!.isBalanced ? LedgifyColors.debitGreenBg : LedgifyColors.creditRedBg,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _report!.isBalanced ? '✓ Trial Balance Balanced (₹${_report!.totalClosingDr.toStringAsFixed(2)})' : '⚠ Discrepancy Detected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _report!.isBalanced ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
                      ),
                    ),
                    Text(
                      'Dr: ₹${_report!.totalClosingDr.toStringAsFixed(2)} | Cr: ₹${_report!.totalClosingCr.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              // Table Headers
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: LedgifyColors.surfaceVariant.withOpacity(0.4),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Particulars / खाता', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Opening', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Closing', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                  ],
                ),
              ),

              // Ledger Rows
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _report!.lines.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _report!.lines[index];
                    final closingAmount = item.closingDr > 0 ? item.closingDr : item.closingCr;
                    final closingType = item.closingDr > 0 ? 'Dr' : (item.closingCr > 0 ? 'Cr' : '');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.accountName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text(item.groupName, style: const TextStyle(fontSize: 10, color: LedgifyColors.secondarySlate)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.openingDr > 0 ? '${item.openingDr.toStringAsFixed(0)} Dr' : (item.openingCr > 0 ? '${item.openingCr.toStringAsFixed(0)} Cr' : '-'),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.periodDr > 0 ? item.periodDr.toStringAsFixed(0) : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: LedgifyColors.debitGreen),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.periodCr > 0 ? item.periodCr.toStringAsFixed(0) : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: LedgifyColors.creditRed),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              closingAmount > 0 ? '${closingAmount.toStringAsFixed(0)} $closingType' : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
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
