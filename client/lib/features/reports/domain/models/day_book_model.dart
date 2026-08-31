/// Domain model representing a Day Book daily transaction register.
class DayBookLineItem {
  final String accountId;
  final String accountName;
  final String entryType;
  final double amount;
  final String? itemDescription;

  const DayBookLineItem({
    required this.accountId,
    required this.accountName,
    required this.entryType,
    required this.amount,
    this.itemDescription,
  });

  factory DayBookLineItem.fromJson(Map<String, dynamic> json) {
    return DayBookLineItem(
      accountId: json['account_id'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      entryType: json['entry_type'] as String? ?? 'Dr',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.00,
      itemDescription: json['item_description'] as String?,
    );
  }
}

class DayBookVoucherEntry {
  final String voucherId;
  final String voucherNumber;
  final String voucherTypeName;
  final DateTime voucherDate;
  final String? referenceNumber;
  final String? narration;
  final bool isCancelled;
  final double totalAmount;
  final List<DayBookLineItem> lineItems;

  const DayBookVoucherEntry({
    required this.voucherId,
    required this.voucherNumber,
    required this.voucherTypeName,
    required this.voucherDate,
    this.referenceNumber,
    this.narration,
    this.isCancelled = false,
    required this.totalAmount,
    required this.lineItems,
  });

  factory DayBookVoucherEntry.fromJson(Map<String, dynamic> json) {
    final rawLines = json['line_items'] as List<dynamic>? ?? [];

    return DayBookVoucherEntry(
      voucherId: json['voucher_id'] as String? ?? '',
      voucherNumber: json['voucher_number'] as String? ?? '',
      voucherTypeName: json['voucher_type_name'] as String? ?? 'Journal',
      voucherDate: DateTime.parse(json['voucher_date'] as String),
      referenceNumber: json['reference_number'] as String?,
      narration: json['narration'] as String?,
      isCancelled: json['is_cancelled'] as bool? ?? false,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.00,
      lineItems: rawLines.map((l) => DayBookLineItem.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }
}

class DayBookReportModel {
  final DateTime date;
  final int totalVouchers;
  final double totalTurnover;
  final List<DayBookVoucherEntry> vouchers;

  const DayBookReportModel({
    required this.date,
    required this.totalVouchers,
    required this.totalTurnover,
    required this.vouchers,
  });

  factory DayBookReportModel.fromJson(Map<String, dynamic> json) {
    final rawVouchers = json['vouchers'] as List<dynamic>? ?? [];

    return DayBookReportModel(
      date: DateTime.parse(json['date'] as String),
      totalVouchers: json['total_vouchers'] as int? ?? 0,
      totalTurnover: (json['total_turnover'] as num?)?.toDouble() ?? 0.00,
      vouchers: rawVouchers.map((v) => DayBookVoucherEntry.fromJson(v as Map<String, dynamic>)).toList(),
    );
  }
}
