/// Domain model for Inward Supplies Management (IMS) invoice reconciliation records.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md.
class ImsEntryModel {
  final String id;
  final String businessId;
  final String? voucherId;
  final String supplierGstin;
  final String supplierName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double invoiceValue;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final String imsStatus; // 'PENDING', 'ACCEPTED', 'REJECTED'
  final String? imsRemarks;
  final DateTime? createdAt;

  const ImsEntryModel({
    required this.id,
    required this.businessId,
    this.voucherId,
    required this.supplierGstin,
    required this.supplierName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.invoiceValue,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    this.cess = 0.00,
    this.imsStatus = 'PENDING',
    this.imsRemarks,
    this.createdAt,
  });

  factory ImsEntryModel.fromJson(Map<String, dynamic> json) {
    final summary = json['payload_summary'] as Map<String, dynamic>? ?? {};

    return ImsEntryModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      voucherId: json['voucher_id'] as String?,
      supplierGstin: summary['supplier_gstin'] as String? ?? '27AAAAA0000A1Z5',
      supplierName: summary['supplier_name'] as String? ?? 'Supplier Enterprise',
      invoiceNumber: summary['invoice_number'] as String? ?? 'INV-001',
      invoiceDate: summary['invoice_date'] != null
          ? DateTime.parse(summary['invoice_date'] as String)
          : DateTime.now(),
      invoiceValue: (summary['invoice_value'] as num?)?.toDouble() ?? 0.00,
      taxableValue: (summary['taxable_value'] as num?)?.toDouble() ?? 0.00,
      cgst: (summary['cgst'] as num?)?.toDouble() ?? 0.00,
      sgst: (summary['sgst'] as num?)?.toDouble() ?? 0.00,
      igst: (summary['igst'] as num?)?.toDouble() ?? 0.00,
      cess: (summary['cess'] as num?)?.toDouble() ?? 0.00,
      imsStatus: json['ims_status'] as String? ?? 'PENDING',
      imsRemarks: json['ims_remarks'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'voucher_id': voucherId,
      'return_type': 'IMS',
      'return_period': '${invoiceDate.month.toString().padLeft(2, '0')}${invoiceDate.year}',
      'ims_status': imsStatus,
      'ims_remarks': imsRemarks,
      'payload_summary': {
        'supplier_gstin': supplierGstin,
        'supplier_name': supplierName,
        'invoice_number': invoiceNumber,
        'invoice_date': invoiceDate.toIso8601String().split('T').first,
        'invoice_value': invoiceValue,
        'taxable_value': taxableValue,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'cess': cess,
      },
    };
  }

  double get totalTax => cgst + sgst + igst + cess;

  ImsEntryModel copyWith({
    String? id,
    String? businessId,
    String? voucherId,
    String? supplierGstin,
    String? supplierName,
    String? invoiceNumber,
    DateTime? invoiceDate,
    double? invoiceValue,
    double? taxableValue,
    double? cgst,
    double? sgst,
    double? igst,
    double? cess,
    String? imsStatus,
    String? imsRemarks,
    DateTime? createdAt,
  }) {
    return ImsEntryModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      voucherId: voucherId ?? this.voucherId,
      supplierGstin: supplierGstin ?? this.supplierGstin,
      supplierName: supplierName ?? this.supplierName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      invoiceValue: invoiceValue ?? this.invoiceValue,
      taxableValue: taxableValue ?? this.taxableValue,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      cess: cess ?? this.cess,
      imsStatus: imsStatus ?? this.imsStatus,
      imsRemarks: imsRemarks ?? this.imsRemarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
