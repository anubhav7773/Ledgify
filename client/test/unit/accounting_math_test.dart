import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/utils/formatters.dart';

void main() {
  group('Accounting Math & Statutory Formulas Suite', () {
    test('Indian Numbering System Currency Formatting', () {
      expect(CurrencyFormatter.formatInr(0.0), '₹0.00');
      expect(CurrencyFormatter.formatInr(0.50), '₹0.50');
      expect(CurrencyFormatter.formatInr(99999.00), '₹99,999.00');
      expect(CurrencyFormatter.formatInr(100000.00), '₹1,00,000.00');
      expect(CurrencyFormatter.formatInr(5000000.00), '₹50,00,000.00');
      expect(CurrencyFormatter.formatInr(100000000.00), '₹10,00,00,000.00');
    });

    test('Compact Indian Currency Representation', () {
      expect(CurrencyFormatter.formatInrCompact(150000.0), '₹1.50 L');
      expect(CurrencyFormatter.formatInrCompact(24000000.0), '₹2.40 Cr');
      expect(CurrencyFormatter.formatInrCompact(5000.0), '₹5.0 k');
    });

    test('GST Split Intra-State vs Inter-State Calculation', () {
      const taxableValue = 10000.00;
      const gstRate = 0.18; // 18%

      // Intra-state (CGST 9% + SGST 9%)
      final cgst = double.parse((taxableValue * (gstRate / 2)).toStringAsFixed(2));
      final sgst = double.parse((taxableValue * (gstRate / 2)).toStringAsFixed(2));
      final totalIntra = taxableValue + cgst + sgst;

      expect(cgst, 900.00);
      expect(sgst, 900.00);
      expect(totalIntra, 11800.00);

      // Inter-state (IGST 18%)
      final igst = double.parse((taxableValue * gstRate).toStringAsFixed(2));
      final totalInter = taxableValue + igst;

      expect(igst, 1800.00);
      expect(totalInter, 11800.00);
      expect(cgst + sgst, igst);
    });

    test('Financial Year Calculation', () {
      expect(DateFormatter.formatFinancialYear(DateTime(2026, 4, 1)), '2026-2027');
      expect(DateFormatter.formatFinancialYear(DateTime(2026, 8, 31)), '2026-2027');
      expect(DateFormatter.formatFinancialYear(DateTime(2027, 3, 31)), '2026-2027');
      expect(DateFormatter.formatFinancialYear(DateTime(2027, 1, 15)), '2026-2027');
    });
  });
}
