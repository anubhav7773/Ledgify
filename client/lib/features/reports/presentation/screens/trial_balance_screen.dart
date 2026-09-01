import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/reports/data/repositories/reports_repository.dart';
import 'package:ledgify/features/reports/domain/models/trial_balance_model.dart';

/// Screen presenting the multi-column Trial Balance report (Google Stitch UI).
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Trial Balance Report', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Report',
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
              color: AppColors.surfaceCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Period: ${_fromDate.day.toString().padLeft(2, '0')}/${_fromDate.month.toString().padLeft(2, '0')}/${_fromDate.year} to ${_toDate.day.toString().padLeft(2, '0')}/${_toDate.month.toString().padLeft(2, '0')}/${_toDate.year}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.date_range_outlined, size: 16),
                    label: const Text('Change Date', style: TextStyle(fontWeight: FontWeight.w700)),
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
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_report == null)
              const Expanded(child: Center(child: Text('No data found.', style: TextStyle(color: AppColors.textSecondary))))
            else ...[
              // Balance Verification Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _report!.isBalanced ? AppColors.debitGreenLight : AppColors.creditRedLight,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _report!.isBalanced ? '✓ Trial Balance Balanced' : '⚠ Discrepancy Detected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: _report!.isBalanced ? AppColors.debitGreen : AppColors.creditRed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Dr: ₹${_report!.totalClosingDr.toStringAsFixed(2)} | Cr: ₹${_report!.totalClosingCr.toStringAsFixed(2)}',
                        style: AppTypography.currencyText.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

              // Table Headers
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.surfaceVariant.withOpacity(0.6),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Particulars', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.textPrimary))),
                    Expanded(flex: 2, child: Text('Opening', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.textPrimary))),
                    Expanded(flex: 2, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.textPrimary))),
                    Expanded(flex: 2, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.textPrimary))),
                    Expanded(flex: 2, child: Text('Closing', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.textPrimary))),
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
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.accountName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                Text(item.groupName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.openingDr > 0 ? '${item.openingDr.toStringAsFixed(0)} Dr' : (item.openingCr > 0 ? '${item.openingCr.toStringAsFixed(0)} Cr' : '-'),
                              textAlign: TextAlign.right,
                              style: AppTypography.currencyText.copyWith(fontSize: 11.5),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.periodDr > 0 ? item.periodDr.toStringAsFixed(0) : '-',
                              textAlign: TextAlign.right,
                              style: AppTypography.currencyText.copyWith(fontSize: 11.5, color: AppColors.debitGreen),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.periodCr > 0 ? item.periodCr.toStringAsFixed(0) : '-',
                              textAlign: TextAlign.right,
                              style: AppTypography.currencyText.copyWith(fontSize: 11.5, color: AppColors.creditRed),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              closingAmount > 0 ? '${closingAmount.toStringAsFixed(0)} $closingType' : '-',
                              textAlign: TextAlign.right,
                              style: AppTypography.currencyText.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
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
