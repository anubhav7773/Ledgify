import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/data_portability_package.dart';
import '../models/dpdp_data_request_model.dart';

/// Service implementing Data Principal Rights under Sections 11, 12, and 13 of the Indian DPDP Act 2023.
class DpdpDsrService {
  final SupabaseClient _client;

  DpdpDsrService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Generates a complete data portability export payload for the current tenant
  Future<DataPortabilityPackage> requestDataPortabilityExport({String? businessId}) async {
    return await executeSafely<DataPortabilityPackage>(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final response = await _client.rpc(
        'generate_dpdp_portability_archive',
        params: {
          'p_business_id': businessId ?? '00000000-0000-0000-0000-000000000000',
          'p_user_id': user.id,
        },
      );

      return DataPortabilityPackage.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Submits a formal Rectification Request for updating inaccurate business records
  Future<void> submitRectificationRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> requestedCorrections,
    String? businessId,
  }) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      await _client.from('dpdp_data_requests').insert({
        'business_id': businessId ?? '00000000-0000-0000-0000-000000000000',
        'user_id': user.id,
        'request_type': 'RECTIFICATION',
        'status': 'PENDING',
        'request_details': {
          'entity_type': entityType,
          'entity_id': entityId,
          'corrections': requestedCorrections,
        },
      });
    });
  }

  /// Submits a Right to Erasure / Right to be Forgotten request with statutory harmonization
  Future<Map<String, dynamic>> requestAccountErasure({
    required String reason,
    String? businessId,
  }) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final response = await _client.rpc(
        'process_dpdp_erasure_request',
        params: {
          'p_business_id': businessId ?? '00000000-0000-0000-0000-000000000000',
          'p_user_id': user.id,
          'p_reason': reason,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Fetches history of all submitted DSR requests for the user
  Future<List<DpdpDataRequestModel>> fetchMyRequests() async {
    return await executeSafely<List<DpdpDataRequestModel>>(() async {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('dpdp_data_requests')
          .select()
          .eq('user_id', user.id)
          .order('requested_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => DpdpDataRequestModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    });
  }
}
