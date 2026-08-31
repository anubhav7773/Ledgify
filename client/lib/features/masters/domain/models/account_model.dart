/// Account and Ledger domain model for Chart of Accounts (COA) hierarchy.
/// Adheres strictly to docs/04_core_accounting_engine_rules.md and docs/02_database_schema_ddl_and_indexes.md.
class AccountModel {
  final String id;
  final String businessId;
  final String? parentId;
  final String name;
  final String? alias;
  final String groupName;
  final String primaryClassification; // 'Asset', 'Liability', 'Equity', 'Income', 'Expense'
  final bool isSubLedger;
  final double openingBalance;
  final String openingBalanceType; // 'Dr', 'Cr'
  final String? partyGstin;
  final String? partyPan;
  final String? hsnSacCode;
  final int creditPeriodDays;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AccountModel({
    required this.id,
    required this.businessId,
    this.parentId,
    required this.name,
    this.alias,
    required this.groupName,
    required this.primaryClassification,
    this.isSubLedger = false,
    this.openingBalance = 0.00,
    this.openingBalanceType = 'Dr',
    this.partyGstin,
    this.partyPan,
    this.hsnSacCode,
    this.creditPeriodDays = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to parse JSON from Supabase PostgREST
  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String,
      alias: json['alias'] as String?,
      groupName: json['group_name'] as String,
      primaryClassification: json['primary_classification'] as String,
      isSubLedger: json['is_sub_ledger'] as bool? ?? false,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.00,
      openingBalanceType: json['opening_balance_type'] as String? ?? 'Dr',
      partyGstin: json['party_gstin'] as String?,
      partyPan: json['party_pan'] as String?,
      hsnSacCode: json['hsn_sac_code'] as String?,
      creditPeriodDays: (json['credit_period_days'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  /// Converts model to JSON for database insert/update operations
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'parent_id': parentId,
      'name': name,
      'alias': alias,
      'group_name': groupName,
      'primary_classification': primaryClassification,
      'is_sub_ledger': isSubLedger,
      'opening_balance': openingBalance,
      'opening_balance_type': openingBalanceType,
      'party_gstin': partyGstin,
      'party_pan': partyPan,
      'hsn_sac_code': hsnSacCode,
      'credit_period_days': creditPeriodDays,
      'is_active': isActive,
    };
  }

  /// Returns a copy of the model with updated fields
  AccountModel copyWith({
    String? id,
    String? businessId,
    String? parentId,
    String? name,
    String? alias,
    String? groupName,
    String? primaryClassification,
    bool? isSubLedger,
    double? openingBalance,
    String? openingBalanceType,
    String? partyGstin,
    String? partyPan,
    String? hsnSacCode,
    int? creditPeriodDays,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      groupName: groupName ?? this.groupName,
      primaryClassification: primaryClassification ?? this.primaryClassification,
      isSubLedger: isSubLedger ?? this.isSubLedger,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceType: openingBalanceType ?? this.openingBalanceType,
      partyGstin: partyGstin ?? this.partyGstin,
      partyPan: partyPan ?? this.partyPan,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      creditPeriodDays: creditPeriodDays ?? this.creditPeriodDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Accounting helper getters
  String? get gstin => partyGstin;
  bool get isDebtor => groupName == 'Sundry Debtors';
  bool get isCreditor => groupName == 'Sundry Creditors';
  bool get isBankOrCash => groupName == 'Bank Accounts' || groupName == 'Cash-in-Hand';
  String get formattedBalance => '₹${openingBalance.toStringAsFixed(2)} $openingBalanceType';
}
