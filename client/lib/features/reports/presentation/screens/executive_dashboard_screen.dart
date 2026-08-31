import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'package:ledgify/features/reports/domain/models/business_ratios_model.dart';
import 'package:ledgify/features/reports/domain/models/cash_flow_forecast_point.dart';
import 'package:ledgify/features/reports/domain/models/dashboard_summary_model.dart';
import 'package:ledgify/features/reports/domain/services/analytics_dashboard_service.dart';
import '../widgets/cash_flow_forecast_chart.dart';
import '../widgets/kpi_metric_card.dart';
import 'reports_hub_screen.dart';

/// Screen presenting the Executive KPI Dashboard, Financial Ratios, and Cash Runway Forecast.
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
      appBar: AppBar(
        title: const Text('Executive Dashboard / मुख्य डैशबोर्ड', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(LedgifyColors.standardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Health Score Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
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
                                  const Text(
                                    'Working capital & liquidity ratios are healthy / स्थिति उत्तम है',
                                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
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
                            bilingualSubtitle: 'शुद्ध लाभ',
                            value: '₹${_summary.netProfitYtd.toStringAsFixed(0)}',
                            changePercent: '+14.2%',
                            isPositive: true,
                            icon: Icons.trending_up,
                            color: LedgifyColors.debitGreen,
                          ),
                          KpiMetricCard(
                            title: 'Operating Cash',
                            bilingualSubtitle: 'रोकड़ शेष',
                            value: '₹${_summary.operatingCash.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: LedgifyColors.primaryBlue,
                          ),
                          KpiMetricCard(
                            title: 'Overdue Receivables',
                            bilingualSubtitle: 'प्राप्य बकाया',
                            value: '₹${_summary.overdueReceivables.toStringAsFixed(0)}',
                            changePercent: '${_ratios?.debtorDaysDso.toStringAsFixed(0) ?? 42} Days DSO',
                            isPositive: false,
                            icon: Icons.call_received,
                            color: LedgifyColors.warningOrange,
                          ),
                          KpiMetricCard(
                            title: 'Overdue Payables',
                            bilingualSubtitle: 'देय बकाया',
                            value: '₹${_summary.overduePayables.toStringAsFixed(0)}',
                            changePercent: '${_ratios?.creditorDaysDpo.toStringAsFixed(0) ?? 30} Days DPO',
                            isPositive: true,
                            icon: Icons.call_made,
                            color: LedgifyColors.secondarySlate,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 30-Day Cash Flow Forecast Chart
                      CashFlowForecastChart(forecastPoints: _forecast),
                      const SizedBox(height: 16),

                      // Financial Ratios Hub
                      if (_ratios != null) ...[
                        const Text('Key Financial Ratios / मुख्य वित्तीय अनुपात', style: LedgifyTypography.cardHeader),
                        const SizedBox(height: 10),

                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                            side: const BorderSide(color: LedgifyColors.surfaceVariant),
                          ),
                          color: LedgifyColors.surfaceCard,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildRatioRow(
                                  'Current Ratio (चालू अनुपात)',
                                  '${_ratios!.currentRatio.toStringAsFixed(2)} : 1',
                                  _ratios!.currentRatioStatus,
                                  _ratios!.currentRatioColor,
                                ),
                                const Divider(height: 20),
                                _buildRatioRow(
                                  'Quick Ratio (त्वरित अनुपात)',
                                  '${_ratios!.quickRatio.toStringAsFixed(2)} : 1',
                                  _ratios!.quickRatio >= 1.0 ? 'Optimal' : 'Low Buffer',
                                  _ratios!.quickRatio >= 1.0 ? LedgifyColors.debitGreen : LedgifyColors.warningOrange,
                                ),
                                const Divider(height: 20),
                                _buildRatioRow(
                                  'Gross Profit Margin (सकल मार्जिन)',
                                  '${_ratios!.grossProfitMargin.toStringAsFixed(1)}%',
                                  'Direct Profitability',
                                  LedgifyColors.primaryBlue,
                                ),
                                const Divider(height: 20),
                                _buildRatioRow(
                                  'Debt-to-Equity (ऋण-पूंजी अनुपात)',
                                  '${_ratios!.debtToEquity.toStringAsFixed(2)}',
                                  _ratios!.debtToEquity <= 1.5 ? 'Conservative' : 'Leveraged',
                                  _ratios!.debtToEquity <= 1.5 ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        Text(
          ratioVal,
          style: LedgifyTypography.financialAmount.copyWith(fontSize: 16, color: color),
        ),
      ],
    );
  }
}
