/// Single point on a 30-day forward looking cash flow forecast timeline.
class CashFlowForecastPoint {
  final DateTime date;
  final double projectedInflow;
  final double projectedOutflow;
  final double projectedBalance;

  const CashFlowForecastPoint({
    required this.date,
    required this.projectedInflow,
    required this.projectedOutflow,
    required this.projectedBalance,
  });

  factory CashFlowForecastPoint.fromJson(Map<String, dynamic> json) {
    return CashFlowForecastPoint(
      date: DateTime.parse(json['date'] as String),
      projectedInflow: (json['projected_inflow'] as num?)?.toDouble() ?? 0.00,
      projectedOutflow: (json['projected_outflow'] as num?)?.toDouble() ?? 0.00,
      projectedBalance: (json['projected_balance'] as num?)?.toDouble() ?? 0.00,
    );
  }
}
