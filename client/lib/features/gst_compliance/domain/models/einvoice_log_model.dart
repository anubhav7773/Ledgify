/// Domain model representing E-Invoice IRP audit logs.
/// Adheres strictly to docs/02_database_schema_ddl_and_indexes.md.
class EInvoiceLogModel {
  final String id;
  final String businessId;
  final String voucherId;
  final String irn;
  final String ackNo;
  final DateTime ackDate;
  final String? signedInvoice;
  final String signedQrCode;
  final Map<String, dynamic> payloadJson;
  final Map<String, dynamic> irpResponse;
  final String status; // 'SUCCESS', 'FAILED', 'CANCELLED'
  final DateTime? createdAt;

  const EInvoiceLogModel({
    required this.id,
    required this.businessId,
    required this.voucherId,
    required this.irn,
    required this.ackNo,
    required this.ackDate,
    this.signedInvoice,
    required this.signedQrCode,
    required this.payloadJson,
    required this.irpResponse,
    this.status = 'SUCCESS',
    this.createdAt,
  });

  factory EInvoiceLogModel.fromJson(Map<String, dynamic> json) {
    return EInvoiceLogModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      voucherId: json['voucher_id'] as String,
      irn: json['irn'] as String,
      ackNo: json['ack_no'] as String,
      ackDate: DateTime.parse(json['ack_date'] as String),
      signedInvoice: json['signed_invoice'] as String?,
      signedQrCode: json['signed_qr_code'] as String? ?? '',
      payloadJson: json['payload_json'] != null
          ? Map<String, dynamic>.from(json['payload_json'] as Map)
          : {},
      irpResponse: json['irp_response'] != null
          ? Map<String, dynamic>.from(json['irp_response'] as Map)
          : {},
      status: json['status'] as String? ?? 'SUCCESS',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'voucher_id': voucherId,
      'irn': irn,
      'ack_no': ackNo,
      'ack_date': ackDate.toIso8601String(),
      'signed_invoice': signedInvoice,
      'signed_qr_code': signedQrCode,
      'payload_json': payloadJson,
      'irp_response': irpResponse,
      'status': status,
    };
  }

  EInvoiceLogModel copyWith({
    String? id,
    String? businessId,
    String? voucherId,
    String? irn,
    String? ackNo,
    DateTime? ackDate,
    String? signedInvoice,
    String? signedQrCode,
    Map<String, dynamic>? payloadJson,
    Map<String, dynamic>? irpResponse,
    String? status,
    DateTime? createdAt,
  }) {
    return EInvoiceLogModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      voucherId: voucherId ?? this.voucherId,
      irn: irn ?? this.irn,
      ackNo: ackNo ?? this.ackNo,
      ackDate: ackDate ?? this.ackDate,
      signedInvoice: signedInvoice ?? this.signedInvoice,
      signedQrCode: signedQrCode ?? this.signedQrCode,
      payloadJson: payloadJson ?? this.payloadJson,
      irpResponse: irpResponse ?? this.irpResponse,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
