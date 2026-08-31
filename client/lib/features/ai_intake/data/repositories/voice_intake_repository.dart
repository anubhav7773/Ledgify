import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/ai_intake/data/services/gemini_voice_service.dart';

/// Repository managing voice voucher intake under DPDP consent checks.
class VoiceIntakeRepository {
  final SupabaseClient _client;
  final GeminiVoiceService _voiceService;

  VoiceIntakeRepository({
    SupabaseClient? client,
    GeminiVoiceService? voiceService,
  })  : _client = client ?? SupabaseClientService.client,
        _voiceService = voiceService ?? GeminiVoiceService();

  /// Processes voice recording via Gemini Multimodal Voice API if DPDP consent is active
  Future<Map<String, dynamic>> processVoiceNote(
    String audioFilePath, {
    required String businessId,
  }) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      // 1. Check DPDP Statutory Consent for Voice Processing
      final consentResponse = await _client
          .from('dpdp_consent_logs')
          .select()
          .eq('business_id', businessId)
          .eq('purpose', 'VOICE_VOUCHER_PROCESSING')
          .eq('consent_given', true)
          .isFilter('withdrawn_at', null)
          .limit(1);

      final List<dynamic> consentData = consentResponse as List<dynamic>;
      if (consentData.isEmpty) {
        throw const DpdpConsentRequiredFailure(
          message: 'DPDP statutory consent required for processing vernacular voice recordings.',
          purpose: 'VOICE_VOUCHER_PROCESSING',
        );
      }

      // 2. Dispatch native audio to Gemini 2.5 Flash
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw const ValidationFailure(message: 'Audio file not found.');
      }

      return await _voiceService.extractVoiceVoucher(file);
    });
  }

  /// Records explicit DPDP consent for voice processing
  Future<void> recordVoiceConsent({
    required String businessId,
    String purpose = 'VOICE_VOUCHER_PROCESSING',
  }) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      final userId = user?.id;

      await _client.from('dpdp_consent_logs').insert({
        'business_id': businessId,
        if (userId != null) 'user_id': userId,
        'purpose': purpose,
        'consent_given': true,
        'notice_version': '1.0',
        'ip_address': '127.0.0.1',
        'user_agent': 'Ledgify-Mobile-Voice',
      });
    });
  }
}
