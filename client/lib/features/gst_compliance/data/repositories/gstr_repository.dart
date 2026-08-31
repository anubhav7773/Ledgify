import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/gst_compliance/domain/models/ims_entry_model.dart';

/// Repository managing GSTR-1, GSTR-3B return payload generation and IMS reconciliation records.
class GstrRepository {
  final SupabaseClient _client;

  GstrRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Invokes database procedure to generate GSTR-1 outward supply JSON payload
  Future<Map<String, dynamic>> fetchGstr1Report(String returnPeriod) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'aggregate_gstr1_payload',
        params: {
          'p_business_id': businessId,
          'p_return_period': returnPeriod,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Invokes database procedure to aggregate GSTR-3B Table 3.1 & Table 4 summaries
  Future<Map<String, dynamic>> fetchGstr3bReport(String returnPeriod) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'aggregate_gstr3b_summary',
        params: {
          'p_business_id': businessId,
          'p_return_period': returnPeriod,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Fetches IMS inward supplier invoices queue
  Future<List<ImsEntryModel>> fetchImsInwardSupplies(
    String returnPeriod, {
    String? filterStatus,
  }) async {
    return await executeSafely<List<ImsEntryModel>>(() async {
      var query = _client
          .from('gstr_returns_ims')
          .select()
          .eq('return_type', 'IMS')
          .eq('return_period', returnPeriod);

      if (filterStatus != null && filterStatus.isNotEmpty) {
        query = query.eq('ims_status', filterStatus);
      }

      final response = await query.order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => ImsEntryModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Submits tri-state decision on an inward invoice in IMS
  Future<void> updateImsStatus(
    String imsId,
    String status,
    String? remarks,
  ) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      await _client.rpc(
        'process_ims_action',
        params: {
          'p_business_id': businessId,
          'p_ims_entry_id': imsId,
          'p_action': status,
          'p_remarks': remarks,
        },
      );
    });
  }
}
