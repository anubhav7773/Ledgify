import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';

/// Domain service managing Indian Direct Tax evaluations (TDS Section 194Q & TCS Section 206C(1H)) and quarterly exports.
class DirectTaxService {
  final SupabaseClient _client;

  DirectTaxService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Evaluates and auto-deducts TDS under Section 194Q for purchases exceeding ₹50 Lakhs
  Future<double> evaluateTdsForPurchase({
    required String voucherId,
    required String partyAccountId,
    required double purchaseAmount,
  }) async {
    return await executeSafely<double>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'process_section_194q_tds',
        params: {
          'p_business_id': businessId,
          'p_voucher_id': voucherId,
          'p_party_account_id': partyAccountId,
          'p_purchase_amount': purchaseAmount,
        },
      );

      return (response as num?)?.toDouble() ?? 0.00;
    });
  }

  /// Evaluates and auto-collects TCS under Section 206C(1H) for sales receipts exceeding ₹50 Lakhs
  Future<double> evaluateTcsForSale({
    required String voucherId,
    required String partyAccountId,
    required double receiptAmount,
  }) async {
    return await executeSafely<double>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'process_section_206c_tcs',
        params: {
          'p_business_id': businessId,
          'p_voucher_id': voucherId,
          'p_party_account_id': partyAccountId,
          'p_receipt_amount': receiptAmount,
        },
      );

      return (response as num?)?.toDouble() ?? 0.00;
    });
  }

  /// Generates Form 26Q quarterly TDS JSON payload
  Future<Map<String, dynamic>> fetchForm26QExport({
    required String financialYear,
    required String quarter, // 'Q1', 'Q2', 'Q3', 'Q4'
  }) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_form_26q_payload',
        params: {
          'p_business_id': businessId,
          'p_financial_year': financialYear,
          'p_quarter': quarter,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Links government Challan payment details across multiple TDS entries
  Future<void> linkChallanPayment({
    required List<String> entryIds,
    required String challanNumber,
    required DateTime challanDate,
  }) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      await _client.rpc(
        'update_tds_challan_details',
        params: {
          'p_business_id': businessId,
          'p_entry_ids': entryIds,
          'p_challan_number': challanNumber.trim(),
          'p_challan_date': challanDate.toIso8601String().split('T').first,
        },
      );
    });
  }
}
