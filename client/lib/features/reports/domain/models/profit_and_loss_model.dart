/// Domain model representing the Trading and Profit & Loss Statement.
/// Adheres strictly to docs/04_core_accounting_engine_rules.md.
class PnLLineDetail {
  final String accountName;
  final String groupName;
  final double amount;

  const PnLLineDetail({
    required this.accountName,
    required this.groupName,
    required this.amount,
  });

  factory PnLLineDetail.fromJson(Map<String, dynamic> json) {
    return PnLLineDetail(
      accountName: json['account_name'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.00,
    );
  }
}

class ProfitAndLossReportModel {
  final DateTime fromDate;
  final DateTime toDate;
  final double directIncomes;
  final double directExpenses;
  final double grossProfit;
  final double indirectIncomes;
  final double indirectExpenses;
  final double netProfit;
  final List<PnLLineDetail> incomeDetails;
  final List<PnLLineDetail> expenseDetails;

  const ProfitAndLossReportModel({
    required this.fromDate,
    required this.toDate,
    required this.directIncomes,
    required this.directExpenses,
    required this.grossProfit,
    required this.indirectIncomes,
    required this.indirectExpenses,
    required this.netProfit,
    required this.incomeDetails,
    required this.expenseDetails,
  });

  factory ProfitAndLossReportModel.fromJson(Map<String, dynamic> json) {
    final inc = json['income_details'] as List<dynamic>? ?? [];
    final exp = json['expense_details'] as List<dynamic>? ?? [];

    return ProfitAndLossReportModel(
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      directIncomes: (json['direct_incomes'] as num?)?.toDouble() ?? 0.00,
      directExpenses: (json['direct_expenses'] as num?)?.toDouble() ?? 0.00,
      grossProfit: (json['gross_profit'] as num?)?.toDouble() ?? 0.00,
      indirectIncomes: (json['indirect_incomes'] as num?)?.toDouble() ?? 0.00,
      indirectExpenses: (json['indirect_expenses'] as num?)?.toDouble() ?? 0.00,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0.00,
      incomeDetails: inc.map((i) => PnLLineDetail.fromJson(i as Map<String, dynamic>)).toList(),
      expenseDetails: exp.map((e) => PnLLineDetail.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  bool get isProfit => netProfit >= 0;
}
