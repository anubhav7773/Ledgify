/// Domain model representing the top-level KPI metrics for the Executive Dashboard.
class DashboardSummaryModel {
  final double netProfitYtd;
  final double operatingCash;
  final double overdueReceivables;
  final double overduePayables;
  final double monthlySalesTurnover;
  final int healthScore;

  const DashboardSummaryModel({
    required this.netProfitYtd,
    required this.operatingCash,
    required this.overdueReceivables,
    required this.overduePayables,
    required this.monthlySalesTurnover,
    this.healthScore = 92,
  });

  factory DashboardSummaryModel.empty() {
    return const DashboardSummaryModel(
      netProfitYtd: 0.0,
      operatingCash: 0.0,
      overdueReceivables: 0.0,
      overduePayables: 0.0,
      monthlySalesTurnover: 0.0,
      healthScore: 90,
    );
  }
}
