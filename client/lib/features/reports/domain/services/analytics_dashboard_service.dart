import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/business_ratios_model.dart';
import '../models/cash_flow_forecast_point.dart';
import '../models/dashboard_summary_model.dart';

/// Service calculating business ratios and predicting 30-day cash flow runways via FastAPI backend.
class AnalyticsDashboardService {
  AnalyticsDashboardService();

  /// Fetches core financial ratios
  Future<BusinessRatiosModel> fetchBusinessRatios({DateTime? asOfDate}) async {
    return await executeSafely<BusinessRatiosModel>(() async {
      final response = await ApiClient.get('/reports/dashboard-kpis');
      final data = response as Map<String, dynamic>;
      final ratiosData = data['ratios'] as Map<String, dynamic>? ?? {};
      return BusinessRatiosModel.fromJson(ratiosData);
    });
  }

  /// Fetches 30-day forward-looking predictive cash forecast
  Future<List<CashFlowForecastPoint>> fetch30DayCashForecast({DateTime? startDate}) async {
    return await executeSafely<List<CashFlowForecastPoint>>(() async {
      final response = await ApiClient.get('/reports/dashboard-kpis');
      final data = response as Map<String, dynamic>;
      final points = (data['forecast_points'] as List<dynamic>?) ?? [];
      return points.map((p) => CashFlowForecastPoint.fromJson(p as Map<String, dynamic>)).toList();
    });
  }

  /// Aggregates top-level executive KPI summary
  Future<DashboardSummaryModel> fetchExecutiveSummary() async {
    return await executeSafely<DashboardSummaryModel>(() async {
      final response = await ApiClient.get('/reports/dashboard-kpis');
      final data = response as Map<String, dynamic>;

      return DashboardSummaryModel(
        netProfitYtd: (data['net_profit_ytd'] as num?)?.toDouble() ?? 0.0,
        operatingCash: (data['operating_cash'] as num?)?.toDouble() ?? 0.0,
        overdueReceivables: (data['overdue_receivables'] as num?)?.toDouble() ?? 0.0,
        overduePayables: (data['overdue_payables'] as num?)?.toDouble() ?? 0.0,
        monthlySalesTurnover: (data['monthly_sales_turnover'] as num?)?.toDouble() ?? 0.0,
        healthScore: (data['health_score'] as num?)?.toInt() ?? 90,
      );
    });
  }
}
