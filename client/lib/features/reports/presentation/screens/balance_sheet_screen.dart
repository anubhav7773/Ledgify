import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/reports/data/repositories/reports_repository.dart';
import 'package:ledgify/features/reports/domain/models/balance_sheet_model.dart';

/// Screen presenting Schedule III compliant Balance Sheet statement (Google Stitch UI).
class BalanceSheetScreen extends StatefulWidget {
  final ReportsRepository? repository;

  const BalanceSheetScreen({super.key, this.repository});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  late final ReportsRepository _repository;
  bool _isLoading = true;
  BalanceSheetReportModel? _report;

  DateTime _asOfDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ReportsRepository();
    _loadBalanceSheet();
  }

  Future<void> _loadBalanceSheet() async {
    setState(() => _isLoading = true);
    try {
      final report = await _repository.getBalanceSheet(asOfDate: _asOfDate);
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
        title: Text('Balance Sheet Report', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Balance Sheet',
            onPressed: _loadBalanceSheet,
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
                        _loadBalanceSheet();
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
              const Expanded(child: Center(child: Text('No balance sheet data found.', style: TextStyle(color: AppColors.textSecondary))))
            else ...[
              // Balance Equality Verification Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _report!.isBalanced ? AppColors.debitGreenLight : AppColors.creditRedLight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _report!.isBalanced ? '✓ Balance Sheet Balanced (₹${_report!.totalAssets.toStringAsFixed(2)})' : '⚠ Imbalance Difference: ₹${_report!.difference.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: _report!.isBalanced ? AppColors.debitGreen : AppColors.creditRed,
                      ),
                    ),
                    Text(
                      'Total: ₹${_report!.totalAssets.toStringAsFixed(0)}',
                      style: AppTypography.currencyText.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              // Liabilities & Assets Sections
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppColors.standardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sources of Funds (Liabilities & Equity)
                      Text('I. Liabilities & Equity (Sources of Funds)', style: AppTypography.cardHeader),
                      const SizedBox(height: 10),

                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildLineItem('Capital Account', _report!.capitalEquity),
                              const Divider(height: 16),
                              _buildLineItem('Current Net Profit (Reserves)', _report!.currentNetProfit),
                              const Divider(height: 16),
                              _buildSubHeader('Total Equity & Reserves', _report!.totalEquityAndReserves),
                              const Divider(height: 16),
                              _buildLineItem('Loans & Borrowings (Liability)', _report!.loansLiability),
                              const Divider(height: 16),
                              _buildLineItem('Current Liabilities & Sundry Creditors', _report!.currentLiabilities),
                              const Divider(height: 18),
                              _buildTotalHeader('Total Liabilities & Equity', _report!.totalLiabilitiesAndEquity),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Application of Funds (Assets)
                      Text('II. Assets (Application of Funds)', style: AppTypography.cardHeader),
                      const SizedBox(height: 10),

                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildLineItem('Fixed Assets (Net Block & Plant)', _report!.fixedAssets),
                              const Divider(height: 16),
                              _buildLineItem('Current Assets (Bank, Cash, Sundry Debtors)', _report!.currentAssets),
                              const Divider(height: 18),
                              _buildTotalHeader('Total Assets', _report!.totalAssets),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineItem(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        Text('₹${amount.toStringAsFixed(2)}', style: AppTypography.currencyText.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSubHeader(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text('₹${amount.toStringAsFixed(2)}', style: AppTypography.currencyText.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildTotalHeader(String title, double amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: AppTypography.currencyText.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
