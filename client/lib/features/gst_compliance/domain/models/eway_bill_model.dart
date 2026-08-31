import '../services/ewb_validity_calculator.dart';

/// Domain model for E-Way Bills (FORM GST EWB-01).
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md and docs/02_database_schema_ddl_and_indexes.md.
class EWayBillModel {
  final String id;
  final String businessId;
  final String voucherId;
  final String? voucherNumber;
  final String ewbNumber;
  final DateTime ewbDate;
  final DateTime validUpto;
  final String? transporterPartyId;
  final String? transporterName;
  final String? vehicleNumber;
  final double distanceKm;
  final Map<String, dynamic> partAData;
  final Map<String, dynamic> partBData;
  final String status; // 'ACTIVE', 'CANCELLED', 'EXTENDED'
  final DateTime? createdAt;

  const EWayBillModel({
    required this.id,
    required this.businessId,
    required this.voucherId,
    this.voucherNumber,
    required this.ewbNumber,
    required this.ewbDate,
    required this.validUpto,
    this.transporterPartyId,
    this.transporterName,
    this.vehicleNumber,
    required this.distanceKm,
    required this.partAData,
    required this.partBData,
    this.status = 'ACTIVE',
    this.createdAt,
  });

  factory EWayBillModel.fromJson(Map<String, dynamic> json) {
    return EWayBillModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      voucherId: json['voucher_id'] as String,
      voucherNumber: json['vouchers'] != null
          ? (json['vouchers'] as Map<String, dynamic>)['voucher_number'] as String?
          : json['voucher_number'] as String?,
      ewbNumber: json['ewb_number'] as String,
      ewbDate: DateTime.parse(json['ewb_date'] as String),
      validUpto: DateTime.parse(json['valid_upto'] as String),
      transporterPartyId: json['transporter_party_id'] as String?,
      transporterName: json['transporters'] != null
          ? (json['transporters'] as Map<String, dynamic>)['name'] as String?
          : json['transporter_name'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      partAData: json['part_a_data'] != null
          ? Map<String, dynamic>.from(json['part_a_data'] as Map)
          : {},
      partBData: json['part_b_data'] != null
          ? Map<String, dynamic>.from(json['part_b_data'] as Map)
          : {},
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'voucher_id': voucherId,
      'ewb_number': ewbNumber,
      'ewb_date': ewbDate.toIso8601String(),
      'valid_upto': validUpto.toIso8601String(),
      'transporter_party_id': transporterPartyId,
      'vehicle_number': vehicleNumber,
      'distance_km': distanceKm,
      'part_a_data': partAData,
      'part_b_data': partBData,
      'status': status,
    };
  }

  bool get isExpired => DateTime.now().isAfter(validUpto);
  int get remainingHours => validUpto.difference(DateTime.now()).inHours;
  String get remainingCountdownFormatted => EwbValidityCalculator.formatRemainingTime(validUpto);
  bool get isPartBCompleted =>
      vehicleNumber != null && vehicleNumber!.isNotEmpty && vehicleNumber != 'DEF_INTRA_10KM';

  EWayBillModel copyWith({
    String? id,
    String? businessId,
    String? voucherId,
    String? voucherNumber,
    String? ewbNumber,
    DateTime? ewbDate,
    DateTime? validUpto,
    String? transporterPartyId,
    String? transporterName,
    String? vehicleNumber,
    double? distanceKm,
    Map<String, dynamic>? partAData,
    Map<String, dynamic>? partBData,
    String? status,
    DateTime? createdAt,
  }) {
    return EWayBillModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      voucherId: voucherId ?? this.voucherId,
      voucherNumber: voucherNumber ?? this.voucherNumber,
      ewbNumber: ewbNumber ?? this.ewbNumber,
      ewbDate: ewbDate ?? this.ewbDate,
      validUpto: validUpto ?? this.validUpto,
      transporterPartyId: transporterPartyId ?? this.transporterPartyId,
      transporterName: transporterName ?? this.transporterName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      distanceKm: distanceKm ?? this.distanceKm,
      partAData: partAData ?? this.partAData,
      partBData: partBData ?? this.partBData,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
