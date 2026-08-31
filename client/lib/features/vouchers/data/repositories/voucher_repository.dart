import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/masters/domain/models/voucher_type_model.dart';
import '../../domain/models/voucher_model.dart';

/// Repository managing Double-Entry Voucher operations and atomic transaction commits.
/// Interacts with Supabase PostgreSQL and handles zero-sum double-entry constraint violations.
class VoucherRepository {
  final SupabaseClient _client;

  VoucherRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Creates a double-entry balanced voucher atomically via database stored procedure.
  /// Throws [AccountingInvariantFailure] if \sum Debits != \sum Credits.
  Future<Map<String, dynamic>> createVoucher(VoucherModel voucher) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      if (!voucher.isBalanced) {
        throw AccountingInvariantFailure(
          message: 'Voucher is not balanced! Total Debits (₹${voucher.totalDebitAmount.toStringAsFixed(2)}) '
              'must equal Total Credits (₹${voucher.totalCreditAmount.toStringAsFixed(2)}). '
              'Difference: ₹${voucher.differenceAmount.toStringAsFixed(2)}',
        );
      }

      try {
        final payload = voucher.toJson();
        final response = await _client.rpc(
          'post_double_entry_voucher',
          params: {'p_voucher_payload': payload},
        );

        return Map<String, dynamic>.from(response as Map);
      } on PostgrestException catch (e, stackTrace) {
        if (e.code == '23514' || e.message.contains('Double-entry balancing violation')) {
          throw AccountingInvariantFailure(
            message: 'Database double-entry check failed: ${e.message}',
          );
        }
        throw ServerFailure(
          message: e.message,
          code: e.code,
          stackTrace: stackTrace,
        );
      }
    });
  }

  /// Fetches paginated vouchers with associated line items and voucher type names
  Future<List<VoucherModel>> fetchVouchers({
    DateTime? startDate,
    DateTime? endDate,
    String? voucherTypeId,
    int limit = 50,
    int offset = 0,
  }) async {
    return await executeSafely<List<VoucherModel>>(() async {
      var query = _client.from('vouchers').select('''
        id,
        business_id,
        voucher_type_id,
        voucher_number,
        original_voucher_number,
        voucher_date,
        narration,
        reference_number,
        reference_date,
        is_cancelled,
        ai_confidence_score,
        irn,
        qr_code,
        ack_no,
        ack_date,
        e_way_bill_no,
        created_at,
        updated_at,
        voucher_types(name),
        voucher_line_items(
          id,
          business_id,
          voucher_id,
          account_id,
          entry_type,
          amount,
          item_description,
          cgst_amt,
          sgst_amt,
          igst_amt,
          cess_amt,
          accounts(name)
        )
      ''');

      if (startDate != null) {
        query = query.gte('voucher_date', startDate.toIso8601String().split('T').first);
      }
      if (endDate != null) {
        query = query.lte('voucher_date', endDate.toIso8601String().split('T').first);
      }
      if (voucherTypeId != null) {
        query = query.eq('voucher_type_id', voucherTypeId);
      }

      final response = await query
          .order('voucher_date', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => VoucherModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Fetches a single voucher by UUID with complete line items
  Future<VoucherModel> fetchVoucherById(String voucherId) async {
    return await executeSafely<VoucherModel>(() async {
      final response = await _client.from('vouchers').select('''
        id,
        business_id,
        voucher_type_id,
        voucher_number,
        original_voucher_number,
        voucher_date,
        narration,
        reference_number,
        reference_date,
        is_cancelled,
        ai_confidence_score,
        irn,
        qr_code,
        ack_no,
        ack_date,
        e_way_bill_no,
        created_at,
        updated_at,
        voucher_types(name),
        voucher_line_items(
          id,
          business_id,
          voucher_id,
          account_id,
          entry_type,
          amount,
          item_description,
          cgst_amt,
          sgst_amt,
          igst_amt,
          cess_amt,
          accounts(name)
        )
      ''').eq('id', voucherId).single();

      return VoucherModel.fromJson(response as Map<String, dynamic>);
    });
  }

  /// Fetches available voucher types (system default + custom)
  Future<List<VoucherTypeModel>> fetchVoucherTypes() async {
    return await executeSafely<List<VoucherTypeModel>>(() async {
      final response = await _client
          .from('voucher_types')
          .select()
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => VoucherTypeModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Soft-cancels a voucher to preserve audit compliance
  Future<void> cancelVoucher(String voucherId, String reason) async {
    await executeSafely<void>(() async {
      await _client.from('vouchers').update({
        'is_cancelled': true,
        'narration': 'CANCELLED: $reason',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', voucherId);
    });
  }
}
