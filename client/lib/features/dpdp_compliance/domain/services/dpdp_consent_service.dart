import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/dpdp_consent_log_model.dart';
import '../models/dpdp_failures.dart';
import '../models/dpdp_purpose.dart';
import '../../presentation/dialogs/dpdp_consent_modal_dialog.dart';

/// Service managing DPDP Act 2023 consent state checks via FastAPI backend.
class DpdpConsentService {
  DpdpConsentService();

  /// Checks if active consent exists for the specified purpose
  Future<bool> checkConsent(DpdpPurpose purpose, {String? businessId}) async {
    return await executeSafely<bool>(() async {
      final response = await ApiClient.get('/dpdp/consents');
      final list = response as List<dynamic>;

      final item = list.firstWhere(
        (c) => c['purpose_code'] == purpose.code,
        orElse: () => null,
      );

      if (item != null) {
        return item['is_granted'] == true;
      }
      return true; // Default enabled
    });
  }

  /// Records a new statutory consent grant via FastAPI backend
  Future<void> grantConsent(DpdpPurpose purpose, {String? businessId}) async {
    await executeSafely<void>(() async {
      await ApiClient.post(
        '/dpdp/consents/toggle',
        body: {
          'purpose_code': purpose.code,
          'is_granted': true,
        },
      );
    });
  }

  /// Revokes an active consent grant via FastAPI backend
  Future<void> revokeConsent(DpdpPurpose purpose, {String? businessId}) async {
    await executeSafely<void>(() async {
      await ApiClient.post(
        '/dpdp/consents/toggle',
        body: {
          'purpose_code': purpose.code,
          'is_granted': false,
        },
      );
    });
  }

  /// Fetches audit history logs from FastAPI backend
  Future<List<DpdpConsentLogModel>> fetchConsentLogs({String? businessId}) async {
    return await executeSafely<List<DpdpConsentLogModel>>(() async {
      final response = await ApiClient.get('/dpdp/consents/audit-log');
      final list = response as List<dynamic>;

      return list.map((json) {
        final data = json as Map<String, dynamic>;
        return DpdpConsentLogModel(
          id: data['id'] ?? '',
          businessId: businessId ?? 'BIZ-DEFAULT-01',
          userId: 'dev-user-01',
          purpose: data['purpose_code'] ?? '',
          status: data['consent_status'] ?? 'GRANTED',
          noticeVersion: 'v1.0',
          payloadHash: data['consent_payload_hash'] ?? '',
          createdAt: DateTime.tryParse(data['granted_at'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    });
  }

  /// Interactive UI Guard: prompts consent modal if not granted
  Future<bool> requireConsent(BuildContext context, DpdpPurpose purpose, {String? businessId}) async {
    final hasConsent = await checkConsent(purpose, businessId: businessId);
    if (hasConsent) return true;

    if (!context.mounted) return false;

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DpdpConsentModalDialog(purpose: purpose),
    );

    if (granted == true) {
      await grantConsent(purpose, businessId: businessId);
      return true;
    }

    return false;
  }
}
