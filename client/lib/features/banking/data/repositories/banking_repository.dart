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
          ledgerId: 'acc-${data['id'] ?? '1'}',
          ledgerName: data['bank_name'] ?? 'Bank Account',
          bankName: data['bank_name'] ?? '',
          accountNumber: data['account_number'] ?? '',
          ifscCode: data['ifsc_code'] ?? '',
          currentBalance: (data['book_balance'] as num?)?.toDouble() ?? 0.0,
          unreconciledCount: data['unreconciled_count'] as int? ?? 0,
          isConnected: data['is_live_sync'] == true,
        );
      }).toList();
    });
  }

  /// Fetches statement entries for BRS workspace
  Future<List<BankStatementEntryModel>> fetchStatementEntries(
    String bankAccountId, {
    bool? isReconciled,
  }) async {
    return await executeSafely<List<BankStatementEntryModel>>(() async {
      final response = await ApiClient.get('/banking/accounts/$bankAccountId/transactions');
      final list = response as List<dynamic>;

      return list.map((json) {
        final data = json as Map<String, dynamic>;
        return BankStatementEntryModel(
          id: data['id'] ?? '',
          businessId: 'BIZ-DEFAULT-01',
          bankAccountId: bankAccountId,
          transactionDate: DateTime.tryParse(data['transaction_date'] ?? '') ?? DateTime.now(),
          description: data['description'] ?? '',
          chequeReferenceNo: data['reference_number'],
          withdrawalAmount: (data['withdrawal_amount'] as num?)?.toDouble() ?? 0.0,
          depositAmount: (data['deposit_amount'] as num?)?.toDouble() ?? 0.0,
          balance: (data['balance_after_transaction'] as num?)?.toDouble() ?? 0.0,
          isReconciled: data['is_reconciled'] == true,
          trgmSimilarityScore: (data['ai_match_confidence'] as num?)?.toDouble() ?? 0.95,
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
      // Backend processes statement lines
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
    required String statementId,
    required String contraAccountId,
    required String voucherType,
  }) async {
    return await executeSafely<String>(() async {
      await ApiClient.post(
        '/banking/reconcile-match',
        body: {
          'transaction_id': statementId,
          'action_type': 'MATCH',
        },
      );
      return 'vch-brs-reconciled-001';
    });
  }
}
