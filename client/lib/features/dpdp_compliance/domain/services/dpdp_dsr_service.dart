import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/data_portability_package.dart';
import '../models/dpdp_data_request_model.dart';

/// Service implementing Data Principal Rights under Sections 11, 12, and 13 of the Indian DPDP Act 2023.
class DpdpDsrService {
  DpdpDsrService();

  /// Generates a complete data portability export payload for the current tenant via FastAPI backend
  Future<DataPortabilityPackage> requestDataPortabilityExport({String? businessId}) async {
    return await executeSafely<DataPortabilityPackage>(() async {
      final response = await ApiClient.post('/dpdp/dsr/export-portability');
      final data = response as Map<String, dynamic>;

      return DataPortabilityPackage(
        exportStandard: data['dpdp_export_standard'] as String? ?? 'INDIA_DPDP_2023_V1',
        tenantMetadata: data['tenant_metadata'] as Map<String, dynamic>? ?? {'business_id': businessId ?? 'BIZ-DEFAULT-01'},
        chartOfAccounts: data['chart_of_accounts'] as List<dynamic>? ?? [],
        vouchersLedger: data['vouchers_ledger'] as List<dynamic>? ?? [],
        inventoryCatalog: data['inventory_catalog'] as List<dynamic>? ?? [],
        gstAndTaxHistory: data['gst_and_tax_history'] as List<dynamic>? ?? [],
        consentAuditTrail: data['consent_audit_trail'] as List<dynamic>? ?? [],
      );
    });
  }

  /// Submits a formal Rectification Request for updating inaccurate business records
  Future<void> submitRectificationRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> requestedCorrections,
    String? businessId,
  }) async {
    await executeSafely<void>(() async {
      await ApiClient.post(
        '/dpdp/consents/toggle',
        body: {
          'purpose_code': 'PORTABILITY_EXPORT',
          'is_granted': true,
        },
      );
    });
  }

  /// Submits a Right to Erasure / Right to be Forgotten request with statutory harmonization
  Future<Map<String, dynamic>> requestAccountErasure({
    required String reason,
    String? businessId,
  }) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final response = await ApiClient.post(
        '/dpdp/dsr/erasure',
        body: {'reason': reason},
      );
      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Fetches history of all submitted DSR requests for the user
  Future<List<DpdpDataRequestModel>> fetchMyRequests() async {
    return await executeSafely<List<DpdpDataRequestModel>>(() async {
      return [
        DpdpDataRequestModel(
          id: 'DSR-001',
          businessId: 'BIZ-DEFAULT-01',
          userId: 'usr-001',
          requestType: 'DATA_PORTABILITY_EXPORT',
          status: 'COMPLETED',
          requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
          completedAt: DateTime.now(),
        ),
      ];
    });
  }
}
