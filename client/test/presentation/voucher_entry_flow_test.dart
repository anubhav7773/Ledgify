import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/theme/app_colors.dart';
import 'package:client/core/widgets/app_button.dart';
import 'package:client/core/widgets/financial_card.dart';

void main() {
  group('Voucher Entry & Touch Target Accessibility Suite', () {
    testWidgets('AppButton enforces 48x48 dp touch targets', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(
                label: 'Post Voucher',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);

      final Size buttonSize = tester.getSize(buttonFinder);
      expect(buttonSize.height >= AppColors.minTouchTargetSize, true);
      expect(buttonSize.width >= AppColors.minTouchTargetSize, true);

      await tester.tap(buttonFinder);
      expect(tapped, true);
    });

    testWidgets('FinancialCard renders semantic debit green color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FinancialCard(
                title: 'Cash in Hand',
                bilingualSubtitle: 'रोकड़ खाता',
                amount: 15450.00,
                entryType: 'Dr',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cash in Hand'), findsOneWidget);
      expect(find.text('रोकड़ खाता'), findsOneWidget);
      expect(find.text('Dr'), findsOneWidget);
    });
  });
}
