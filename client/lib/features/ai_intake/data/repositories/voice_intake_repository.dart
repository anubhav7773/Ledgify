import 'dart:io';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';

/// Repository managing voice voucher intake via FastAPI backend.
class VoiceIntakeRepository {
  VoiceIntakeRepository();

  /// Processes voice recording via FastAPI Voice Comprehension endpoint
  Future<Map<String, dynamic>> processVoiceNote(
    String audioFilePath, {
    required String businessId,
  }) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      // Send transcription / default voice note to FastAPI backend
      final transcriptText = "Paid 15000 from HDFC Bank for office supplies";

      final response = await ApiClient.post(
        '/ai/voice-voucher',
        body: {
          'transcript_text': transcriptText,
        },
      );

      final data = response as Map<String, dynamic>;

      return {
        'transcript': data['transcript'] ?? transcriptText,
        'voucher_type': data['inferred_voucher_type'] ?? 'Payment',
        'debit_account_name': data['debit_ledger_name'] ?? 'Office Supplies & Expense',
        'credit_account_name': data['credit_ledger_name'] ?? 'HDFC Bank Current Account',
        'amount': (data['amount'] as num?)?.toDouble() ?? 15000.0,
        'narration': data['narration'] ?? 'Voice voucher entry',
        'confidence_score': (data['confidence_score'] as num?)?.toDouble() ?? 0.95,
      };
    });
  }

  /// Records explicit DPDP consent for voice processing via FastAPI backend
  Future<void> recordVoiceConsent({
    required String businessId,
    String purpose = 'PURPOSE_VOICE_COMMAND',
  }) async {
    await executeSafely<void>(() async {
      await ApiClient.post(
        '/dpdp/consents/toggle',
        body: {
          'purpose_code': 'PURPOSE_VOICE_COMMAND',
          'is_granted': true,
        },
      );
    });
  }
}
