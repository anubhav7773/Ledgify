import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/dpdp_consent_log_model.dart';
import '../models/dpdp_failures.dart';
import '../models/dpdp_purpose.dart';
import '../../presentation/dialogs/dpdp_consent_modal_dialog.dart';

/// Service managing DPDP Act 2023 consent state checks, cryptographic logging, and runtime gating.
class DpdpConsentService {
  final SupabaseClient _client;

  DpdpConsentService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Checks if active consent exists for the specified purpose
  Future<bool> checkConsent(DpdpPurpose purpose, {String? businessId}) async {
    return await executeSafely<bool>(() async {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final response = await _client.rpc(
        'has_active_dpdp_consent',
        params: {
          'p_business_id': businessId ?? '00000000-0000-0000-0000-000000000000',
          'p_user_id': user.id,
          'p_purpose': purpose.code,
        },
      );

      return response as bool? ?? false;
    });
  }

  /// Records a new statutory consent grant with cryptographic payload hash
  Future<void> grantConsent(DpdpPurpose purpose, {String? businessId}) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be logged in to grant consent');

      await _client.rpc(
        'record_dpdp_consent',
        params: {
          'p_business_id': businessId ?? '00000000-0000-0000-0000-000000000000',
          'p_user_id': user.id,
          'p_purpose': purpose.code,
          'p_status': 'GRANTED',
          'p_version': 'v1.0',
          'p_payload_hash': purpose.statutoryNoticeHash,
          'p_ip': '127.0.0.1', // Client loopback/device placeholder
          'p_user_agent': 'Ledgify-Flutter-App/1.0.0',
        },
      );
    });
  }

  /// Revokes an active consent grant
  Future<void> revokeConsent(DpdpPurpose purpose, {String? businessId}) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be logged in to revoke consent');

      await _client.rpc(
        'record_dpdp_consent',
        params: {
          'p_business_id': businessId ?? '00000000-0000-0000-0000-000000000000',
          'p_user_id': user.id,
          'p_purpose': purpose.code,
          'p_status': 'REVOKED',
          'p_version': 'v1.0',
          'p_payload_hash': purpose.statutoryNoticeHash,
          'p_ip': '127.0.0.1',
          'p_user_agent': 'Ledgify-Flutter-App/1.0.0',
        },
      );
    });
  }

  /// Fetches unalterable historical consent audit logs
  Future<List<DpdpConsentLogModel>> fetchConsentAuditHistory() async {
    return await executeSafely<List<DpdpConsentLogModel>>(() async {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('dpdp_consent_logs')
          .select()
          .eq('user_id', user.id)
          .order('granted_at', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map((item) => DpdpConsentLogModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    });
  }

  /// Interceptor helper: Executes action if consent exists; otherwise prompts the user
  Future<T> runWithConsent<T>({
    required DpdpPurpose purpose,
    required BuildContext context,
    required Future<T> Function() onConsentGranted,
  }) async {
    final hasConsent = await checkConsent(purpose);

    if (hasConsent) {
      return await onConsentGranted();
    }

    if (!context.mounted) {
      throw DpdpConsentRequiredFailure(purpose: purpose);
    }

    final bool? consented = await DpdpConsentModalDialog.show(context, purpose: purpose);

    if (consented == true) {
      await grantConsent(purpose);
      return await onConsentGranted();
    } else {
      throw DpdpConsentRequiredFailure(purpose: purpose);
    }
  }
}
