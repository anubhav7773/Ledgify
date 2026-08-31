import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/fuzzy_match_result.dart';

/// Service executing in-database Two-Stage Hybrid Entity Resolution (Trigram + Levenshtein + Daitch-Mokotoff).
class FuzzyMatchingService {
  final SupabaseClient _client;

  FuzzyMatchingService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Executes two-stage hybrid disambiguation across Accounts or Stock Items
  Future<List<FuzzyMatchResult>> resolveEntity({
    required String queryText,
    String entityType = 'ACCOUNT', // 'ACCOUNT' or 'STOCK_ITEM'
    int maxCandidates = 5,
  }) async {
    return await executeSafely<List<FuzzyMatchResult>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'match_entity_hybrid',
        params: {
          'p_business_id': businessId,
          'p_query_text': queryText.trim(),
          'p_entity_type': entityType,
          'p_max_candidates': maxCandidates,
        },
      );

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => FuzzyMatchResult.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Dispatches dedicated party disambiguation with 15-char GSTIN deterministic priority
  Future<List<FuzzyMatchResult>> resolveLedgerParty({
    required String searchName,
    String? partyGstin,
    String? partyPan,
  }) async {
    return await executeSafely<List<FuzzyMatchResult>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'match_ledger_party',
        params: {
          'p_business_id': businessId,
          'p_search_name': searchName.trim(),
          'p_party_gstin': partyGstin?.trim(),
          'p_party_pan': partyPan?.trim(),
        },
      );

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => FuzzyMatchResult.fromJson(json as Map<String, dynamic>)).toList();
    });
  }
}
