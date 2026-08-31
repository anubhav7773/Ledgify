import '../models/gst_split_result.dart';

/// Pure computational engine for Indian GST tax calculations and Place of Supply (POS) evaluations.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md.
class GstTaxEngine {
  /// Allowed statutory GST rate slabs in India
  static const List<double> allowedGstRates = [
    0.0,
    0.1,
    0.25,
    3.0,
    5.0,
    12.0,
    18.0,
    28.0,
  ];

  /// Computes the exact GST tax split (CGST+SGST vs IGST) for a given taxable amount and POS
  static GstSplitResult calculateTax({
    required int supplierStateCode,
    required int placeOfSupplyStateCode,
    required double taxableValue,
    required double gstRate, // e.g., 18.0
    String supplyCategory = 'B2B', // B2B, B2C, SEZWP, EXPWP, etc.
  }) {
    if (taxableValue <= 0 || gstRate <= 0) {
      return GstSplitResult.zero(taxableValue);
    }

    // Inter-State supply is triggered when supplier state != place of supply
    // OR when supply category is an export/SEZ with payment of tax (EXPWP, SEZWP, DEXP).
    final bool isInterState = (supplierStateCode != placeOfSupplyStateCode) ||
        supplyCategory == 'EXPWP' ||
        supplyCategory == 'SEZWP' ||
        supplyCategory == 'DEXP';

    if (isInterState) {
      // 100% of GST rate allocated to IGST
      final double rawIgst = taxableValue * (gstRate / 100.0);
      final double igst = double.parse(rawIgst.toStringAsFixed(2));

      return GstSplitResult(
        cgst: 0.00,
        sgst: 0.00,
        igst: igst,
        cess: 0.00,
        totalTax: igst,
        totalAmount: double.parse((taxableValue + igst).toStringAsFixed(2)),
      );
    } else {
      // 50% CGST + 50% SGST
      final double halfRate = gstRate / 2.0;
      final double rawCgst = taxableValue * (halfRate / 100.0);
      final double rawSgst = taxableValue * (halfRate / 100.0);

      final double cgst = double.parse(rawCgst.toStringAsFixed(2));
      final double sgst = double.parse(rawSgst.toStringAsFixed(2));
      final double totalTax = double.parse((cgst + sgst).toStringAsFixed(2));

      return GstSplitResult(
        cgst: cgst,
        sgst: sgst,
        igst: 0.00,
        cess: 0.00,
        totalTax: totalTax,
        totalAmount: double.parse((taxableValue + totalTax).toStringAsFixed(2)),
      );
    }
  }

  /// Calculates invoice-level Round-Off adjustment (to the nearest whole rupee)
  static Map<String, double> computeInvoiceRoundOff(double rawTotalAmount) {
    final double roundedTotal = rawTotalAmount.roundToDouble();
    final double roundOffAdjustment = double.parse((roundedTotal - rawTotalAmount).toStringAsFixed(2));

    return {
      'round_off_amount': roundOffAdjustment,
      'rounded_invoice_total': roundedTotal,
    };
  }
}
