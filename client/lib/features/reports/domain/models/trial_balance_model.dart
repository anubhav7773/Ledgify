/// Domain model representing a multi-column Trial Balance report.
/// Adheres strictly to docs/04_core_accounting_engine_rules.md.
class TrialBalanceLineModel {
  final String accountId;
  final String accountName;
  final String groupName;
  final String primaryClassification;
  final double openingDr;
  final double openingCr;
  final double periodDr;
  final double periodCr;
  final double closingDr;
  final double closingCr;

  const TrialBalanceLineModel({
    required this.accountId,
    required this.accountName,
    required this.groupName,
    required this.primaryClassification,
    required this.openingDr,
    required this.openingCr,
    required this.periodDr,
    required this.periodCr,
    required this.closingDr,
    required this.closingCr,
  });

  factory TrialBalanceLineModel.fromJson(Map<String, dynamic> json) {
    return TrialBalanceLineModel(
      accountId: json['account_id'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      primaryClassification: json['primary_classification'] as String? ?? 'Asset',
      openingDr: (json['opening_dr'] as num?)?.toDouble() ?? 0.00,
      openingCr: (json['opening_cr'] as num?)?.toDouble() ?? 0.00,
      periodDr: (json['period_dr'] as num?)?.toDouble() ?? 0.00,
      periodCr: (json['period_cr'] as num?)?.toDouble() ?? 0.00,
      closingDr: (json['closing_dr'] as num?)?.toDouble() ?? 0.00,
      closingCr: (json['closing_cr'] as num?)?.toDouble() ?? 0.00,
    );
  }
}

class TrialBalanceReportModel {
  final DateTime fromDate;
  final DateTime toDate;
  final double totalOpeningDr;
  final double totalOpeningCr;
  final double totalPeriodDr;
  final double totalPeriodCr;
  final double totalClosingDr;
  final double totalClosingCr;
  final bool isBalanced;
  final List<TrialBalanceLineModel> lines;

  const TrialBalanceReportModel({
    required this.fromDate,
    required this.toDate,
    required this.totalOpeningDr,
    required this.totalOpeningCr,
    required this.totalPeriodDr,
    required this.totalPeriodCr,
    required this.totalClosingDr,
    required this.totalClosingCr,
    required this.isBalanced,
    required this.lines,
  });

  factory TrialBalanceReportModel.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? [];

    return TrialBalanceReportModel(
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      totalOpeningDr: (json['total_opening_dr'] as num?)?.toDouble() ?? 0.00,
      totalOpeningCr: (json['total_opening_cr'] as num?)?.toDouble() ?? 0.00,
      totalPeriodDr: (json['total_period_dr'] as num?)?.toDouble() ?? 0.00,
      totalPeriodCr: (json['total_period_cr'] as num?)?.toDouble() ?? 0.00,
      totalClosingDr: (json['total_closing_dr'] as num?)?.toDouble() ?? 0.00,
      totalClosingCr: (json['total_closing_cr'] as num?)?.toDouble() ?? 0.00,
      isBalanced: json['is_balanced'] as bool? ?? false,
      lines: rawLines.map((l) => TrialBalanceLineModel.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }
}
