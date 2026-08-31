/// Domain model representing GSTR-1 and GSTR-3B summarized tables and net statutory tax liabilities.
class GstrSummaryModel {
  final String returnType; // 'GSTR1', 'GSTR3B'
  final String returnPeriod; // 'MMYYYY'
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double totalTax;
  final Map<String, dynamic> rawTableData;

  const GstrSummaryModel({
    required this.returnType,
    required this.returnPeriod,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    this.totalCess = 0.00,
    required this.totalTax,
    required this.rawTableData,
  });

  factory GstrSummaryModel.fromGstr1Json(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return GstrSummaryModel(
      returnType: 'GSTR1',
      returnPeriod: json['fp'] as String? ?? '',
      totalTaxableValue: (summary['total_taxable_value'] as num?)?.toDouble() ?? 0.00,
      totalCgst: (summary['total_cgst'] as num?)?.toDouble() ?? 0.00,
      totalSgst: (summary['total_sgst'] as num?)?.toDouble() ?? 0.00,
      totalIgst: (summary['total_igst'] as num?)?.toDouble() ?? 0.00,
      totalCess: (summary['total_cess'] as num?)?.toDouble() ?? 0.00,
      totalTax: (summary['total_tax'] as num?)?.toDouble() ?? 0.00,
      rawTableData: json,
    );
  }

  factory GstrSummaryModel.fromGstr3bJson(Map<String, dynamic> json) {
    final t31 = (json['table_3_1'] as Map<String, dynamic>?)?['outward_taxable_supplies'] as Map<String, dynamic>? ?? {};
    final double taxable = (t31['taxable_value'] as num?)?.toDouble() ?? 0.00;
    final double cgst = (t31['cgst'] as num?)?.toDouble() ?? 0.00;
    final double sgst = (t31['sgst'] as num?)?.toDouble() ?? 0.00;
    final double igst = (t31['igst'] as num?)?.toDouble() ?? 0.00;
    final double cess = (t31['cess'] as num?)?.toDouble() ?? 0.00;

    return GstrSummaryModel(
      returnType: 'GSTR3B',
      returnPeriod: json['return_period'] as String? ?? '',
      totalTaxableValue: taxable,
      totalCgst: cgst,
      totalSgst: sgst,
      totalIgst: igst,
      totalCess: cess,
      totalTax: cgst + sgst + igst + cess,
      rawTableData: json,
    );
  }
}
