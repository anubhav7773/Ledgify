/// Domain model for an individual debit or credit line item within an accounting voucher.
/// Adheres strictly to docs/02_database_schema_ddl_and_indexes.md and docs/04_core_accounting_engine_rules.md.
class VoucherLineItemModel {
  final String id;
  final String businessId;
  final String voucherId;
  final String accountId;
  final String? accountName;
  final String entryType; // 'Dr' or 'Cr'
  final double amount;
  final String? itemDescription;
  final String? stockItemId;
  final String? godownId;
  final String? batchId;
  final double cgstAmt;
  final double sgstAmt;
  final double igstAmt;
  final double cessAmt;

  const VoucherLineItemModel({
    required this.id,
    required this.businessId,
    required this.voucherId,
    required this.accountId,
    this.accountName,
    required this.entryType,
    required this.amount,
    this.itemDescription,
    this.stockItemId,
    this.godownId,
    this.batchId,
    this.cgstAmt = 0.00,
    this.sgstAmt = 0.00,
    this.igstAmt = 0.00,
    this.cessAmt = 0.00,
  });

  factory VoucherLineItemModel.fromJson(Map<String, dynamic> json) {
    return VoucherLineItemModel(
      id: json['id'] as String? ?? '',
      businessId: json['business_id'] as String? ?? '',
      voucherId: json['voucher_id'] as String? ?? '',
      accountId: json['account_id'] as String,
      accountName: json['accounts'] != null
          ? (json['accounts'] as Map<String, dynamic>)['name'] as String?
          : json['account_name'] as String?,
      entryType: json['entry_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      itemDescription: json['item_description'] as String?,
      stockItemId: json['stock_item_id'] as String?,
      godownId: json['godown_id'] as String?,
      batchId: json['batch_id'] as String?,
      cgstAmt: (json['cgst_amt'] as num?)?.toDouble() ?? 0.00,
      sgstAmt: (json['sgst_amt'] as num?)?.toDouble() ?? 0.00,
      igstAmt: (json['igst_amt'] as num?)?.toDouble() ?? 0.00,
      cessAmt: (json['cess_amt'] as num?)?.toDouble() ?? 0.00,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (businessId.isNotEmpty) 'business_id': businessId,
      if (voucherId.isNotEmpty) 'voucher_id': voucherId,
      'account_id': accountId,
      'entry_type': entryType,
      'amount': amount,
      'item_description': itemDescription,
      'stock_item_id': stockItemId,
      'godown_id': godownId,
      'batch_id': batchId,
      'cgst_amt': cgstAmt,
      'sgst_amt': sgstAmt,
      'igst_amt': igstAmt,
      'cess_amt': cessAmt,
    };
  }

  VoucherLineItemModel copyWith({
    String? id,
    String? businessId,
    String? voucherId,
    String? accountId,
    String? accountName,
    String? entryType,
    double? amount,
    String? itemDescription,
    String? stockItemId,
    String? godownId,
    String? batchId,
    double? cgstAmt,
    double? sgstAmt,
    double? igstAmt,
    double? cessAmt,
  }) {
    return VoucherLineItemModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      voucherId: voucherId ?? this.voucherId,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      entryType: entryType ?? this.entryType,
      amount: amount ?? this.amount,
      itemDescription: itemDescription ?? this.itemDescription,
      stockItemId: stockItemId ?? this.stockItemId,
      godownId: godownId ?? this.godownId,
      batchId: batchId ?? this.batchId,
      cgstAmt: cgstAmt ?? this.cgstAmt,
      sgstAmt: sgstAmt ?? this.sgstAmt,
      igstAmt: igstAmt ?? this.igstAmt,
      cessAmt: cessAmt ?? this.cessAmt,
    );
  }
}
