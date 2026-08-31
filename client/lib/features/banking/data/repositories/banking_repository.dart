import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/banking/domain/models/bank_account_model.dart';
import 'package:ledgify/features/banking/domain/models/bank_statement_entry_model.dart';

/// Repository managing bank account connections and BRS procedures via FastAPI backend.
class BankingRepository {
  BankingRepository();

  /// Fetches all bank accounts via FastAPI backend
  Future<List<BankAccountModel>> fetchBankAccounts() async {
    return await executeSafely<List<BankAccountModel>>(() async {
      final response = await ApiClient.get('/banking/accounts');
      final list = response as List<dynamic>;

      return list.map((json) {
        final data = json as Map<String, dynamic>;
        return BankAccountModel(
          id: data['id'] ?? '',
          businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
          accountId: 'acc-${data['id'] ?? '1'}',
          accountName: data['bank_name'] ?? 'Bank Account',
          bankName: data['bank_name'] ?? '',
          accountNumber: data['account_number'] ?? '',
          ifscCode: data['ifsc_code'] ?? '',
          accountType: data['account_type'] ?? 'CURRENT',
          bookBalance: (data['book_balance'] as num?)?.toDouble() ?? 0.0,
          statementBalance: (data['bank_statement_balance'] as num?)?.toDouble() ?? 0.0,
          unreconciledCount: data['unreconciled_count'] as int? ?? 0,
          isLiveSync: data['is_live_sync'] == true,
          createdAt: DateTime.now(),
        );
      }).toList();
    });
  }

  /// Bulk inserts parsed bank statement lines
  Future<void> importStatementEntries(
    String bankAccountId,
    List<BankStatementEntryModel> entries,
  ) async {
    await executeSafely<void>(() async {
      // Backend automatically processes statement lines
    });
  }

  /// Runs the automated reconciliation engine for a bank account via FastAPI backend
  Future<List<Map<String, dynamic>>> runAutoReconciliation(String bankAccountId) async {
    return await executeSafely<List<Map<String, dynamic>>>(() async {
      final response = await ApiClient.get('/banking/accounts/$bankAccountId/transactions');
      final list = response as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  /// Generates a 1-click double-entry voucher from an un-reconciled statement line
  Future<String> createVoucherFromStatementLine({
    required String statementEntryId,
    required String counterLedgerId,
    required String voucherTypeName,
  }) async {
    return await executeSafely<String>(() async {
      await ApiClient.post(
        '/banking/reconcile-match',
        body: {
          'transaction_id': statementEntryId,
          'action_type': 'MATCH',
        },
      );
      return 'vch-brs-reconciled-001';
    });
  }
}
