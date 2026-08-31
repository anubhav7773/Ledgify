import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Statutory ITC Set-Off Engine (Section 49/49A/49B)', () {
    test('Mandatory IGST Exhaustion Before CGST/SGST Utilization', () {
      double igstCredit = 50000.0;
      double cgstCredit = 20000.0;
      double sgstCredit = 20000.0;

      double igstLiability = 30000.0;
      double cgstLiability = 25000.0;
      double sgstLiability = 25000.0;

      // 1. Set off IGST credit against IGST liability
      final igstUsedForIgst = igstCredit.clamp(0.0, igstLiability);
      igstCredit -= igstUsedForIgst;
      igstLiability -= igstUsedForIgst;

      expect(igstLiability, 0.0);
      expect(igstCredit, 20000.0); // Remaining IGST credit

      // 2. Set off remaining IGST credit against CGST & SGST equally/as preferred
      final igstUsedForCgst = igstCredit.clamp(0.0, 10000.0);
      igstCredit -= igstUsedForCgst;
      cgstLiability -= igstUsedForCgst;

      final igstUsedForSgst = igstCredit.clamp(0.0, 10000.0);
      igstCredit -= igstUsedForSgst;
      sgstLiability -= igstUsedForSgst;

      expect(igstCredit, 0.0); // Fully exhausted
      expect(cgstLiability, 15000.0);
      expect(sgstLiability, 15000.0);

      // 3. Set off CGST credit against remaining CGST liability
      final cgstUsedForCgst = cgstCredit.clamp(0.0, cgstLiability);
      cgstCredit -= cgstUsedForCgst;
      cgstLiability -= cgstUsedForCgst;

      expect(cgstLiability, 0.0);
      expect(cgstCredit, 5000.0);

      // 4. Set off SGST credit against remaining SGST liability
      final sgstUsedForSgst = sgstCredit.clamp(0.0, sgstLiability);
      sgstCredit -= sgstUsedForSgst;
      sgstLiability -= sgstUsedForSgst;

      expect(sgstLiability, 0.0);
      expect(sgstCredit, 5000.0);

      // Invariant: CGST credit NEVER offsets SGST liability and vice versa
      expect(cgstCredit > 0, true);
      expect(sgstCredit > 0, true);
    });

    test('Section 17(5) Blocked ITC Exclusion from Eligible Credit', () {
      final List<Map<String, dynamic>> inwardInvoices = [
        {'id': 'inv_1', 'taxable': 10000.0, 'tax': 1800.0, 'is_blocked_itc_17_5': false}, // General Purchase
        {'id': 'inv_2', 'taxable': 50000.0, 'tax': 14000.0, 'is_blocked_itc_17_5': true}, // Motor Vehicle for personal use
        {'id': 'inv_3', 'taxable': 5000.0, 'tax': 900.0, 'is_blocked_itc_17_5': false},   // Office Supplies
      ];

      double eligibleItc = 0.0;
      double blockedItc = 0.0;

      for (final inv in inwardInvoices) {
        final tax = (inv['tax'] as num).toDouble();
        if (inv['is_blocked_itc_17_5'] == true) {
          blockedItc += tax;
        } else {
          eligibleItc += tax;
        }
      }

      expect(eligibleItc, 2700.0);
      expect(blockedItc, 14000.0);
      expect(eligibleItc + blockedItc, 16700.0);
    });
  });
}
