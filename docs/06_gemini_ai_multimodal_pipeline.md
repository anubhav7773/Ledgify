Neeche Doc 6: 06_gemini_ai_multimodal_pipeline.md ka complete, production-grade content hai. Isse copy karke apni docs/06_gemini_ai_multimodal_pipeline.md file mein paste kar lijiye.  Markdown# 06_gemini_ai_multimodal_pipeline.md — Multimodal Gemini API Architecture, Unified Merged Schema & Rate-Limit Management

## 1. Executive Summary & Pipeline Scope
Ledgify utilizes the Google Gemini API to eliminate manual data entry across Indian MSME accounting workflows[cite: 1, 2]. 
The pipeline processes two multimodal intake channels:
1. **Document OCR & Vision Intake:** Ingests physical bill photos, tax invoice images (PNG/JPEG/WEBP/HEIC), and multi-page digital PDFs[cite: 2]. Extracts header data, seller/buyer details, line-item arrays, tax splits, and normalized 2D bounding boxes (`box_2d`)[cite: 1, 2].
2. **Audio & Voice Note Intake:** Ingests spoken expense descriptions and voucher commands (e.g., mixed Hindi/English speech)[cite: 2]. Passes native audio directly to the multimodal model to extract structured double-entry vouchers without intermediate speech-to-text latency[cite: 2].

All model outputs are constrained via `response_format` with a single, production-hardened **Unified Merged JSON Schema** combining accounting, GST compliance, and visual localization[cite: 1].

---

## 2. Token Math, Pricing & Rate-Limit Parameters

### 2.1 Free-Tier Token & Resolution Mechanics
- **Base Image Cost:** Images with both dimensions $\le 384\text{px}$ consume **258 tokens**[cite: 2].
- **Image Tiling Formula:** Images exceeding $384\text{px}$ are tiled into $768 \times 768\text{px}$ blocks based on crop unit size:
  $$\text{Crop Unit Size} = \left\lfloor \frac{\min(\text{Width}, \text{Height})}{1.5} \right\rfloor$$
  $$\text{Total Image Tokens} = \left( \left\lceil \frac{\text{Width}}{\text{Crop Unit}} \right\rceil \times \left\lceil \frac{\text{Height}}{\text{Crop Unit}} \right\rceil \right) \times 258$$
- **Audio Token Consumption:** Multimodal audio input is billed at a fixed rate of **25 tokens per second** (e.g., a 30-second Hindi voice voucher consumes exactly $30 \times 25 = 750\text{ input tokens}$)[cite: 2].
- **Request Size Boundaries:**
  - Inline Base64 (`inline_data`): Capped at **20MB** total payload size[cite: 2].
  - Files API (`client.files.upload`): Mandatory for payloads $> 20\text{MB}$ or reused documents[cite: 2].

---

## 3. The Unified Merged JSON Schema (Complete Specification)

This JSON Schema is enforced across all Gemini API calls using `mime_type: "application/json"`[cite: 1, 2].

