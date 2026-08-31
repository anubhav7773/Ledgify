import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/ai_intake/domain/models/extracted_invoice_payload.dart';
import 'package:ledgify/features/ai_intake/data/services/gemini_ocr_service.dart';

/// Repository orchestrating AI Multimodal bill extraction under DPDP statutory consent gating.
class AiIntakeRepository {
  final SupabaseClient _client;
  final GeminiOcrService _ocrService;

  AiIntakeRepository({
    SupabaseClient? client,
    GeminiOcrService? ocrService,
  })  : _client = client ?? SupabaseClientService.client,
        _ocrService = ocrService ?? GeminiOcrService();

  /// Processes bill image via Gemini Multimodal OCR if DPDP statutory consent is active
  Future<ExtractedInvoicePayload> processBillImage(
    Uint8List imageBytes, {
    required String businessId,
  }) async {
    return await executeSafely<ExtractedInvoicePayload>(() async {
      // 1. Check DPDP Statutory Consent
      final consentResponse = await _client
          .from('dpdp_consent_logs')
          .select()
          .eq('business_id', businessId)
          .eq('purpose', 'FINANCIAL_OCR_EXTRACTION')
          .eq('consent_given', true)
          .isFilter('withdrawn_at', null)
          .limit(1);

      final List<dynamic> consentData = consentResponse as List<dynamic>;
      if (consentData.isEmpty) {
        throw const DpdpConsentRequiredFailure(
          message: 'DPDP statutory consent required for AI processing of financial documents.',
          purpose: 'FINANCIAL_OCR_EXTRACTION',
        );
      }

      // 2. Dispatch to Gemini 2.5 Flash OCR Service
      final rawJson = await _ocrService.extractInvoiceData(imageBytes);

      // 3. Parse into ExtractedInvoicePayload domain model
      return ExtractedInvoicePayload.fromJson(rawJson);
    });
  }

  /// Records explicit DPDP consent for AI extraction
  Future<void> recordDpdpConsent({
    required String businessId,
    String purpose = 'FINANCIAL_OCR_EXTRACTION',
    String noticeVersion = '1.0',
  }) async {
    await executeSafely<void>(() async {
      final user = _client.auth.currentUser;
      final userId = user?.id;

      await _client.from('dpdp_consent_logs').insert({
        'business_id': businessId,
        if (userId != null) 'user_id': userId,
        'purpose': purpose,
        'consent_given': true,
        'notice_version': noticeVersion,
        'ip_address': '127.0.0.1',
        'user_agent': 'Ledgify-Mobile-App',
      });
    });
  }
}
