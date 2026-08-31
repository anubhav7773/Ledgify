import 'dart:typed_data';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/ai_intake/domain/models/extracted_invoice_payload.dart';

/// Repository orchestrating AI Multimodal bill extraction via FastAPI backend.
class AiIntakeRepository {
  AiIntakeRepository();

  /// Processes bill image via FastAPI Gemini OCR endpoint
  Future<ExtractedInvoicePayload> processBillImage(
    Uint8List imageBytes, {
    required String businessId,
  }) async {
    return await executeSafely<ExtractedInvoicePayload>(() async {
      final response = await ApiClient.postMultipart(
        '/ai/scan-receipt',
        fileBytes: imageBytes,
        filename: 'receipt.jpg',
        fieldName: 'file',
      );

      final data = response as Map<String, dynamic>;
      final vendor = (data['vendor'] as Map<String, dynamic>?) ?? {};
      final lineItemsList = (data['line_items'] as List<dynamic>?) ?? [];

      final items = lineItemsList.map((itemJson) {
        final item = itemJson as Map<String, dynamic>;
        return ExtractedLineItem(
          serialNumber: '1',
          itemDescription: item['description'] ?? 'Item',
          hsnCode: item['hsn_code'] ?? '84716060',
          quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
          unit: item['unit'] ?? 'NOS',
          unitPrice: (item['rate'] as num?)?.toDouble() ?? 0.0,
          taxableValue: ((item['quantity'] as num? ?? 1.0) * (item['rate'] as num? ?? 0.0)).toDouble(),
          gstRate: (item['tax_rate'] as num?)?.toDouble() ?? 18.0,
          cgstAmount: ((item['tax_amount'] as num?)?.toDouble() ?? 0.0) / 2,
          sgstAmount: ((item['tax_amount'] as num?)?.toDouble() ?? 0.0) / 2,
          igstAmount: 0.0,
          itemTotal: (item['total_amount'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      final header = {
        'document_number': data['invoice_number'] ?? 'INV-001',
        'document_date': data['invoice_date'] ?? DateTime.now().toIso8601String().split('T')[0],
      };

      final sellerDetails = {
        'legal_name': vendor['name'] ?? 'Vendor Supplier',
        'gstin': vendor['gstin'] ?? '',
        'pan': vendor['pan'] ?? '',
        'address': vendor['address'] ?? '',
        'state_code': vendor['state_code'] ?? '27',
      };

      final documentTotals = {
        'total_taxable_value': (data['subtotal'] as num?)?.toDouble() ?? 0.0,
        'total_cgst_value': (data['cgst_amount'] as num?)?.toDouble() ?? 0.0,
        'total_sgst_value': (data['sgst_amount'] as num?)?.toDouble() ?? 0.0,
        'total_igst_value': (data['igst_amount'] as num?)?.toDouble() ?? 0.0,
        'total_invoice_value': (data['total_amount'] as num?)?.toDouble() ?? 0.0,
      };

      final accountingPosting = {
        'voucher_type': data['inferred_voucher_type'] ?? 'Purchase',
        'voucher_narration': 'AI OCR extracted bill #${data['invoice_number'] ?? ''} from ${vendor['name'] ?? ''}',
      };

      return ExtractedInvoicePayload(
        header: header,
        sellerDetails: sellerDetails,
        buyerDetails: {'legal_name': 'Apex Enterprises Ltd.'},
        accountingPosting: accountingPosting,
        lineItems: items,
        documentTotals: documentTotals,
        confidenceScore: (data['confidence_score'] as num?)?.toDouble() ?? 0.95,
      );
    });
  }

  /// Records explicit DPDP consent for AI extraction
  Future<void> recordDpdpConsent({
    required String businessId,
    String purpose = 'PURPOSE_DOCUMENT_OCR',
    String noticeVersion = '1.0',
  }) async {
    await executeSafely<void>(() async {
      await ApiClient.post(
        '/dpdp/consents/toggle',
        body: {
          'purpose_code': 'PURPOSE_DOCUMENT_OCR',
          'is_granted': true,
        },
      );
    });
  }
}
