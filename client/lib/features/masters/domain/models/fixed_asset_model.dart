/// Fixed Asset domain model for Companies Act 2013 (Schedule II) compliance.
/// Adheres strictly to docs/04_core_accounting_engine_rules.md and docs/02_database_schema_ddl_and_indexes.md.
class FixedAssetModel {
  final String id;
  final String businessId;
  final String assetAccountId;
  final String? assetAccountName;
  final String assetName;
  final String category;
  final DateTime purchaseDate;
  final double originalCost;
  final double residualValue;
  final double usefulLifeYears;
  final bool isNesd;
  final String shiftWorking; // 'Single', 'Double', 'Triple'
  final bool itcClaimedFlag;
  final double accumulatedDepreciation;
  final bool isDisposed;
  final DateTime? disposalDate;
  final DateTime? createdAt;

  const FixedAssetModel({
    required this.id,
    required this.businessId,
    required this.assetAccountId,
    this.assetAccountName,
    required this.assetName,
    required this.category,
    required this.purchaseDate,
    required this.originalCost,
    required this.residualValue,
    required this.usefulLifeYears,
    this.isNesd = false,
    this.shiftWorking = 'Single',
    this.itcClaimedFlag = false,
    this.accumulatedDepreciation = 0.00,
    this.isDisposed = false,
    this.disposalDate,
    this.createdAt,
  });

  factory FixedAssetModel.fromJson(Map<String, dynamic> json) {
    return FixedAssetModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      assetAccountId: json['asset_account_id'] as String,
      assetAccountName: json['accounts'] != null
          ? (json['accounts'] as Map<String, dynamic>)['name'] as String?
          : json['asset_account_name'] as String?,
      assetName: json['asset_name'] as String,
      category: json['category'] as String,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      originalCost: (json['original_cost'] as num).toDouble(),
      residualValue: (json['residual_value'] as num).toDouble(),
      usefulLifeYears: (json['useful_life_years'] as num).toDouble(),
      isNesd: json['is_nesd'] as bool? ?? false,
      shiftWorking: json['shift_working'] as String? ?? 'Single',
      itcClaimedFlag: json['itc_claimed_flag'] as bool? ?? false,
      accumulatedDepreciation: (json['accumulated_depreciation'] as num?)?.toDouble() ?? 0.00,
      isDisposed: json['is_disposed'] as bool? ?? false,
      disposalDate: json['disposal_date'] != null
          ? DateTime.parse(json['disposal_date'] as String)
          : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'asset_account_id': assetAccountId,
      'asset_name': assetName,
      'category': category,
      'purchase_date': purchaseDate.toIso8601String().split('T').first,
      'original_cost': originalCost,
      'residual_value': residualValue,
      'useful_life_years': usefulLifeYears,
      'is_nesd': isNesd,
      'shift_working': shiftWorking,
      'itc_claimed_flag': itcClaimedFlag,
      'accumulated_depreciation': accumulatedDepreciation,
      'is_disposed': isDisposed,
      if (disposalDate != null)
        'disposal_date': disposalDate!.toIso8601String().split('T').first,
    };
  }

  /// Current Net Carrying / Book Value
  double get currentBookValue => (originalCost - accumulatedDepreciation).clamp(0.00, originalCost);

  /// Schedule II Maximum Allowed 5% Residual Value Cap
  double get maxAllowedResidualValue => originalCost * 0.05;

  /// Shift working multiplier (1.0 for Single, 1.5 for Double, 2.0 for Triple; 1.0 if NESD)
  double get shiftMultiplier {
    if (isNesd) return 1.0;
    switch (shiftWorking) {
      case 'Double':
        return 1.5;
      case 'Triple':
        return 2.0;
      default:
        return 1.0;
    }
  }

  /// Estimated annual SLM depreciation amount
  double get annualDepreciation {
    if (usefulLifeYears <= 0) return 0.00;
    final depreciable = (originalCost - residualValue).clamp(0.00, originalCost);
    return (depreciable / usefulLifeYears) * shiftMultiplier;
  }

  FixedAssetModel copyWith({
    String? id,
    String? businessId,
    String? assetAccountId,
    String? assetAccountName,
    String? assetName,
    String? category,
    DateTime? purchaseDate,
    double? originalCost,
    double? residualValue,
    double? usefulLifeYears,
    bool? isNesd,
    String? shiftWorking,
    bool? itcClaimedFlag,
    double? accumulatedDepreciation,
    bool? isDisposed,
    DateTime? disposalDate,
    DateTime? createdAt,
  }) {
    return FixedAssetModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      assetAccountId: assetAccountId ?? this.assetAccountId,
      assetAccountName: assetAccountName ?? this.assetAccountName,
      assetName: assetName ?? this.assetName,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      originalCost: originalCost ?? this.originalCost,
      residualValue: residualValue ?? this.residualValue,
      usefulLifeYears: usefulLifeYears ?? this.usefulLifeYears,
      isNesd: isNesd ?? this.isNesd,
      shiftWorking: shiftWorking ?? this.shiftWorking,
      itcClaimedFlag: itcClaimedFlag ?? this.itcClaimedFlag,
      accumulatedDepreciation: accumulatedDepreciation ?? this.accumulatedDepreciation,
      isDisposed: isDisposed ?? this.isDisposed,
      disposalDate: disposalDate ?? this.disposalDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
