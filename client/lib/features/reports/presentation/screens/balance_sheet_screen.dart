import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'package:ledgify/features/reports/data/repositories/reports_repository.dart';
import 'package:ledgify/features/reports/domain/models/balance_sheet_model.dart';

/// Screen presenting Schedule III compliant Balance Sheet statement.
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
      appBar: AppBar(
        title: const Text('Balance Sheet / तुलन पत्र', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                        _loadBalanceSheet();
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
              // Balance Equality Verification Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _report!.isBalanced ? LedgifyColors.debitGreenBg : LedgifyColors.creditRedBg,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _report!.isBalanced ? '✓ Balance Sheet Balanced (₹${_report!.totalAssets.toStringAsFixed(2)})' : '⚠ Imbalance Difference: ₹${_report!.difference.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _report!.isBalanced ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
                      ),
                    ),
                    Text(
                      'Total: ₹${_report!.totalAssets.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              // Liabilities & Assets Sections
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(LedgifyColors.standardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sources of Funds (Liabilities & Equity)
                      const Text('I. Liabilities & Equity / देनदारियां और पूंजी', style: LedgifyTypography.cardHeader),
                      const SizedBox(height: 8),

                      _buildLineItem('Capital Account', _report!.capitalEquity),
                      _buildLineItem('Current Net Profit', _report!.currentNetProfit),
                      _buildSubHeader('Total Equity & Reserves', _report!.totalEquityAndReserves),

                      _buildLineItem('Loans (Liability)', _report!.loansLiability),
                      _buildLineItem('Current Liabilities & Creditors', _report!.currentLiabilities),
                      _buildTotalHeader('Total Liabilities & Equity', _report!.totalLiabilitiesAndEquity),
                      const Divider(height: 28),

                      // Application of Funds (Assets)
                      const Text('II. Assets / परिसंपत्तियां (संपत्ति)', style: LedgifyTypography.cardHeader),
                      const SizedBox(height: 8),

                      _buildLineItem('Fixed Assets (Net Block)', _report!.fixedAssets),
                      _buildLineItem('Current Assets (Bank, Cash, Debtors)', _report!.currentAssets),
                      _buildTotalHeader('Total Assets / कुल संपत्ति', _report!.totalAssets),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String title, double amount) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LedgifyColors.surfaceCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTotalHeader(String title, double amount) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LedgifyColors.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LedgifyColors.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: LedgifyTypography.financialAmount.copyWith(fontSize: 16, color: LedgifyColors.primaryBlue),
          ),
        ],
      ),
    );
  }
}
