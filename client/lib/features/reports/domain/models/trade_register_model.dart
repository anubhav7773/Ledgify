/// Domain model representing Sales and Purchase Trade Registers.
class TradeRegisterEntry {
  final String voucherId;
  final String voucherNumber;
  final DateTime voucherDate;
  final String? partyAccountId;
  final String partyName;
  final String? partyGstin;
  final String? referenceNumber;
  final String? irn;
  final String? eWayBillNo;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double netTotal;

  const TradeRegisterEntry({
    required this.voucherId,
    required this.voucherNumber,
    required this.voucherDate,
    this.partyAccountId,
    required this.partyName,
    this.partyGstin,
    this.referenceNumber,
    this.irn,
    this.eWayBillNo,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.netTotal,
  });

  factory TradeRegisterEntry.fromJson(Map<String, dynamic> json) {
    return TradeRegisterEntry(
      voucherId: json['voucher_id'] as String? ?? '',
      voucherNumber: json['voucher_number'] as String? ?? '',
      voucherDate: DateTime.parse(json['voucher_date'] as String),
      partyAccountId: json['party_account_id'] as String?,
      partyName: json['party_name'] as String? ?? 'Cash Party',
      partyGstin: json['party_gstin'] as String?,
      referenceNumber: json['reference_number'] as String?,
      irn: json['irn'] as String?,
      eWayBillNo: json['e_way_bill_no'] as String?,
      taxableValue: (json['taxable_value'] as num?)?.toDouble() ?? 0.00,
      cgstAmount: (json['cgst_amount'] as num?)?.toDouble() ?? 0.00,
      sgstAmount: (json['sgst_amount'] as num?)?.toDouble() ?? 0.00,
      igstAmount: (json['igst_amount'] as num?)?.toDouble() ?? 0.00,
      netTotal: (json['net_total'] as num?)?.toDouble() ?? 0.00,
    );
  }

  double get totalTax => cgstAmount + sgstAmount + igstAmount;
}

class TradeRegisterReportModel {
  final String registerType; // 'SALES' or 'PURCHASE'
  final DateTime fromDate;
  final DateTime toDate;
  final int totalCount;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalNetAmount;
  final List<TradeRegisterEntry> entries;

  const TradeRegisterReportModel({
    required this.registerType,
    required this.fromDate,
    required this.toDate,
    required this.totalCount,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalNetAmount,
    required this.entries,
  });

  factory TradeRegisterReportModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];

    return TradeRegisterReportModel(
      registerType: json['register_type'] as String? ?? 'SALES',
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      totalCount: json['total_count'] as int? ?? 0,
      totalTaxableValue: (json['total_taxable_value'] as num?)?.toDouble() ?? 0.00,
      totalCgst: (json['total_cgst'] as num?)?.toDouble() ?? 0.00,
      totalSgst: (json['total_sgst'] as num?)?.toDouble() ?? 0.00,
      totalIgst: (json['total_igst'] as num?)?.toDouble() ?? 0.00,
      totalNetAmount: (json['total_net_amount'] as num?)?.toDouble() ?? 0.00,
      entries: rawEntries.map((e) => TradeRegisterEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
