import '../../../vouchers/domain/models/voucher_line_item_model.dart';
import '../../../vouchers/domain/models/voucher_model.dart';

/// Domain model representing the full structured extraction output from Gemini 2.5 Flash.
/// Adheres strictly to docs/06_gemini_ai_multimodal_pipeline.md.
class ExtractedInvoicePayload {
  final Map<String, dynamic> header;
  final Map<String, dynamic> sellerDetails;
  final Map<String, dynamic> buyerDetails;
  final Map<String, dynamic> accountingPosting;
  final List<ExtractedLineItem> lineItems;
  final Map<String, dynamic> documentTotals;
  final double confidenceScore;

  const ExtractedInvoicePayload({
    required this.header,
    required this.sellerDetails,
    required this.buyerDetails,
    required this.accountingPosting,
    required this.lineItems,
    required this.documentTotals,
    this.confidenceScore = 0.95,
  });

  factory ExtractedInvoicePayload.fromJson(Map<String, dynamic> json) {
    final rawItems = json['line_items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((item) => ExtractedLineItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return ExtractedInvoicePayload(
      header: json['header'] as Map<String, dynamic>? ?? {},
      sellerDetails: json['seller_details'] as Map<String, dynamic>? ?? {},
      buyerDetails: json['buyer_details'] as Map<String, dynamic>? ?? {},
      accountingPosting: json['accounting_posting'] as Map<String, dynamic>? ?? {},
      lineItems: items,
      documentTotals: json['document_totals'] as Map<String, dynamic>? ?? {},
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'header': header,
      'seller_details': sellerDetails,
      'buyer_details': buyerDetails,
      'accounting_posting': accountingPosting,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'document_totals': documentTotals,
      'confidence_score': confidenceScore,
    };
  }

  // Quick getters
  String get documentNumber => header['document_number'] as String? ?? 'INV-001';
  String get documentDate => header['document_date'] as String? ?? DateTime.now().toIso8601String().split('T').first;
  String get sellerName => sellerDetails['legal_name'] as String? ?? 'Vendor Enterprise';
  String get sellerGstin => sellerDetails['gstin'] as String? ?? '';
  String get buyerName => buyerDetails['legal_name'] as String? ?? 'Our Company';
  double get totalInvoiceValue => (documentTotals['total_invoice_value'] as num?)?.toDouble() ?? 0.00;
  double get totalTaxableValue => (documentTotals['total_taxable_value'] as num?)?.toDouble() ?? 0.00;
  double get totalTax =>
      ((documentTotals['total_cgst_value'] as num?)?.toDouble() ?? 0.00) +
      ((documentTotals['total_sgst_value'] as num?)?.toDouble() ?? 0.00) +
      ((documentTotals['total_igst_value'] as num?)?.toDouble() ?? 0.00);

  /// Converts AI extracted payload into a double-entry VoucherModel ready for database posting
  VoucherModel toVoucherModel({
    required String businessId,
    required String voucherTypeId,
    required String debitAccountId,
    required String creditAccountId,
  }) {
    final List<VoucherLineItemModel> voucherLines = [];

    // Line 1: Purchase / Expense Debit
    voucherLines.add(
      VoucherLineItemModel(
        id: '',
        businessId: businessId,
        voucherId: '',
        accountId: debitAccountId,
        entryType: 'Dr',
        amount: totalInvoiceValue,
        itemDescription: 'AI Scanned Bill: $documentNumber from $sellerName',
        cgstAmt: (documentTotals['total_cgst_value'] as num?)?.toDouble() ?? 0.00,
        sgstAmt: (documentTotals['total_sgst_value'] as num?)?.toDouble() ?? 0.00,
        igstAmt: (documentTotals['total_igst_value'] as num?)?.toDouble() ?? 0.00,
      ),
    );

    // Line 2: Sundry Creditor / Supplier Credit
    voucherLines.add(
      VoucherLineItemModel(
        id: '',
        businessId: businessId,
        voucherId: '',
        accountId: creditAccountId,
        entryType: 'Cr',
        amount: totalInvoiceValue,
        itemDescription: 'Payable to $sellerName (GSTIN: $sellerGstin)',
      ),
    );

    return VoucherModel(
      id: '',
      businessId: businessId,
      voucherTypeId: voucherTypeId,
      voucherNumber: documentNumber,
      voucherDate: DateTime.tryParse(documentDate) ?? DateTime.now(),
      narration: accountingPosting['voucher_narration'] as String? ??
          'Auto-extracted via Gemini AI Multimodal OCR from invoice #$documentNumber',
      aiConfidenceScore: confidenceScore,
      lineItems: voucherLines,
    );
  }
}

/// Itemized line entry extracted by Gemini OCR
class ExtractedLineItem {
  final String serialNumber;
  final String itemDescription;
  final String isService;
  final String hsnCode;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double taxableValue;
  final double gstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double itemTotal;

  const ExtractedLineItem({
    required this.serialNumber,
    required this.itemDescription,
    this.isService = 'N',
    required this.hsnCode,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.taxableValue,
    required this.gstRate,
    this.cgstAmount = 0.00,
    this.sgstAmount = 0.00,
    this.igstAmount = 0.00,
    required this.itemTotal,
  });

  factory ExtractedLineItem.fromJson(Map<String, dynamic> json) {
    return ExtractedLineItem(
      serialNumber: json['serial_number']?.toString() ?? '1',
      itemDescription: json['item_description'] as String? ?? 'Item',
      isService: json['is_service'] as String? ?? 'N',
      hsnCode: json['hsn_code'] as String? ?? '998311',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'NOS',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.00,
      taxableValue: (json['taxable_value'] as num?)?.toDouble() ?? 0.00,
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 18.0,
      cgstAmount: (json['cgst_amount'] as num?)?.toDouble() ?? 0.00,
      sgstAmount: (json['sgst_amount'] as num?)?.toDouble() ?? 0.00,
      igstAmount: (json['igst_amount'] as num?)?.toDouble() ?? 0.00,
      itemTotal: (json['item_total'] as num?)?.toDouble() ?? 0.00,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serial_number': serialNumber,
      'item_description': itemDescription,
      'is_service': isService,
      'hsn_code': hsnCode,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'taxable_value': taxableValue,
      'gst_rate': gstRate,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
      'item_total': itemTotal,
    };
  }
}
