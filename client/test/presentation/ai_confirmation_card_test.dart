import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/widgets/ai_confirmation_card.dart';

void main() {
  group('AiConfirmationCard Widget & Interaction Suite', () {
    testWidgets('Renders confidence badge, document details, and triggers tap-to-edit', (WidgetTester tester) async {
      bool editAmountTapped = false;
      bool confirmTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiConfirmationCard(
                voucherType: 'Purchase',
                voucherNumber: 'BILL/2026/889',
                voucherDate: '31-08-2026',
                partyName: 'Supreme Electricals Ltd',
                partyGstin: '27AABCS1429B1Z8',
                totalAmount: 23600.00,
                taxableAmount: 20000.00,
                taxAmount: 3600.00,
                confidenceScore: 0.94,
                lineItems: const [
                  {'description': 'Copper Wires 2.5mm', 'total': 23600.00}
                ],
                onConfirm: () => confirmTapped = true,
                onEditAmount: () => editAmountTapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify AI badge and confidence label
      expect(find.text('Gemini 2.5 Flash'), findsOneWidget);
      expect(find.textContaining('High Accuracy'), findsOneWidget);

      // Verify Party and Bill Details
      expect(find.text('Supreme Electricals Ltd'), findsOneWidget);
      expect(find.text('GSTIN: 27AABCS1429B1Z8'), findsOneWidget);

      // Tap on Amount section
      await tester.tap(find.textContaining('Total Invoice Amount'));
      await tester.pump();
      expect(editAmountTapped, true);

      // Tap Confirm CTA
      await tester.tap(find.textContaining('Confirm & Post Voucher'));
      await tester.pump();
      expect(confirmTapped, true);
    });
  });
}
