import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../../domain/models/account_model.dart';

/// Repository managing Chart of Accounts, Ledgers, and Master Group operations via FastAPI backend.
class AccountRepository {
  AccountRepository();

  /// Fetches all active accounts via FastAPI backend
  Future<List<AccountModel>> fetchAccounts({
    String? primaryClassification,
    String? groupName,
    bool includeInactive = false,
  }) async {
    return await executeSafely<List<AccountModel>>(() async {
      final queryParams = <String, String>{};
      if (groupName != null) queryParams['group_name'] = groupName;

      final response = await ApiClient.get('/masters/ledgers', queryParams: queryParams);
      final list = response as List<dynamic>;

      return list.map((json) {
        final data = json as Map<String, dynamic>;
        return AccountModel(
          id: data['id'] ?? '',
          businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
          name: data['name'] ?? '',
          groupName: data['parent_group_name'] ?? 'General',
          primaryClassification: _inferClassification(data['parent_group_name'] ?? ''),
          openingBalance: (data['opening_balance'] as num?)?.toDouble() ?? 0.0,
          currentBalance: (data['current_balance'] as num?)?.toDouble() ?? 0.0,
          isDebit: (data['opening_balance_type'] ?? 'Dr') == 'Dr',
          gstin: data['gstin'],
          pan: data['pan'],
          isActive: data['is_active'] == true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
    });
  }

  static String _inferClassification(String groupName) {
    final g = groupName.toLowerCase();
    if (g.contains('debtor') || g.contains('bank') || g.contains('cash') || g.contains('asset') || g.contains('stock')) {
      return 'Asset';
    }
    if (g.contains('creditor') || g.contains('liability') || g.contains('duty') || g.contains('tax') || g.contains('loan')) {
      return 'Liability';
    }
    if (g.contains('capital') || g.contains('reserve')) {
      return 'Equity';
    }
    if (g.contains('sale') || g.contains('income') || g.contains('revenue')) {
      return 'Income';
    }
    return 'Expense';
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

  /// Creates a new ledger account via FastAPI backend
  Future<AccountModel> createAccount(AccountModel account) async {
    return await executeSafely<AccountModel>(() async {
      final payload = {
        'name': account.name,
        'parent_group_name': account.groupName,
        'opening_balance': account.openingBalance,
        'opening_balance_type': account.isDebit ? 'Dr' : 'Cr',
        'gstin': account.gstin,
        'pan': account.pan,
        'is_active': account.isActive,
      };

      final response = await ApiClient.post('/masters/ledgers', body: payload);
      final data = response as Map<String, dynamic>;

      return AccountModel(
        id: data['id'] ?? '',
        businessId: data['business_id'] ?? account.businessId,
        name: data['name'] ?? account.name,
        groupName: data['parent_group_name'] ?? account.groupName,
        primaryClassification: account.primaryClassification,
        openingBalance: (data['opening_balance'] as num?)?.toDouble() ?? account.openingBalance,
        currentBalance: (data['current_balance'] as num?)?.toDouble() ?? account.currentBalance,
        isDebit: (data['opening_balance_type'] ?? 'Dr') == 'Dr',
        gstin: data['gstin'] ?? account.gstin,
        pan: data['pan'] ?? account.pan,
        isActive: data['is_active'] == true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });
  }
}
