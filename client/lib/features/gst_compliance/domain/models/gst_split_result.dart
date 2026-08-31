/// Domain model representing the computed Indian GST tax split and totals.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md.
class GstSplitResult {
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final double totalTax;
  final double totalAmount;

  const GstSplitResult({
    required this.cgst,
    required this.sgst,
    required this.igst,
    this.cess = 0.00,
    required this.totalTax,
    required this.totalAmount,
  });

  /// Indicates whether the transaction is an Intra-State supply (CGST + SGST)
  bool get isIntraState => igst == 0.00 && (cgst > 0.00 || sgst > 0.00);

  /// Indicates whether the transaction is an Inter-State supply (IGST)
  bool get isInterState => igst > 0.00;

  /// Formatted summary strings
  String get formattedCgst => '₹${cgst.toStringAsFixed(2)}';
  String get formattedSgst => '₹${sgst.toStringAsFixed(2)}';
  String get formattedIgst => '₹${igst.toStringAsFixed(2)}';
  String get formattedTotalTax => '₹${totalTax.toStringAsFixed(2)}';
  String get formattedTotalAmount => '₹${totalAmount.toStringAsFixed(2)}';

  factory GstSplitResult.zero(double taxableValue) {
    return GstSplitResult(
      cgst: 0.00,
      sgst: 0.00,
      igst: 0.00,
      cess: 0.00,
      totalTax: 0.00,
      totalAmount: double.parse(taxableValue.toStringAsFixed(2)),
    );
  }
}
