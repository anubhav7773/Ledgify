/// Domain representation of complete tenant data exported under DPDP portability provisions.
class DataPortabilityPackage {
  final String exportStandard;
  final Map<String, dynamic> tenantMetadata;
  final List<dynamic> chartOfAccounts;
  final List<dynamic> vouchersLedger;
  final List<dynamic> inventoryCatalog;
  final List<dynamic> gstAndTaxHistory;
  final List<dynamic> consentAuditTrail;

  const DataPortabilityPackage({
    this.exportStandard = 'INDIA_DPDP_2023_V1',
    required this.tenantMetadata,
    required this.chartOfAccounts,
    required this.vouchersLedger,
    required this.inventoryCatalog,
    required this.gstAndTaxHistory,
    required this.consentAuditTrail,
  });

  factory DataPortabilityPackage.fromJson(Map<String, dynamic> json) {
    return DataPortabilityPackage(
      exportStandard: json['dpdp_export_standard'] as String? ?? 'INDIA_DPDP_2023_V1',
      tenantMetadata: json['tenant_metadata'] as Map<String, dynamic>? ?? {},
      chartOfAccounts: json['chart_of_accounts'] as List<dynamic>? ?? [],
      vouchersLedger: json['vouchers_ledger'] as List<dynamic>? ?? [],
      inventoryCatalog: json['inventory_catalog'] as List<dynamic>? ?? [],
      gstAndTaxHistory: json['gst_and_tax_history'] as List<dynamic>? ?? [],
      consentAuditTrail: json['consent_audit_trail'] as List<dynamic>? ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dpdp_export_standard': exportStandard,
      'tenant_metadata': tenantMetadata,
      'chart_of_accounts': chartOfAccounts,
      'vouchers_ledger': vouchersLedger,
      'inventory_catalog': inventoryCatalog,
      'gst_and_tax_history': gstAndTaxHistory,
      'consent_audit_trail': consentAuditTrail,
    };
  }

  int get totalVouchers => vouchersLedger.length;
  int get totalAccounts => chartOfAccounts.length;
  int get totalStockItems => inventoryCatalog.length;
}
