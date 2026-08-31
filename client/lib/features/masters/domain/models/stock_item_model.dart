/// Domain model representing an inventory Stock Item in Ledgify.
/// Adheres strictly to docs/02_database_schema_ddl_and_indexes.md.
class StockItemModel {
  final String id;
  final String businessId;
  final String? groupId;
  final String name;
  final String? alias;
  final String uqc; // Unit Quantity Code, e.g. 'NOS', 'KGS', 'BOX'
  final String hsnSacCode;
  final double gstRateSlab; // 0, 0.1, 0.25, 3, 5, 12, 18, 28
  final String costingMethod; // 'FIFO', 'Weighted Average', 'Standard Cost'
  final double openingQuantity;
  final double openingRate;
  final double openingValue;
  final bool isActive;

  const StockItemModel({
    required this.id,
    required this.businessId,
    this.groupId,
    required this.name,
    this.alias,
    this.uqc = 'NOS',
    required this.hsnSacCode,
    this.gstRateSlab = 18.00,
    this.costingMethod = 'FIFO',
    this.openingQuantity = 0.000,
    this.openingRate = 0.00,
    this.openingValue = 0.00,
    this.isActive = true,
  });

  factory StockItemModel.fromJson(Map<String, dynamic> json) {
    return StockItemModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      groupId: json['group_id'] as String?,
      name: json['name'] as String,
      alias: json['alias'] as String?,
      uqc: json['uqc'] as String? ?? 'NOS',
      hsnSacCode: json['hsn_sac_code'] as String? ?? '998311',
      gstRateSlab: (json['gst_rate_slab'] as num?)?.toDouble() ?? 18.00,
      costingMethod: json['costing_method'] as String? ?? 'FIFO',
      openingQuantity: (json['opening_quantity'] as num?)?.toDouble() ?? 0.000,
      openingRate: (json['opening_rate'] as num?)?.toDouble() ?? 0.00,
      openingValue: (json['opening_value'] as num?)?.toDouble() ?? 0.00,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'group_id': groupId,
      'name': name,
      'alias': alias,
      'uqc': uqc,
      'hsn_sac_code': hsnSacCode,
      'gst_rate_slab': gstRateSlab,
      'costing_method': costingMethod,
      'opening_quantity': openingQuantity,
      'opening_rate': openingRate,
      'opening_value': openingValue,
      'is_active': isActive,
    };
  }
}
