import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../domain/models/tds_tcs_entry_model.dart';
import '../domain/services/direct_tax_service.dart';

/// Repository managing TDS/TCS ledger records via FastAPI backend.
class DirectTaxRepository {
  final DirectTaxService _taxService;

  DirectTaxRepository({DirectTaxService? taxService})
      : _taxService = taxService ?? DirectTaxService();

  /// Fetches pending TDS/TCS deductions from FastAPI backend
  Future<List<TdsTcsEntryModel>> fetchPendingTdsEntries({
    String? sectionCode,
    String? formType,
  }) async {
    return await executeSafely<List<TdsTcsEntryModel>>(() async {
      final queryParams = <String, String>{};
      if (sectionCode != null && sectionCode.isNotEmpty) {
        queryParams['section'] = sectionCode;
      }

      final response = await ApiClient.get('/direct-tax/tds-register', queryParams: queryParams);
      final list = response as List<dynamic>;

      return list.map((json) {
        final data = json as Map<String, dynamic>;
        return TdsTcsEntryModel(
          id: data['id'] ?? '',
          businessId: 'BIZ-DEFAULT-01',
          voucherId: data['voucher_number'] ?? '',
          partyName: data['party_name'] ?? '',
          partyPan: data['party_pan'] ?? '',
          sectionCode: data['section_code'] ?? '194Q',
          natureOfPayment: data['section_description'] ?? 'TDS Payment',
          taxableAmount: (data['gross_amount'] as num?)?.toDouble() ?? 0.0,
          rate: (data['rate_percent'] as num?)?.toDouble() ?? 0.1,
          tdsAmount: (data['tax_deducted'] as num?)?.toDouble() ?? 0.0,
          isTcs: (data['section_code'] ?? '').contains('206'),
          challanNumber: data['challan_bsr_code'],
          challanDate: data['deposit_status'] == 'DEPOSITED' ? DateTime.now() : null,
          createdAt: DateTime.tryParse(data['transaction_date'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    });
  }

  /// Fetches historical deposited TDS/TCS entries
  Future<List<TdsTcsEntryModel>> fetchTdsHistory({
    String? formType,
  }) async {
    return fetchPendingTdsEntries(formType: formType);
  }
}
