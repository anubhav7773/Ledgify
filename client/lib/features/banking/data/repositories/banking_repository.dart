import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../domain/models/bank_account_model.dart';
import '../domain/models/bank_statement_entry_model.dart';

/// Repository managing bank account connections, e-statement uploads, and automated BRS procedures.
class BankingRepository {
  final SupabaseClient _client;

  BankingRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Fetches all bank accounts for the current business
  Future<List<BankAccountModel>> fetchBankAccounts() async {
    return await executeSafely<List<BankAccountModel>>(() async {
      final response = await _client
          .from('bank_accounts')
          .select('*, accounts(name)')
          .order('bank_name');

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => BankAccountModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Bulk inserts parsed bank statement lines into bank_statements_brs
  Future<void> importStatementEntries(
    String bankAccountId,
    List<BankStatementEntryModel> entries,
  ) async {
    await executeSafely<void>(() async {
      if (entries.isEmpty) return;

      final rows = entries.map((e) => e.toJson()).toList();
      await _client.from('bank_statements_brs').insert(rows);
    });
  }

  /// Runs the automated Trigram reconciliation engine for a bank account
  Future<List<Map<String, dynamic>>> runAutoReconciliation(String bankAccountId) async {
    return await executeSafely<List<Map<String, dynamic>>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'auto_reconcile_bank_statement',
        params: {
          'p_business_id': businessId,
          'p_bank_account_id': bankAccountId,
        },
      );

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  /// Generates a 1-click double-entry voucher from an un-reconciled statement line
  Future<String> createVoucherFromStatementLine({
    required String statementId,
    required String contraAccountId,
    String voucherType = 'Payment',
  }) async {
    return await executeSafely<String>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final voucherId = await _client.rpc(
        'create_voucher_from_bank_line',
        params: {
          'p_business_id': businessId,
          'p_statement_id': statementId,
          'p_contra_account_id': contraAccountId,
          'p_voucher_type': voucherType,
        },
      );

      return voucherId as String;
    });
  }

  /// Manually links or unlinks a statement line and an accounting voucher
  Future<void> manualReconcile({
    required String statementId,
    required String voucherId,
    String action = 'LINK', // 'LINK' or 'UNLINK'
  }) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      await _client.rpc(
        'manual_reconcile_brs_entry',
        params: {
          'p_business_id': businessId,
          'p_statement_id': statementId,
          'p_voucher_id': voucherId,
          'p_action': action,
        },
      );
    });
  }

  /// Fetches statement entries for a bank account with optional reconciliation filter
  Future<List<BankStatementEntryModel>> fetchStatementEntries(
    String bankAccountId, {
    bool? isReconciled,
  }) async {
    return await executeSafely<List<BankStatementEntryModel>>(() async {
      var query = _client
          .from('bank_statements_brs')
          .select()
          .eq('bank_account_id', bankAccountId);

      if (isReconciled != null) {
        query = query.eq('is_reconciled', isReconciled);
      }

      final response = await query.order('transaction_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => BankStatementEntryModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }
}
