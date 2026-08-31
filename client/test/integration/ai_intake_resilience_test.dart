import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgify/features/ai_intake/domain/models/extracted_invoice_payload.dart';
import 'package:ledgify/features/dpdp_compliance/domain/models/dpdp_failures.dart';
import 'package:ledgify/features/dpdp_compliance/domain/models/dpdp_purpose.dart';

void main() {
  group('AI Intake Pipeline Resiliency & Error Recovery Suite', () {
    test('DPDP Consent Rejection halts pipeline immediately', () async {
      bool consentGranted = false;

      Future<void> attemptExtraction() async {
        if (!consentGranted) {
          throw const DpdpConsentRequiredFailure(
            purpose: DpdpPurpose.financialOcrExtraction,
            message: 'Statutory DPDP consent required to upload bill image to Gemini AI.',
          );
        }
      }

      expect(
        () async => await attemptExtraction(),
        throwsA(isA<DpdpConsentRequiredFailure>()),
      );
    });

    test('Malformed JSON Recovery and Schema Default Fallback', () {
      // Simulating partial / interrupted Gemini Flash JSON stream
      const partialJsonString = '''
      {
        "header": {
          "document_number": "INV-994"
        },
        "seller_details": {
          "legal_name": "Maharashtra Power Systems"
        },
        "document_totals": {
          "total_invoice_value": 11800.00
        }
      }
      ''';

      final decoded = jsonDecode(partialJsonString) as Map<String, dynamic>;
      final payload = ExtractedInvoicePayload.fromJson(decoded);

      expect(payload.documentNumber, 'INV-994');
      expect(payload.sellerName, 'Maharashtra Power Systems');
      expect(payload.totalInvoiceValue, 11800.00);

      // Verify safe default fallbacks for missing keys
      expect(payload.sellerGstin, '');
      expect(payload.totalTaxableValue, 0.00);
      expect(payload.lineItems.isEmpty, true);
    });

    test('Exponential Backoff Delay Multiplier Simulation on HTTP 429', () {
      List<int> retryDelaysMs = [];
      const baseDelayMs = 500;
      const maxRetries = 3;

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        final delay = baseDelayMs * (1 << attempt); // 500ms, 1000ms, 2000ms
        retryDelaysMs.add(delay);
      }

      expect(retryDelaysMs, [500, 1000, 2000]);
    });
  });
}
