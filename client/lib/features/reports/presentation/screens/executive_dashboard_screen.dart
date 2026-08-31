import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/reports/domain/models/business_ratios_model.dart';
import 'package:ledgify/features/reports/domain/models/cash_flow_forecast_point.dart';
import 'package:ledgify/features/reports/domain/models/dashboard_summary_model.dart';
import 'package:ledgify/features/reports/domain/services/analytics_dashboard_service.dart';
import '../widgets/cash_flow_forecast_chart.dart';
import '../widgets/kpi_metric_card.dart';
import 'reports_hub_screen.dart';

/// Screen presenting the Executive KPI Dashboard, Financial Ratios, and Cash Runway Forecast (Google Stitch UI).
class ExecutiveDashboardScreen extends StatefulWidget {
  final AnalyticsDashboardService? service;

  const ExecutiveDashboardScreen({super.key, this.service});

  @override
  State<ExecutiveDashboardScreen> createState() => _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends State<ExecutiveDashboardScreen> {
  late final AnalyticsDashboardService _service;
  bool _isLoading = true;

  DashboardSummaryModel _summary = DashboardSummaryModel.empty();
  BusinessRatiosModel? _ratios;
  List<CashFlowForecastPoint> _forecast = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnalyticsDashboardService();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _service.fetchExecutiveSummary();
      final ratios = await _service.fetchBusinessRatios();
      final forecast = await _service.fetch30DayCashForecast();

      if (mounted) {
        setState(() {
          _summary = summary;
          _ratios = ratios;
          _forecast = forecast;
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
        title: Text('Executive Dashboard', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'All Financial Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsHubScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Dashboard',
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppColors.standardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Health Score Banner (Deep Indigo Gradient)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Business Health: ${_summary.healthScore}% Optimal',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Working capital and liquidity ratios are performing within optimal bands.',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4-Card Hero Metrics Grid
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.25,
                        children: [
                          KpiMetricCard(
                            title: 'Net Profit (YTD)',
                            value: '₹${_summary.netProfitYtd.toStringAsFixed(0)}',
                            changePercent: '+14.2%',
                            isPositive: true,
                            icon: Icons.trending_up_rounded,
                            color: AppColors.debitGreen,
                          ),
                          KpiMetricCard(
                            title: 'Operating Cash',
                            value: '₹${_summary.operatingCash.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: AppColors.primary,
                          ),
                          KpiMetricCard(
                            title: 'Overdue Receivables',
                            value: '₹${_summary.overdueReceivables.toStringAsFixed(0)}',
                            changePercent: '${_ratios?.debtorDaysDso.toStringAsFixed(0) ?? 42} Days DSO',
                            isPositive: false,
                            icon: Icons.call_received_rounded,
                            color: AppColors.warningAmber,
                          ),
                          KpiMetricCard(
                            title: 'Overdue Payables',
                            value: '₹${_summary.overduePayables.toStringAsFixed(0)}',
                            changePercent: '${_ratios?.creditorDaysDpo.toStringAsFixed(0) ?? 30} Days DPO',
                            isPositive: true,
                            icon: Icons.call_made_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 30-Day Cash Flow Forecast Chart
                      CashFlowForecastChart(forecastPoints: _forecast),
                      const SizedBox(height: 16),

                      // Financial Ratios Hub
                      if (_ratios != null) ...[
                        Text('Key Financial Ratios', style: AppTypography.cardHeader),
                        const SizedBox(height: 10),

                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          color: AppColors.surfaceCard,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildRatioRow(
                                  'Current Ratio',
                                  '${_ratios!.currentRatio.toStringAsFixed(2)} : 1',
                                  _ratios!.currentRatioStatus,
                                  _ratios!.currentRatioColor,
                                ),
                                const Divider(height: 20),
                                _buildRatioRow(
                                  'Quick Ratio',
                                  '${_ratios!.quickRatio.toStringAsFixed(2)} : 1',
                                  _ratios!.quickRatio >= 1.0 ? 'Optimal' : 'Low Buffer',
                                  _ratios!.quickRatio >= 1.0 ? AppColors.debitGreen : AppColors.warningAmber,
                                ),
                                const Divider(height: 20),
                                _buildRatioRow(
                                  'Gross Profit Margin',
                                  '${_ratios!.grossProfitMargin.toStringAsFixed(1)}%',
                                  'Direct Profitability',
                                  AppColors.primary,
                                ),
                                const Divider(height: 20),
                                _buildRatioRow(
                                  'Debt-to-Equity Ratio',
                                  '${_ratios!.debtToEquity.toStringAsFixed(2)}',
                                  _ratios!.debtToEquity <= 1.5 ? 'Conservative' : 'Leveraged',
                                  _ratios!.debtToEquity <= 1.5 ? AppColors.debitGreen : AppColors.creditRed,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRatioRow(String title, String ratioVal, String statusText, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary)),
            Text(statusText, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        Text(
          ratioVal,
          style: AppTypography.currencyText.copyWith(fontSize: 16, color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
