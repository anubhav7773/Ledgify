import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../domain/models/tds_tcs_entry_model.dart';
import '../domain/services/direct_tax_service.dart';

/// Repository managing TDS/TCS ledger records, Challan payment links, and return exports.
class DirectTaxRepository {
  final SupabaseClient _client;
  final DirectTaxService _taxService;

  DirectTaxRepository({
    SupabaseClient? client,
    DirectTaxService? taxService,
  })  : _client = client ?? SupabaseClientService.client,
        _taxService = taxService ?? DirectTaxService();

  /// Fetches pending TDS/TCS deductions awaiting government deposit
  Future<List<TdsTcsEntryModel>> fetchPendingTdsEntries({
    String? sectionCode,
    String? formType,
  }) async {
    return await executeSafely<List<TdsTcsEntryModel>>(() async {
      var query = _client
          .from('tds_tcs_entries')
          .select()
          .isFilter('challan_number', null);

      if (sectionCode != null && sectionCode.isNotEmpty) {
        query = query.eq('section_code', sectionCode);
      }
      if (formType != null && formType.isNotEmpty) {
        query = query.eq('form_type', formType);
      }

      final response = await query.order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => TdsTcsEntryModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Fetches historical deposited TDS/TCS entries
  Future<List<TdsTcsEntryModel>> fetchTdsHistory({
    String? formType,
  }) async {
    return await executeSafely<List<TdsTcsEntryModel>>(() async {
      var query = _client
          .from('tds_tcs_entries')
          .select()
          .not('challan_number', 'is', null);

      if (formType != null && formType.isNotEmpty) {
        query = query.eq('form_type', formType);
      }

      final response = await query.order('challan_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => TdsTcsEntryModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Links Challan number and date to a list of entry IDs
  Future<void> linkChallanPayment({
    required List<String> entryIds,
    required String challanNumber,
    required DateTime challanDate,
  }) async {
    await _taxService.linkChallanPayment(
      entryIds: entryIds,
      challanNumber: challanNumber,
      challanDate: challanDate,
    );
  }

  /// Exports quarterly Form 26Q payload
  Future<Map<String, dynamic>> exportQuarterlyReturn({
    required String financialYear,
    required String quarter,
  }) async {
    return await _taxService.fetchForm26QExport(
      financialYear: financialYear,
      quarter: quarter,
    );
  }
}
