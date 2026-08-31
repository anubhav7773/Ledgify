/// Domain model representing an AS 3 Direct Method Cash Flow statement.
class CashFlowReportModel {
  final DateTime fromDate;
  final DateTime toDate;
  final double openingCashEquivalents;
  final double operatingInflows;
  final double operatingOutflows;
  final double netOperatingCashFlow;
  final double investingCashFlow;
  final double financingCashFlow;
  final double netCashDelta;
  final double closingCashEquivalents;

  const CashFlowReportModel({
    required this.fromDate,
    required this.toDate,
    required this.openingCashEquivalents,
    required this.operatingInflows,
    required this.operatingOutflows,
    required this.netOperatingCashFlow,
    required this.investingCashFlow,
    required this.financingCashFlow,
    required this.netCashDelta,
    required this.closingCashEquivalents,
  });

  factory CashFlowReportModel.fromJson(Map<String, dynamic> json) {
    return CashFlowReportModel(
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      openingCashEquivalents: (json['opening_cash_equivalents'] as num?)?.toDouble() ?? 0.00,
      operatingInflows: (json['operating_inflows'] as num?)?.toDouble() ?? 0.00,
      operatingOutflows: (json['operating_outflows'] as num?)?.toDouble() ?? 0.00,
      netOperatingCashFlow: (json['net_operating_cash_flow'] as num?)?.toDouble() ?? 0.00,
      investingCashFlow: (json['investing_cash_flow'] as num?)?.toDouble() ?? 0.00,
      financingCashFlow: (json['financing_cash_flow'] as num?)?.toDouble() ?? 0.00,
      netCashDelta: (json['net_cash_delta'] as num?)?.toDouble() ?? 0.00,
      closingCashEquivalents: (json['closing_cash_equivalents'] as num?)?.toDouble() ?? 0.00,
    );
  }
}
