/// Domain model for multi-GST registrations.
/// Adheres strictly to docs/02_database_schema_ddl_and_indexes.md.
class GstRegistrationModel {
  final String id;
  final String businessId;
  final String gstin;
  final String legalName;
  final String? tradeName;
  final int stateCode;
  final String principalAddress;
  final int pincode;
  final bool isComposition;
  final bool isActive;
  final DateTime? createdAt;

  const GstRegistrationModel({
    required this.id,
    required this.businessId,
    required this.gstin,
    required this.legalName,
    this.tradeName,
    required this.stateCode,
    required this.principalAddress,
    required this.pincode,
    this.isComposition = false,
    this.isActive = true,
    this.createdAt,
  });

  factory GstRegistrationModel.fromJson(Map<String, dynamic> json) {
    return GstRegistrationModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      gstin: json['gstin'] as String,
      legalName: json['legal_name'] as String,
      tradeName: json['trade_name'] as String?,
      stateCode: (json['state_code'] as num).toInt(),
      principalAddress: json['principal_address'] as String,
      pincode: (json['pincode'] as num).toInt(),
      isComposition: json['is_composition'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'gstin': gstin,
      'legal_name': legalName,
      'trade_name': tradeName,
      'state_code': stateCode,
      'principal_address': principalAddress,
      'pincode': pincode,
      'is_composition': isComposition,
      'is_active': isActive,
    };
  }

  GstRegistrationModel copyWith({
    String? id,
    String? businessId,
    String? gstin,
    String? legalName,
    String? tradeName,
    int? stateCode,
    String? principalAddress,
    int? pincode,
    bool? isComposition,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return GstRegistrationModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      gstin: gstin ?? this.gstin,
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      stateCode: stateCode ?? this.stateCode,
      principalAddress: principalAddress ?? this.principalAddress,
      pincode: pincode ?? this.pincode,
      isComposition: isComposition ?? this.isComposition,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