```json
{
  "$schema": "[http://json-schema.org/draft-07/schema#](http://json-schema.org/draft-07/schema#)",
  "title": "UnifiedExtractionAndAccountingSchema",
  "description": "Unified schema combining Gemini multimodal OCR/voice extraction with GST compliance (FORM GST INV-01) and double-entry ledger rules.",
  "type": "object",
  "properties": {
    "header": {
      "type": "object",
      "description": "Document classification and GST category headers",
      "properties": {
        "version": { "type": "string", "description": "E-invoice schema version, default '1.1'" },
        "tax_scheme": { "type": "string", "description": "Applicable tax regime, default 'GST'" },
        "supply_category": {
          "type": "string",
          "enum": ["B2B", "B2C", "SEZWP", "SEZWOP", "EXPWP", "EXPWOP", "DEXP"],
          "description": "Transaction category for GST reporting"
        },
        "reverse_charge": { "type": "string", "enum": ["Y", "N", "RG", "RC"], "description": "Whether supply attracts reverse charge" },
        "document_type": { "type": "string", "enum": ["INV", "CRN", "DBN"], "description": "INV for Invoice, CRN for Credit Note, DBN for Debit Note" },
        "document_number": { "type": "string", "description": "Supplier document number (max 16 chars alphanumeric)" },
        "document_date": { "type": "string", "description": "Document date in YYYY-MM-DD format" },
        "original_invoice_number": { "type": ["string", "null"], "description": "Original invoice reference if credit or debit note" }
      },
      "required": ["version", "tax_scheme", "supply_category", "reverse_charge", "document_type", "document_number", "document_date"]
    },
    "seller_details": {
      "type": "object",
      "description": "Supplier identity and tax registration metadata",
      "properties": {
        "gstin": { "type": "string", "description": "15-character GSTIN of supplier" },
        "legal_name": { "type": "string", "description": "Legal business name" },
        "trade_name": { "type": ["string", "null"], "description": "Trade name / alias" },
        "address": { "type": "string", "description": "Street address" },
        "location": { "type": "string", "description": "City or municipality" },
        "state_code": { "type": "integer", "description": "2-digit numeric state code (1-38)" },
        "pincode": { "type": "integer", "description": "6-digit postal PIN code" }
      },
      "required": ["gstin", "legal_name", "address", "location", "state_code", "pincode"]
    },
    "buyer_details": {
      "type": "object",
      "description": "Customer identity and Place of Supply",
      "properties": {
        "gstin": { "type": "string", "description": "15-character GSTIN of recipient or 'URP' for unregistered" },
        "legal_name": { "type": "string", "description": "Legal recipient name" },
        "place_of_supply": { "type": "string", "description": "2-digit state code determining POS" },
        "address": { "type": "string", "description": "Recipient billing address" },
        "location": { "type": "string", "description": "Recipient city" },
        "state_code": { "type": "integer", "description": "2-digit state code" },
        "pincode": { "type": ["integer", "null"], "description": "Postal PIN code" }
      },
      "required": ["gstin", "legal_name", "place_of_supply", "address", "location", "state_code"]
    },
    "accounting_posting": {
      "type": "object",
      "description": "Double-entry classification and posting instructions",
      "properties": {
        "voucher_type": {
          "type": "string",
          "enum": ["Sales", "Purchase", "Payment", "Receipt", "Contra", "Journal", "Debit Note", "Credit Note"],
          "description": "Accounting voucher classification"
        },
        "debit_ledger_name": { "type": "string", "description": "Primary account to debit" },
        "credit_ledger_name": { "type": "string", "description": "Primary account to credit" },
        "posting_date": { "type": "string", "description": "Accounting posting date (YYYY-MM-DD)" },
        "itc_claimed": { "type": "boolean", "description": "Whether Input Tax Credit is claimed (CGST Sec 16(3))" },
        "cost_center": { "type": ["string", "null"], "description": "Optional department or cost center" },
        "voucher_narration": { "type": "string", "description": "Transaction remarks for journal entry" }
      },
      "required": ["voucher_type", "debit_ledger_name", "credit_ledger_name", "posting_date", "itc_claimed", "voucher_narration"]
    },
    "line_items": {
      "type": "array",
      "description": "List of itemized goods or services",
      "items": {
        "type": "object",
        "properties": {
          "serial_number": { "type": "string", "description": "Line serial number (1, 2, 3...)" },
          "item_description": { "type": "string", "description": "Product or service description" },
          "is_service": { "type": "string", "enum": ["Y", "N"], "description": "Y for service (SAC), N for goods (HSN)" },
          "hsn_code": { "type": "string", "description": "Mandatory 4 or 6-digit HSN/SAC code" },
          "quantity": { "type": "number", "description": "Billed quantity" },
          "unit": { "type": "string", "description": "Unit Quantity Code (e.g. PCS, NOS, KGS)" },
          "unit_price": { "type": "number", "description": "Unit price (up to 3 decimal places)" },
          "gross_amount": { "type": "number", "description": "Gross amount before discount" },
          "discount_amount": { "type": "number", "description": "Line-item discount" },
          "taxable_value": { "type": "number", "description": "Assessable value (AssAmt)" },
          "gst_rate": { "type": "number", "description": "GST rate slab percentage (0, 0.1, 0.25, 3, 5, 12, 18, 28)" },
          "cgst_amount": { "type": "number", "description": "Central tax amount" },
          "sgst_amount": { "type": "number", "description": "State tax amount" },
          "igst_amount": { "type": "number", "description": "Integrated tax amount" },
          "item_total": { "type": "number", "description": "Line total inclusive of taxes" },
          "item_ledger_name": { "type": "string", "description": "Specific ledger to map this line item" },
          "is_capital_good": { "type": "boolean", "description": "True if item is a fixed asset" },
          "useful_life_years": { "type": ["integer", "null"], "description": "Schedule II useful life in years if capital good" },
          "box_2d": {
            "type": ["array", "null"],
            "items": { "type": "integer" },
            "description": "OCR normalized bounding box coordinates [ymin, xmin, ymax, xmax] on scale 0-1000"
          }
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
      "description": "Document summary values",
      "properties": {
        "total_taxable_value": { "type": "number", "description": "Sum of taxable values" },
        "total_cgst_value": { "type": "number", "description": "Total CGST amount" },
        "total_sgst_value": { "type": "number", "description": "Total SGST amount" },
        "total_igst_value": { "type": "number", "description": "Total IGST amount" },
        "round_off_amount": { "type": "number", "description": "Rounding adjustment (+/-)" },
        "total_invoice_value": { "type": "number", "description": "Final payable invoice total" }
      },
      "required": ["total_taxable_value", "total_cgst_value", "total_sgst_value", "total_igst_value", "total_invoice_value"]
    }
  },
  "required": ["header", "seller_details", "buyer_details", "accounting_posting", "line_items", "document_totals"]
}
4. Flutter Gemini Client Implementation with Exponential BackoffThis service coordinates multimodal calls, applies thinking_level: "minimal" for token efficiency and segmentation precision, and executes exponential backoff with jitter on HTTP 429 RESOURCE_EXHAUSTED[cite: 2].client/lib/core/network/gemini_pipeline_service.dartDartimport 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

class GeminiPipelineService {
  final String apiKey;
  final String modelName;
  static const int _maxRetries = 4;
  static const int _baseDelayMs = 1500;

  GeminiPipelineService({
    required this.apiKey,
    this.modelName = 'gemini-2.5-flash',
  });

  /// Extracts structured accounting voucher from an image file (OCR)
  Future<Map<String, dynamic>> extractFromImage(File imageFile, Map<String, dynamic> jsonSchema) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": "Extract complete double-entry accounting and GST compliance fields from this bill/invoice according to the schema."
            },
            {
              "inline_data": {
                "mime_type": _getMimeType(imageFile.path),
                "data": base64Image
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "response_mime_type": "application/json",
        "response_schema": jsonSchema,
        "thinking_config": {
          "thinking_level": "minimal"
        }
      }
    };

    return await _executeWithRetry(payload);
  }

  /// Extracts structured accounting voucher from an audio recording (Voice)
  Future<Map<String, dynamic>> extractFromAudio(File audioFile, Map<String, dynamic> jsonSchema) async {
    final bytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": "Parse this Hindi/English voice note into double-entry accounting transactions, classifying ledgers, amounts, and GST details."
            },
            {
              "inline_data": {
                "mime_type": "audio/mp3",
                "data": base64Audio
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "response_mime_type": "application/json",
        "response_schema": jsonSchema
      }
    };

    return await _executeWithRetry(payload);
  }

  Future<Map<String, dynamic>> _executeWithRetry(Map<String, dynamic> payload) async {
    final url = Uri.parse('[https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey](https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey)');
    final random = Random();

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final String jsonText = data['candidates'][0]['content']['parts'][0]['text'];
          return jsonDecode(jsonText) as Map<String, dynamic>;
        } else if (response.statusCode == 429) {
          // Rate Limit Hit: Exponential backoff with full jitter
          final delay = _baseDelayMs * pow(2, attempt) + random.nextInt(500);
          await Future.delayed(Duration(milliseconds: delay.toInt()));
          continue;
        } else {
          throw Exception('Gemini API Failure [${response.statusCode}]:${response.body}');
        }
      } catch (e) {
        if (attempt == _maxRetries - 1) rethrow;
        final delay = _baseDelayMs * pow(2, attempt) + random.nextInt(500);
        await Future.delayed(Duration(milliseconds: delay.toInt()));
      }
    }
    throw Exception('Gemini API exhausted retry attempts.');
  }

  String _getMimeType(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.heic')) return 'image/heic';
    if (path.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
