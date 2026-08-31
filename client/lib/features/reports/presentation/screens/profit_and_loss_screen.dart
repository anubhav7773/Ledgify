import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'package:ledgify/features/reports/data/repositories/reports_repository.dart';
import 'package:ledgify/features/reports/domain/models/profit_and_loss_model.dart';

/// Screen presenting the Trading and Profit & Loss Statement.
class ProfitAndLossScreen extends StatefulWidget {
  final ReportsRepository? repository;

  const ProfitAndLossScreen({super.key, this.repository});

  @override
  State<ProfitAndLossScreen> createState() => _ProfitAndLossScreenState();
}

class _ProfitAndLossScreenState extends State<ProfitAndLossScreen> {
  late final ReportsRepository _repository;
  bool _isLoading = true;
  ProfitAndLossReportModel? _pnl;

  DateTime _fromDate = DateTime(DateTime.now().year, 4, 1);
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ReportsRepository();
    _loadPnL();
  }

  Future<void> _loadPnL() async {
    setState(() => _isLoading = true);
    try {
      final pnl = await _repository.getProfitAndLoss(fromDate: _fromDate, toDate: _toDate);
      if (mounted) {
        setState(() {
          _pnl = pnl;
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
        title: const Text('Profit & Loss A/c / लाभ-हानि', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPnL,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
            : _pnl == null
                ? const Center(child: Text('No data found.'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(LedgifyColors.standardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Net Profit Summary Card
                        Card(
                          elevation: 2,
                          color: _pnl!.isProfit ? LedgifyColors.debitGreenBg : LedgifyColors.creditRedBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pnl!.isProfit ? 'Net Profit / शुद्ध लाभ' : 'Net Loss / शुद्ध हानि',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _pnl!.isProfit ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
                                      ),
                                    ),
                                    Text('Gross Profit: ₹${_pnl!.grossProfit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                                  ],
                                ),
                                Text(
                                  '₹${_pnl!.netProfit.abs().toStringAsFixed(2)}',
                                  style: LedgifyTypography.financialAmount.copyWith(
                                    fontSize: 22,
                                    color: _pnl!.isProfit ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Trading Account Section
                        const Text('Trading Account (Gross Turnover) / व्यापार खाता', style: LedgifyTypography.cardHeader),
                        const SizedBox(height: 8),

                        _buildStatementTile('Direct Incomes (Sales)', _pnl!.directIncomes, isIncome: true),
                        _buildStatementTile('Direct Expenses (Purchases)', _pnl!.directExpenses, isIncome: false),
                        _buildSubTotalTile('Gross Profit / सकल लाभ', _pnl!.grossProfit),
                        const Divider(height: 24),

                        // Income Statement Section
                        const Text('Income Statement / आय विवरण', style: LedgifyTypography.cardHeader),
                        const SizedBox(height: 8),

                        _buildStatementTile('Indirect Incomes', _pnl!.indirectIncomes, isIncome: true),
                        _buildStatementTile('Indirect Expenses & Overheads', _pnl!.indirectExpenses, isIncome: false),
                        _buildSubTotalTile('Net Profit / शुद्ध लाभ', _pnl!.netProfit, isFinal: true),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatementTile(String title, double amount, {required bool isIncome}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isIncome ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTotalTile(String title, double amount, {bool isFinal = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LedgifyColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LedgifyColors.surfaceVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isFinal ? 14 : 12)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: isFinal ? 16 : 13,
              color: amount >= 0 ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
            ),
          ),
        ],
      ),
    );
  }
}
