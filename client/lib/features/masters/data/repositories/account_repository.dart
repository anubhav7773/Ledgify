import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../../domain/models/account_model.dart';

/// Repository managing Chart of Accounts, Ledgers, and Master Group operations.
/// Interacts directly with Supabase PostgreSQL under zero-trust RLS isolation.
class AccountRepository {
  final SupabaseClient _client;

  AccountRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Fetches all active accounts, optionally filtered by classification or group name
  Future<List<AccountModel>> fetchAccounts({
    String? primaryClassification,
    String? groupName,
    bool includeInactive = false,
  }) async {
    return await executeSafely<List<AccountModel>>(() async {
      var query = _client.from('accounts').select();

      if (!includeInactive) {
        query = query.eq('is_active', true);
      }
      if (primaryClassification != null) {
        query = query.eq('primary_classification', primaryClassification);
      }
      if (groupName != null) {
        query = query.eq('group_name', groupName);
      }

      final response = await query.order('name', ascending: true);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => AccountModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Fetches accounts organized hierarchically by Primary Classification -> Group -> Ledgers
  Future<Map<String, Map<String, List<AccountModel>>>> fetchGroupHierarchy() async {
    return await executeSafely<Map<String, Map<String, List<AccountModel>>>>(() async {
      final accounts = await fetchAccounts();
      final Map<String, Map<String, List<AccountModel>>> hierarchy = {
        'Asset': {},
        'Liability': {},
        'Equity': {},
        'Income': {},
        'Expense': {},
      };

      for (final account in accounts) {
        final classification = account.primaryClassification;
        final group = account.groupName;

        if (!hierarchy.containsKey(classification)) {
          hierarchy[classification] = {};
        }
        if (!hierarchy[classification]!.containsKey(group)) {
          hierarchy[classification]![group] = [];
        }
        hierarchy[classification]![group]!.add(account);
      }

      return hierarchy;
    });
  }

  /// Creates a new ledger or sub-ledger under a parent group
  Future<AccountModel> createLedger(AccountModel account) async {
    return await executeSafely<AccountModel>(() async {
      final insertData = account.toJson();
      // Remove empty id to let PostgreSQL generate a fresh UUID if not provided
      if (account.id.isEmpty) {
        insertData.remove('id');
      }

      final response = await _client
          .from('accounts')
          .insert(insertData)
          .select()
          .single();

      return AccountModel.fromJson(response as Map<String, dynamic>);
    });
  }

  /// Updates an existing ledger's details and opening balance
  Future<AccountModel> updateLedger(AccountModel account) async {
    return await executeSafely<AccountModel>(() async {
      final updateData = account.toJson();
      updateData.remove('id');
      updateData.remove('business_id');

      final response = await _client
          .from('accounts')
          .update(updateData)
          .eq('id', account.id)
          .select()
          .single();

      return AccountModel.fromJson(response as Map<String, dynamic>);
    });
  }

  /// Deactivates a ledger (soft-delete to preserve statutory audit history)
  Future<void> deactivateLedger(String accountId) async {
    await executeSafely<void>(() async {
      await _client
          .from('accounts')
          .update({'is_active': false})
          .eq('id', accountId);
    });
  }
}
