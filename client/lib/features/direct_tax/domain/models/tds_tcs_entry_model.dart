/// Domain model representing a TDS (e.g. 194Q) or TCS (e.g. 206C) entry in Ledgify.
/// Adheres strictly to docs/08_banking_brs_payroll_direct_tax.md.
class TdsTcsEntryModel {
  final String id;
  final String businessId;
  final String voucherId;
  final String sectionCode; // '194Q', '206C(1H)', '192'
  final String partyPan;
  final String? partyName;
  final double assessedAmount;
  final double tdsTcsRate; // e.g. 0.001 for 0.1%, 0.05 for 5%
  final double taxAmount;
  final String? challanNumber;
  final DateTime? challanDate;
  final String formType; // '26Q', '27EQ', '24Q'
  final DateTime? createdAt;

  const TdsTcsEntryModel({
    required this.id,
    required this.businessId,
    required this.voucherId,
    required this.sectionCode,
    required this.partyPan,
    this.partyName,
    required this.assessedAmount,
    required this.tdsTcsRate,
    required this.taxAmount,
    this.challanNumber,
    this.challanDate,
    required this.formType,
    this.createdAt,
  });

  factory TdsTcsEntryModel.fromJson(Map<String, dynamic> json) {
    return TdsTcsEntryModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      voucherId: json['voucher_id'] as String,
      sectionCode: json['section_code'] as String,
      partyPan: json['party_pan'] as String,
      partyName: json['party_name'] as String?,
      assessedAmount: (json['assessed_amount'] as num?)?.toDouble() ?? 0.00,
      tdsTcsRate: (json['tds_tcs_rate'] as num?)?.toDouble() ?? 0.001,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.00,
      challanNumber: json['challan_number'] as String?,
      challanDate: json['challan_date'] != null ? DateTime.parse(json['challan_date'] as String) : null,
      formType: json['form_type'] as String? ?? '26Q',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'voucher_id': voucherId,
      'section_code': sectionCode,
      'party_pan': partyPan,
      'assessed_amount': assessedAmount,
      'tds_tcs_rate': tdsTcsRate,
      'tax_amount': taxAmount,
      'challan_number': challanNumber,
      'challan_date': challanDate?.toIso8601String().split('T').first,
      'form_type': formType,
    };
  }

  bool get isDeposited => challanNumber != null && challanNumber!.isNotEmpty;
  double get taxRatePercentage => double.parse((tdsTcsRate * 100).toStringAsFixed(2));

  TdsTcsEntryModel copyWith({
    String? id,
    String? businessId,
    String? voucherId,
    String? sectionCode,
    String? partyPan,
    String? partyName,
    double? assessedAmount,
    double? tdsTcsRate,
    double? taxAmount,
    String? challanNumber,
    DateTime? challanDate,
    String? formType,
    DateTime? createdAt,
  }) {
    return TdsTcsEntryModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      voucherId: voucherId ?? this.voucherId,
      sectionCode: sectionCode ?? this.sectionCode,
      partyPan: partyPan ?? this.partyPan,
      partyName: partyName ?? this.partyName,
      assessedAmount: assessedAmount ?? this.assessedAmount,
      tdsTcsRate: tdsTcsRate ?? this.tdsTcsRate,
      taxAmount: taxAmount ?? this.taxAmount,
      challanNumber: challanNumber ?? this.challanNumber,
      challanDate: challanDate ?? this.challanDate,
      formType: formType ?? this.formType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
