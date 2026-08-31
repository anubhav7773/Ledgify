import 'voucher_line_item_model.dart';

/// Domain model for Double-Entry Accounting Vouchers.
/// Enforces mathematical double-entry equality ($\sum \text{Debits} = \sum \text{Credits}$).
/// Adheres strictly to docs/04_core_accounting_engine_rules.md.
class VoucherModel {
  final String id;
  final String businessId;
  final String voucherTypeId;
  final String? voucherTypeName;
  final String voucherNumber;
  final String? originalVoucherNumber;
  final DateTime voucherDate;
  final String? narration;
  final String? referenceNumber;
  final DateTime? referenceDate;
  final bool isCancelled;
  final double? aiConfidenceScore;
  final String? irn;
  final String? qrCode;
  final String? ackNo;
  final DateTime? ackDate;
  final String? eWayBillNo;
  final List<VoucherLineItemModel> lineItems;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VoucherModel({
    required this.id,
    required this.businessId,
    required this.voucherTypeId,
    this.voucherTypeName,
    required this.voucherNumber,
    this.originalVoucherNumber,
    required this.voucherDate,
    this.narration,
    this.referenceNumber,
    this.referenceDate,
    this.isCancelled = false,
    this.aiConfidenceScore,
    this.irn,
    this.qrCode,
    this.ackNo,
    this.ackDate,
    this.eWayBillNo,
    this.lineItems = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor parsing voucher header and line items
  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    final rawLineItems = json['voucher_line_items'] as List<dynamic>? ?? [];
    final items = rawLineItems
        .map((item) => VoucherLineItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return VoucherModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      voucherTypeId: json['voucher_type_id'] as String,
      voucherTypeName: json['voucher_types'] != null
          ? (json['voucher_types'] as Map<String, dynamic>)['name'] as String?
          : json['voucher_type_name'] as String?,
      voucherNumber: json['voucher_number'] as String,
      originalVoucherNumber: json['original_voucher_number'] as String?,
      voucherDate: DateTime.parse(json['voucher_date'] as String),
      narration: json['narration'] as String?,
      referenceNumber: json['reference_number'] as String?,
      referenceDate: json['reference_date'] != null
          ? DateTime.parse(json['reference_date'] as String)
          : null,
      isCancelled: json['is_cancelled'] as bool? ?? false,
      aiConfidenceScore: (json['ai_confidence_score'] as num?)?.toDouble(),
      irn: json['irn'] as String?,
      qrCode: json['qr_code'] as String?,
      ackNo: json['ack_no'] as String?,
      ackDate: json['ack_date'] != null ? DateTime.parse(json['ack_date'] as String) : null,
      eWayBillNo: json['e_way_bill_no'] as String?,
      lineItems: items,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'voucher_type_id': voucherTypeId,
      'voucher_number': voucherNumber,
      if (originalVoucherNumber != null) 'original_voucher_number': originalVoucherNumber,
      'voucher_date': voucherDate.toIso8601String().split('T').first,
      'narration': narration,
      'reference_number': referenceNumber,
      if (referenceDate != null)
        'reference_date': referenceDate!.toIso8601String().split('T').first,
      'is_cancelled': isCancelled,
      if (aiConfidenceScore != null) 'ai_confidence_score': aiConfidenceScore,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
    };
  }

  /// Calculates total debit amount across line items
  double get totalDebitAmount {
    return lineItems
        .where((item) => item.entryType == 'Dr')
        .fold(0.00, (sum, item) => sum + item.amount);
  }

  /// Calculates total credit amount across line items
  double get totalCreditAmount {
    return lineItems
        .where((item) => item.entryType == 'Cr')
        .fold(0.00, (sum, item) => sum + item.amount);
  }

  /// Checks if the double-entry invariant is satisfied (\sum Debits == \sum Credits)
  bool get isBalanced {
    if (lineItems.length < 2) return false;
    final diff = (totalDebitAmount - totalCreditAmount).abs();
    return diff < 0.001;
  }

  /// Difference between debits and credits
  double get differenceAmount => (totalDebitAmount - totalCreditAmount).abs();

  VoucherModel copyWith({
    String? id,
    String? businessId,
    String? voucherTypeId,
    String? voucherTypeName,
    String? voucherNumber,
    String? originalVoucherNumber,
    DateTime? voucherDate,
    String? narration,
    String? referenceNumber,
    DateTime? referenceDate,
    bool? isCancelled,
    double? aiConfidenceScore,
    String? irn,
    String? qrCode,
    String? ackNo,
    DateTime? ackDate,
    String? eWayBillNo,
    List<VoucherLineItemModel>? lineItems,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoucherModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      voucherTypeId: voucherTypeId ?? this.voucherTypeId,
      voucherTypeName: voucherTypeName ?? this.voucherTypeName,
      voucherNumber: voucherNumber ?? this.voucherNumber,
      originalVoucherNumber: originalVoucherNumber ?? this.originalVoucherNumber,
      voucherDate: voucherDate ?? this.voucherDate,
      narration: narration ?? this.narration,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      referenceDate: referenceDate ?? this.referenceDate,
      isCancelled: isCancelled ?? this.isCancelled,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      irn: irn ?? this.irn,
      qrCode: qrCode ?? this.qrCode,
      ackNo: ackNo ?? this.ackNo,
      ackDate: ackDate ?? this.ackDate,
      eWayBillNo: eWayBillNo ?? this.eWayBillNo,
      lineItems: lineItems ?? this.lineItems,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
