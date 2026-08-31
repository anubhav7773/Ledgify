/// Domain model representing an itemized ledger statement with continuous running balances.
class LedgerStatementEntry {
  final String voucherId;
  final DateTime voucherDate;
  final String voucherType;
  final String voucherNumber;
  final String particulars;
  final double debitAmount;
  final double creditAmount;
  final String? itemDescription;
  final double runningBalance;
  final String runningBalanceType; // 'Dr' or 'Cr'

  const LedgerStatementEntry({
    required this.voucherId,
    required this.voucherDate,
    required this.voucherType,
    required this.voucherNumber,
    required this.particulars,
    required this.debitAmount,
    required this.creditAmount,
    this.itemDescription,
    required this.runningBalance,
    required this.runningBalanceType,
  });

  factory LedgerStatementEntry.fromJson(Map<String, dynamic> json) {
    return LedgerStatementEntry(
      voucherId: json['voucher_id'] as String? ?? '',
      voucherDate: DateTime.parse(json['voucher_date'] as String),
      voucherType: json['voucher_type'] as String? ?? 'Journal',
      voucherNumber: json['voucher_number'] as String? ?? '',
      particulars: json['particulars'] as String? ?? 'As per details',
      debitAmount: (json['debit_amount'] as num?)?.toDouble() ?? 0.00,
      creditAmount: (json['credit_amount'] as num?)?.toDouble() ?? 0.00,
      itemDescription: json['item_description'] as String?,
      runningBalance: (json['running_balance'] as num?)?.toDouble() ?? 0.00,
      runningBalanceType: json['running_balance_type'] as String? ?? 'Dr',
    );
  }
}

class LedgerStatementReportModel {
  final String accountId;
  final String accountName;
  final String groupName;
  final DateTime fromDate;
  final DateTime toDate;
  final double openingBalance;
  final String openingBalanceType;
  final double totalDebit;
  final double totalCredit;
  final List<LedgerStatementEntry> entries;

  const LedgerStatementReportModel({
    required this.accountId,
    required this.accountName,
    required this.groupName,
    required this.fromDate,
    required this.toDate,
    required this.openingBalance,
    required this.openingBalanceType,
    required this.totalDebit,
    required this.totalCredit,
    required this.entries,
  });

  factory LedgerStatementReportModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];

    return LedgerStatementReportModel(
      accountId: json['account_id'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.00,
      openingBalanceType: json['opening_balance_type'] as String? ?? 'Dr',
      totalDebit: (json['total_debit'] as num?)?.toDouble() ?? 0.00,
      totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0.00,
      entries: rawEntries.map((e) => LedgerStatementEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  double get closingBalance {
    if (entries.isNotEmpty) {
      return entries.last.runningBalance;
    }
    return openingBalance;
  }

  String get closingBalanceType {
    if (entries.isNotEmpty) {
      return entries.last.runningBalanceType;
    }
    return openingBalanceType;
  }
}
