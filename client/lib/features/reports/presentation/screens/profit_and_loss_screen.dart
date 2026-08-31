import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/reports/data/repositories/reports_repository.dart';
import 'package:ledgify/features/reports/domain/models/profit_and_loss_model.dart';

/// Screen presenting the Trading and Profit & Loss Statement (Google Stitch UI).
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Profit & Loss Account', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh P&L',
            onPressed: _loadPnL,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _pnl == null
                ? const Center(child: Text('No financial data found for this period.', style: TextStyle(color: AppColors.textSecondary)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppColors.standardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Net Profit Summary Card
                        Card(
                          elevation: 0,
                          color: _pnl!.isProfit ? AppColors.debitGreenLight : AppColors.creditRedLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                            side: BorderSide(
                              color: _pnl!.isProfit ? AppColors.debitGreen.withOpacity(0.3) : AppColors.creditRed.withOpacity(0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pnl!.isProfit ? 'Net Profit (Earnings)' : 'Net Loss',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _pnl!.isProfit ? AppColors.debitGreen : AppColors.creditRed,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Gross Profit: ₹${_pnl!.grossProfit.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹${_pnl!.netProfit.abs().toStringAsFixed(2)}',
                                  style: AppTypography.currencyText.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _pnl!.isProfit ? AppColors.debitGreen : AppColors.creditRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Trading Account Section
                        Text('Trading Account (Gross Turnover)', style: AppTypography.cardHeader),
                        const SizedBox(height: 10),

                        _buildStatementCard([
                          _buildStatementRow('Direct Incomes (Sales / Revenue)', _pnl!.directIncomes, isIncome: true),
                          const Divider(height: 16),
                          _buildStatementRow('Direct Expenses (Purchases & COGS)', _pnl!.directExpenses, isIncome: false),
                          const Divider(height: 16),
                          _buildSubTotalRow('Gross Profit', _pnl!.grossProfit),
                        ]),
                        const SizedBox(height: 20),

                        // Income Statement Section
                        Text('Operating & Overhead Expenses', style: AppTypography.cardHeader),
                        const SizedBox(height: 10),

                        _buildStatementCard([
                          _buildStatementRow('Indirect Incomes', _pnl!.indirectIncomes, isIncome: true),
                          const Divider(height: 16),
                          _buildStatementRow('Indirect Expenses & Overheads', _pnl!.indirectExpenses, isIncome: false),
                          const Divider(height: 16),
                          _buildSubTotalRow('Net Profit / Net Margin', _pnl!.netProfit, isFinal: true),
                        ]),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatementCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildStatementRow(String title, double amount, {required bool isIncome}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: AppTypography.currencyText.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isIncome ? AppColors.debitGreen : AppColors.creditRed,
          ),
        ),
      ],
    );
  }

  Widget _buildSubTotalRow(String title, double amount, {bool isFinal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: isFinal ? 14.5 : 13, color: AppColors.textPrimary),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: AppTypography.currencyText.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: isFinal ? 16.5 : 14,
            color: amount >= 0 ? AppColors.debitGreen : AppColors.creditRed,
          ),
        ),
      ],
    );
  }
}
