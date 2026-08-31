import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../../core/errors/failures.dart';

/// Service dispatching native audio recordings to Google Gemini 2.5 Flash for Hindi/Hinglish Voice Voucher parsing.
/// Enforces thinking_level: "minimal" and strict double-entry JSON response schema.
class GeminiVoiceService {
  final String _apiKey;
  final String _modelName;
  static const int _maxRetries = 4;
  static const int _baseDelayMs = 1500;

  GeminiVoiceService({
    String? apiKey,
    String modelName = 'gemini-2.5-flash',
  })  : _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
        _modelName = modelName;

  /// Strict JSON response schema for Voice Voucher Extraction
  static final Map<String, dynamic> voiceVoucherSchema = {
    "type": "object",
    "properties": {
      "voucher_type": {
        "type": "string",
        "enum": ["Sales", "Purchase", "Payment", "Receipt", "Contra", "Journal", "Debit Note", "Credit Note"]
      },
      "party_name": {
        "type": "string",
        "description": "Name of customer, supplier, or entity mentioned"
      },
      "payment_mode": {
        "type": "string",
        "enum": ["Cash", "Bank / UPI", "Credit"]
      },
      "total_amount": {
        "type": "number",
        "description": "Total numeric monetary value of the transaction"
      },
      "narration": {
        "type": "string",
        "description": "Clean, standardized bilingual accounting narration"
      },
      "line_items": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "item_name": {"type": "string"},
            "quantity": {"type": "number"},
            "unit": {"type": "string"},
            "rate": {"type": "number"},
            "gst_rate": {"type": "number"},
            "amount": {"type": "number"}
          },
          "required": ["item_name", "amount"]
        }
      },
      "spoken_language_detected": {
        "type": "string",
        "description": "e.g., 'hi-Latn' (Hinglish), 'hi' (Hindi), 'en' (English)"
      },
      "confidence_score": {
        "type": "number",
        "description": "Confidence estimate between 0.0 and 1.0"
      }
    },
    "required": [
      "voucher_type",
      "party_name",
      "payment_mode",
      "total_amount",
      "narration",
      "confidence_score"
    ]
  };

  /// Parses recorded audio file into a structured double-entry transaction
  Future<Map<String, dynamic>> extractVoiceVoucher(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": "You are an expert Indian MSME Chartered Accountant and TallyPrime specialist. "
                  "Listen to this audio note in Hindi, English, or mixed Hinglish and convert it into a standardized double-entry accounting transaction according to the schema.\n"
                  "Rules for Indian accounting idioms:\n"
                  "1. 'Mishra ji ko 5000 cash diya' -> voucher_type: 'Payment', party_name: 'Mishra Ji', payment_mode: 'Cash', total_amount: 5000\n"
                  "2. 'Ramesh se 12000 ka payment aaya phonepe / gpay pe' -> voucher_type: 'Receipt', party_name: 'Ramesh', payment_mode: 'Bank / UPI', total_amount: 12000\n"
                  "3. 'Gupta Traders ko 10 peti tel becha 18% GST pe' -> voucher_type: 'Sales', party_name: 'Gupta Traders', payment_mode: 'Credit'\n"
                  "4. 'Bank se 20000 cash nikala' -> voucher_type: 'Contra', party_name: 'Bank Accounts', payment_mode: 'Cash', total_amount: 20000\n"
                  "5. 'Office ke liye 500 ka chai nashta liya' -> voucher_type: 'Payment', party_name: 'Office Expenses', payment_mode: 'Cash', total_amount: 500"
            },
            {
              "inline_data": {
                "mime_type": "audio/m4a",
                "data": base64Audio
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "response_mime_type": "application/json",
        "response_schema": voiceVoucherSchema,
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
            throw const AiParsingFailure(message: 'Gemini Voice API returned no candidates.');
          }

          final String jsonText = candidates[0]['content']['parts'][0]['text'];
          return jsonDecode(jsonText) as Map<String, dynamic>;
        } else if (response.statusCode == 429) {
          if (attempt == _maxRetries - 1) {
            throw const GeminiRateLimitFailure(
              message: 'Gemini Voice API rate limit exceeded (HTTP 429).',
              retryAfterSeconds: 5,
            );
          }
          final delay = _baseDelayMs * pow(2, attempt) + random.nextInt(500);
          await Future.delayed(Duration(milliseconds: delay.toInt()));
          continue;
        } else {
          throw ServerFailure(
            message: 'Gemini Voice API Error [${response.statusCode}]: ${response.body}',
          );
        }
      } catch (e) {
        if (e is Failure) rethrow;
        if (attempt == _maxRetries - 1) {
          throw AiParsingFailure(message: 'Failed to process voice note with Gemini: $e');
        }
        final delay = _baseDelayMs * pow(2, attempt) + random.nextInt(500);
        await Future.delayed(Duration(milliseconds: delay.toInt()));
      }
    }

    throw const GeminiRateLimitFailure(message: 'Gemini Voice API exhausted retry attempts.');
  }
}
