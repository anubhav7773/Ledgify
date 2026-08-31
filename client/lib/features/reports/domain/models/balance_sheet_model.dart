/// Domain model representing a Schedule III compliant Balance Sheet statement.
/// Adheres strictly to docs/04_core_accounting_engine_rules.md.
class BalanceSheetLineDetail {
  final String accountName;
  final String groupName;
  final double closingBal;

  const BalanceSheetLineDetail({
    required this.accountName,
    required this.groupName,
    required this.closingBal,
  });

  factory BalanceSheetLineDetail.fromJson(Map<String, dynamic> json) {
    return BalanceSheetLineDetail(
      accountName: json['account_name'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      closingBal: (json['closing_bal'] as num?)?.toDouble() ?? 0.00,
    );
  }
}

class BalanceSheetReportModel {
  final DateTime asOfDate;
  final double fixedAssets;
  final double currentAssets;
  final double totalAssets;
  final double capitalEquity;
  final double currentNetProfit;
  final double totalEquityAndReserves;
  final double loansLiability;
  final double currentLiabilities;
  final double totalLiabilitiesAndEquity;
  final double difference;
  final bool isBalanced;
  final List<BalanceSheetLineDetail> assetDetails;
  final List<BalanceSheetLineDetail> liabilityDetails;

  const BalanceSheetReportModel({
    required this.asOfDate,
    required this.fixedAssets,
    required this.currentAssets,
    required this.totalAssets,
    required this.capitalEquity,
    required this.currentNetProfit,
    required this.totalEquityAndReserves,
    required this.loansLiability,
    required this.currentLiabilities,
    required this.totalLiabilitiesAndEquity,
    required this.difference,
    required this.isBalanced,
    required this.assetDetails,
    required this.liabilityDetails,
  });

  factory BalanceSheetReportModel.fromJson(Map<String, dynamic> json) {
    final assets = json['asset_details'] as List<dynamic>? ?? [];
    final liabs = json['liability_details'] as List<dynamic>? ?? [];

    return BalanceSheetReportModel(
      asOfDate: DateTime.parse(json['as_of_date'] as String),
      fixedAssets: (json['fixed_assets'] as num?)?.toDouble() ?? 0.00,
      currentAssets: (json['current_assets'] as num?)?.toDouble() ?? 0.00,
      totalAssets: (json['total_assets'] as num?)?.toDouble() ?? 0.00,
      capitalEquity: (json['capital_equity'] as num?)?.toDouble() ?? 0.00,
      currentNetProfit: (json['current_net_profit'] as num?)?.toDouble() ?? 0.00,
      totalEquityAndReserves: (json['total_equity_and_reserves'] as num?)?.toDouble() ?? 0.00,
      loansLiability: (json['loans_liability'] as num?)?.toDouble() ?? 0.00,
      currentLiabilities: (json['current_liabilities'] as num?)?.toDouble() ?? 0.00,
      totalLiabilitiesAndEquity: (json['total_liabilities_and_equity'] as num?)?.toDouble() ?? 0.00,
      difference: (json['difference'] as num?)?.toDouble() ?? 0.00,
      isBalanced: json['is_balanced'] as bool? ?? false,
      assetDetails: assets.map((a) => BalanceSheetLineDetail.fromJson(a as Map<String, dynamic>)).toList(),
      liabilityDetails: liabs.map((l) => BalanceSheetLineDetail.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }
}
