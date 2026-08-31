# 10_ui_ux_design_system_tokens.md — Material Design 3 Expressive, Vernacular Typography & Voice-First UI System

## 1. Overview & Trust-First Design Principles
Ledgify is designed specifically for Indian MSME owners, traders, and accountants who prioritize speed, accuracy, and operational trust.
To bridge technical literacy gaps and accommodate low-bandwidth mobile devices, the interface adheres to three core design pillars:
1. **Material Design 3 Expressive Tier:** Uses high-contrast containers, distinct visual hierarchy, spring physics motion, and minimum 48x48 dp touch targets to minimize accidental inputs.
2. **Bilingual Vernacular System (Noto Sans Devanagari):** All field headers, statuses, navigation tabs, and error messages render bilingually (English / हिन्दी) with normalized vertical font baselines to avoid clipping.
3. **High-Trust Multimodal Confirmation Cards:** Visual extraction summaries paired with spoken audio feedback and tap-to-edit inline inputs, enabling instant error correction before ledger commitment[cite: 1, 2].

---

## 2. Material 3 Color Palette & Elevation Tokens

The color palette reinforces clarity and regulatory compliance (CGST/SGST/IGST breakdowns, debit/credit color coding)[cite: 1, 2].

```dart
// client/lib/core/theme/color_tokens.dart
import 'package:flutter/material.dart';

class LedgifyColors {
  // Brand Primary & Accents (Trust & Security)
  static const Color primaryBlue = Color(0xFF0F4C81);      // Deep Indigo Blue
  static const Color primaryContainer = Color(0xFFD6E4FF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  
  // Secondary (Financial Operations)
  static const Color secondarySlate = Color(0xFF535F70);
  static const Color secondaryContainer = Color(0xFFD7E3F8);

  // Accounting Specific Semantic Codes
  static const Color debitGreen = Color(0xFF1B873F);        // Inward / Debit / Asset increase
  static const Color debitGreenBg = Color(0xFFE8F5E9);
  static const Color creditRed = Color(0xFFBA1A1A);          // Outward / Credit / Liability increase
  static const Color creditRedBg = Color(0xFFFFDAD6);
  static const Color warningOrange = Color(0xFFE65100);      // Blocked ITC / Review Required
  static const Color warningOrangeBg = Color(0xFFFFF3E0);

  // Neutral Backgrounds & Card Surfaces (M3 Expressive)
  static const Color surfaceLight = Color(0xFFFDFBFF);
  static const Color surfaceVariant = Color(0xFFE1E2EC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color outlineBorder = Color(0xFF74777F);

  // Touch Target Minimums
  static const double minTouchTargetSize = 48.0;
  static const double standardPadding = 16.0;
  static const double cardBorderRadius = 16.0;
}
3. Vernacular Typography & Baseline Metric Alignment3.1 Noto Sans Devanagari Setup (pubspec.yaml)To eliminate glyph clipping and ensure consistent line heights between English (Latin) and Hindi (Devanagari), the application bundles Google Noto Sans Devanagari locally[cite: 1, 2].YAMLflutter:
  fonts:
    - family: NotoSansDevanagari
      fonts:
        - asset: assets/fonts/NotoSansDevanagari-Regular.ttf
          weight: 400
        - asset: assets/fonts/NotoSansDevanagari-Medium.ttf
          weight: 500
        - asset: assets/fonts/NotoSansDevanagari-Bold.ttf
          weight: 700
3.2 Typography Scale & Text StylesDart// client/lib/core/theme/typography_tokens.dart
import 'package:flutter/material.dart';

class LedgifyTypography {
  static const String fontDeva = 'NotoSansDevanagari';

  static const TextStyle displayTitle = TextStyle(
    fontFamily: fontDeva,
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    height: 1.30, // Adjusted baseline for Devanagari ascenders/descenders
  );

  static const TextStyle cardHeader = TextStyle(
    fontFamily: fontDeva,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle bilingualLabel = TextStyle(
    fontFamily: fontDeva,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: Color(0xFF535F70),
    height: 1.20,
  );

  static const TextStyle financialAmount = TextStyle(
    fontFamily: fontDeva,
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle suggestionChip = TextStyle(
    fontFamily: fontDeva,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
  );
}
4. Voice-First Conversation Design System4.1 Spoken Feedback & Persona MechanicsPersona: Professional, precise, polite Indian financial assistant.  Brevity Rule: Voice responses must never exceed 15 words; combine brief audio prompts with rich visual cards on-screen.  Incremental Confirmation: Acknowledge parsed amounts immediately (e.g., "₹2,500 for Sharma Traders recorded. Please confirm.").  4.2 Voice Repair FlowIf audio is ambiguous or background noise is detected, the UI displays quick-repair suggestion chips rather than forcing the user to re-record the entire transaction[cite: 2]:[Edit Amount / राशि बदलें][Change Party / व्यापारी बदलें][Switch to Purchase / खरीद में बदलें]5. High-Trust AI Confirmation Card ComponentThis Flutter widget presents the extracted JSON payload, highlights confidence indicators, renders GST tax breakdowns, and allows direct tap-to-edit inline adjustments[cite: 1, 2].Dart// client/lib/features/ai_intake/presentation/widgets/ai_confirmation_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';

class AiConfirmationCard extends StatelessWidget {
  final Map<String, dynamic> extractedData;
  final VoidCallback onConfirm;
  final Function(String key, dynamic value) onFieldEdited;

  const AiConfirmationCard({
    Key? key,
    required this.extractedData,
    required this.onConfirm,
    required this.onFieldEdited,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final header = extractedData['header'] ?? {};
    final seller = extractedData['seller_details'] ?? {};
    final totals = extractedData['document_totals'] ?? {};
    final lineItems = (extractedData['line_items'] as List?) ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
      ),
      margin: const EdgeInsets.all(LedgifyColors.standardPadding),
      color: LedgifyColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(LedgifyColors.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Voucher Type & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${header['document_type'] ?? 'INV'} •${header['document_number'] ?? 'N/A'}',
                  style: LedgifyTypography.cardHeader,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LedgifyColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    header['supply_category'] ?? 'B2B',
                    style: LedgifyTypography.suggestionChip.copyWith(color: LedgifyColors.primaryBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Bilingual Party Details (Tap to Edit)
            _buildEditableRow(
              context: context,
              labelEn: 'Party / Vendor',
              labelHi: 'व्यापारी / पार्टी',
              value: seller['legal_name'] ?? 'Unknown Vendor',
              onTap: () => _showInlineTextEditor(context, 'Seller Name', seller['legal_name'], (val) {
                onFieldEdited('seller_details.legal_name', val);
              }),
            ),
            const SizedBox(height: 8),

            _buildEditableRow(
              context: context,
              labelEn: 'Party GSTIN',
              labelHi: 'जीएसटी नंबर',
              value: seller['gstin'] ?? 'URP',
              onTap: () => _showInlineTextEditor(context, 'GSTIN', seller['gstin'], (val) {
                onFieldEdited('seller_details.gstin', val);
              }),
            ),
            const SizedBox(height: 12),

            // Line Items Table Summary
            Text('Line Items (${lineItems.length}) / सामान की सूची', style: LedgifyTypography.bilingualLabel),
            const SizedBox(height: 6),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lineItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = lineItems[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['item_description'] ?? 'Item', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('HSN: ${item['hsn_code']} • Qty: ${item['quantity']} ${item['unit']} @ ₹${item['unit_price']}'),
                  trailing: Text('₹${item['item_total']}', style: LedgifyTypography.financialAmount),
                );
              },
            ),
            const SizedBox(height: 12),
            const Divider(),

            // Tax Split & Final Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CGST / SGST / IGST:', style: LedgifyTypography.bilingualLabel),
                Text('₹${totals['total_cgst_value'] ?? 0} / ₹${totals['total_sgst_value'] ?? 0} / ₹${totals['total_igst_value'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount / कुल राशि:', style: LedgifyTypography.cardHeader),
                Text('₹${totals['total_invoice_value'] ?? 0.00}', style: LedgifyTypography.cardHeader.copyWith(color: LedgifyColors.debitGreen)),
              ],
            ),
            const SizedBox(height: 20),

            // Action Suggestion Chips
            Wrap(
              spacing: 8.0,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Amount / राशि बदलें'),
                  onPressed: () {},
                ),
                ActionChip(
                  avatar: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Change Party / पार्टी बदलें'),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Confirm & Save Button (Minimum 48dp Height)
            SizedBox(
              width: double.infinity,
              height: LedgifyColors.minTouchTargetSize,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LedgifyColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm & Save / पुष्टि करें और सहेजें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableRow({
    required BuildContext context,
    required String labelEn,
    required String labelHi,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$labelEn / $labelHi', style: LedgifyTypography.bilingualLabel),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const Icon(Icons.edit_outlined, size: 18, color: LedgifyColors.secondarySlate),
          ],
        ),
      ),
    );
  }

  void _showInlineTextEditor(BuildContext context, String title, String? initialValue, Function(String) onSaved) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onSaved(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
