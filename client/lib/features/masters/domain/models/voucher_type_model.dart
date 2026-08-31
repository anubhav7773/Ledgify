/// Master voucher type definition domain model.
/// Adheres strictly to docs/02_database_schema_ddl_and_indexes.md.
class VoucherTypeModel {
  final String id;
  final String? businessId;
  final String name;
  final String category; // 'Sales', 'Purchase', 'Payment', 'Receipt', 'Contra', 'Journal', etc.
  final bool isSystemDefault;
  final bool eInvoiceApplicable;
  final String numberingMethod;
  final String restartNumberingPeriod;

  const VoucherTypeModel({
    required this.id,
    this.businessId,
    required this.name,
    required this.category,
    this.isSystemDefault = false,
    this.eInvoiceApplicable = false,
    this.numberingMethod = 'Automatic',
    this.restartNumberingPeriod = 'Yearly',
  });

  factory VoucherTypeModel.fromJson(Map<String, dynamic> json) {
    return VoucherTypeModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String,
      isSystemDefault: json['is_system_default'] as bool? ?? false,
      eInvoiceApplicable: json['e_invoice_applicable'] as bool? ?? false,
      numberingMethod: json['numbering_method'] as String? ?? 'Automatic',
      restartNumberingPeriod: json['restart_numbering_period'] as String? ?? 'Yearly',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'category': category,
      'is_system_default': isSystemDefault,
      'e_invoice_applicable': eInvoiceApplicable,
      'numbering_method': numberingMethod,
      'restart_numbering_period': restartNumberingPeriod,
    };
  }

  VoucherTypeModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? category,
    bool? isSystemDefault,
    bool? eInvoiceApplicable,
    String? numberingMethod,
    String? restartNumberingPeriod,
  }) {
    return VoucherTypeModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      category: category ?? this.category,
      isSystemDefault: isSystemDefault ?? this.isSystemDefault,
      eInvoiceApplicable: eInvoiceApplicable ?? this.eInvoiceApplicable,
      numberingMethod: numberingMethod ?? this.numberingMethod,
      restartNumberingPeriod: restartNumberingPeriod ?? this.restartNumberingPeriod,
    );
  }
}
