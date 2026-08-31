import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/fuzzy_match_result.dart';

/// Model representing an active learning cache entry
class DisambiguationCacheItem {
  final String id;
  final String businessId;
  final String rawQueryText;
  final String entityType;
  final String resolvedEntityId;
  final int hitCount;
  final DateTime lastUsedAt;

  const DisambiguationCacheItem({
    required this.id,
    required this.businessId,
    required this.rawQueryText,
    required this.entityType,
    required this.resolvedEntityId,
    required this.hitCount,
    required this.lastUsedAt,
  });

  factory DisambiguationCacheItem.fromJson(Map<String, dynamic> json) {
    return DisambiguationCacheItem(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      rawQueryText: json['raw_query_text'] as String,
      entityType: json['entity_type'] as String,
      resolvedEntityId: json['resolved_entity_id'] as String,
      hitCount: json['hit_count'] as int? ?? 1,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Service managing Active Learning feedback, phonetic alias expansions, and disambiguation cache.
class ActiveLearningService {
  final SupabaseClient _client;

  ActiveLearningService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Records user-confirmed mapping to train future lookups and expand phonetic aliases
  Future<void> submitResolutionFeedback({
    required String rawQueryText,
    required String entityType, // 'ACCOUNT' or 'STOCK_ITEM'
    required String resolvedEntityId,
  }) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      await _client.rpc(
        'record_entity_resolution_feedback',
        params: {
          'p_business_id': businessId,
          'p_raw_query_text': rawQueryText.trim(),
          'p_entity_type': entityType,
          'p_resolved_entity_id': resolvedEntityId,
        },
      );
    });
  }

  /// High-speed cache-first search falling back to two-stage hybrid resolution
  Future<List<FuzzyMatchResult>> resolveWithCache({
    required String queryText,
    String entityType = 'ACCOUNT',
    int maxCandidates = 5,
  }) async {
    return await executeSafely<List<FuzzyMatchResult>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'match_entity_with_cache',
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

  /// Retrieves all learned disambiguation mappings for this business
  Future<List<DisambiguationCacheItem>> fetchLearnedAliases() async {
    return await executeSafely<List<DisambiguationCacheItem>>(() async {
      final response = await _client
          .from('entity_disambiguation_cache')
          .select()
          .order('hit_count', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => DisambiguationCacheItem.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Removes an obsolete or incorrect learned mapping
  Future<void> deleteLearnedAlias(String cacheId) async {
    await executeSafely<void>(() async {
      await _client.from('entity_disambiguation_cache').delete().eq('id', cacheId);
    });
  }
}
