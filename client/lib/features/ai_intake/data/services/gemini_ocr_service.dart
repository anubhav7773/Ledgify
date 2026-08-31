import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../../core/errors/failures.dart';

/// Service interfacing directly with Google Gemini 2.5 Flash API for Multimodal Invoice OCR.
/// Enforces thinking_level: "minimal", strict Unified JSON Schema, and exponential backoff retry on HTTP 429.
class GeminiOcrService {
  final String _apiKey;
  final String _modelName;
  static const int _maxRetries = 4;
  static const int _baseDelayMs = 1500;

  GeminiOcrService({
    String? apiKey,
    String modelName = 'gemini-2.5-flash',
  })  : _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
        _modelName = modelName;

  /// Unified Merged JSON Extraction Schema as defined in docs/06_gemini_ai_multimodal_pipeline.md
  static final Map<String, dynamic> unifiedJsonSchema = {
    "type": "object",
    "properties": {
      "header": {
        "type": "object",
        "properties": {
          "version": {"type": "string"},
          "tax_scheme": {"type": "string"},
          "supply_category": {
            "type": "string",
            "enum": ["B2B", "B2C", "SEZWP", "SEZWOP", "EXPWP", "EXPWOP", "DEXP"]
          },
          "reverse_charge": {"type": "string", "enum": ["Y", "N", "RG", "RC"]},
          "document_type": {"type": "string", "enum": ["INV", "CRN", "DBN"]},
          "document_number": {"type": "string"},
          "document_date": {"type": "string"},
          "original_invoice_number": {"type": "string"}
        },
        "required": ["version", "tax_scheme", "supply_category", "reverse_charge", "document_type", "document_number", "document_date"]
      },
      "seller_details": {
        "type": "object",
        "properties": {
          "gstin": {"type": "string"},
          "legal_name": {"type": "string"},
          "trade_name": {"type": "string"},
          "address": {"type": "string"},
          "location": {"type": "string"},
          "state_code": {"type": "integer"},
          "pincode": {"type": "integer"}
        },
        "required": ["gstin", "legal_name", "address", "location", "state_code", "pincode"]
      },
      "buyer_details": {
        "type": "object",
        "properties": {
          "gstin": {"type": "string"},
          "legal_name": {"type": "string"},
          "place_of_supply": {"type": "string"},
          "address": {"type": "string"},
          "location": {"type": "string"},
          "state_code": {"type": "integer"},
          "pincode": {"type": "integer"}
        },
        "required": ["gstin", "legal_name", "place_of_supply", "address", "location", "state_code"]
      },
      "accounting_posting": {
        "type": "object",
        "properties": {
          "voucher_type": {
            "type": "string",
            "enum": ["Sales", "Purchase", "Payment", "Receipt", "Contra", "Journal", "Debit Note", "Credit Note"]
          },
          "debit_ledger_name": {"type": "string"},
          "credit_ledger_name": {"type": "string"},
          "posting_date": {"type": "string"},
          "itc_claimed": {"type": "boolean"},
          "voucher_narration": {"type": "string"}
        },
        "required": ["voucher_type", "debit_ledger_name", "credit_ledger_name", "posting_date", "itc_claimed", "voucher_narration"]
      },
      "line_items": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "serial_number": {"type": "string"},
            "item_description": {"type": "string"},
            "is_service": {"type": "string", "enum": ["Y", "N"]},
            "hsn_code": {"type": "string"},
            "quantity": {"type": "number"},
            "unit": {"type": "string"},
            "unit_price": {"type": "number"},
            "gross_amount": {"type": "number"},
            "discount_amount": {"type": "number"},
            "taxable_value": {"type": "number"},
            "gst_rate": {"type": "number"},
            "cgst_amount": {"type": "number"},
            "sgst_amount": {"type": "number"},
            "igst_amount": {"type": "number"},
            "item_total": {"type": "number"},
            "item_ledger_name": {"type": "string"},
            "is_capital_good": {"type": "boolean"}
          },
          "required": [
            "serial_number", "item_description", "is_service", "hsn_code", "quantity",
            "unit", "unit_price", "taxable_value", "gst_rate", "item_total",
            "item_ledger_name", "is_capital_good"
          ]
        }
      },
      "document_totals": {
        "type": "object",
        "properties": {
          "total_taxable_value": {"type": "number"},
          "total_cgst_value": {"type": "number"},
          "total_sgst_value": {"type": "number"},
          "total_igst_value": {"type": "number"},
          "round_off_amount": {"type": "number"},
          "total_invoice_value": {"type": "number"}
        },
        "required": ["total_taxable_value", "total_cgst_value", "total_sgst_value", "total_igst_value", "total_invoice_value"]
      }
    },
    "required": ["header", "seller_details", "buyer_details", "accounting_posting", "line_items", "document_totals"]
  };

  /// Dispatches multimodal OCR extraction request to Gemini 2.5 Flash
  Future<Map<String, dynamic>> extractInvoiceData(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final base64Image = base64Encode(imageBytes);

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": "Extract complete double-entry accounting and statutory Indian GST compliance fields from this bill/invoice according to the schema. "
                  "Identify party GSTINs, Place of Supply state codes (1-38), 4/6-digit HSN/SAC codes, and line-item tax allocations."
            },
            {
              "inline_data": {
                "mime_type": mimeType,
                "data": base64Image,
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "response_mime_type": "application/json",
        "response_schema": unifiedJsonSchema,
        "thinking_config": {
          "thinking_level": "minimal"
        }
      }
    };

    return await _executeWithRetry(payload);
  }

  Future<Map<String, dynamic>> _executeWithRetry(Map<String, dynamic> payload) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$_apiKey',
    );
    final random = Random();

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            throw const AiParsingFailure(message: 'Gemini returned no response candidates.');
          }

          final String jsonText = candidates[0]['content']['parts'][0]['text'];
          return jsonDecode(jsonText) as Map<String, dynamic>;
        } else if (response.statusCode == 429) {
          // HTTP 429 Rate limit hit -> apply exponential backoff with jitter
          if (attempt == _maxRetries - 1) {
            throw const GeminiRateLimitFailure(
              message: 'Gemini API rate limit exceeded (HTTP 429). Please try again in a few moments.',
              retryAfterSeconds: 5,
            );
          }
          final delay = _baseDelayMs * pow(2, attempt) + random.nextInt(500);
          await Future.delayed(Duration(milliseconds: delay.toInt()));
          continue;
        } else {
          throw ServerFailure(
            message: 'Gemini OCR API Error [${response.statusCode}]: ${response.body}',
          );
        }
      } catch (e) {
        if (e is Failure) rethrow;
        if (attempt == _maxRetries - 1) {
          throw AiParsingFailure(message: 'Failed to process document with Gemini OCR: $e');
        }
        final delay = _baseDelayMs * pow(2, attempt) + random.nextInt(500);
        await Future.delayed(Duration(milliseconds: delay.toInt()));
      }
    }

    throw const GeminiRateLimitFailure(message: 'Gemini API exhausted retry attempts.');
  }
}
