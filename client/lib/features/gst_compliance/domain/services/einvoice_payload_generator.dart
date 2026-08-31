import '../../../masters/domain/models/account_model.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../models/gst_registration_model.dart';

/// Service generating standard statutory FORM GST INV-01 Version 1.1 JSON payloads for IRP submission.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md.
class EInvoicePayloadGenerator {
  /// Generates the complete FORM GST INV-01 Version 1.1 JSON payload
  static Map<String, dynamic> generateInv01Payload({
    required VoucherModel voucher,
    required GstRegistrationModel sellerReg,
    required AccountModel buyerAccount,
    String? placeOfSupply,
    String supplyType = 'B2B',
    double roundOff = 0.00,
  }) {
    // 1. Format Dates (DD/MM/YYYY)
    final date = voucher.voucherDate;
    final formattedDocDate =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    // 2. Determine Document Type Code
    String docType = 'INV';
    final typeName = voucher.voucherTypeName?.toLowerCase() ?? '';
    if (typeName.contains('credit')) {
      docType = 'CRN';
    } else if (typeName.contains('debit')) {
      docType = 'DBN';
    }

    // 3. Enforce 16-Character Document Number Limit
    String docNo = voucher.voucherNumber;
    if (docNo.length > 16) {
      docNo = docNo.substring(0, 16);
    }

    final buyerPos = placeOfSupply ??
        (buyerAccount.partyGstin != null && buyerAccount.partyGstin!.length >= 2
            ? buyerAccount.partyGstin!.substring(0, 2)
            : sellerReg.stateCode.toString().padLeft(2, '0'));

    // 4. Build Item List
    final List<Map<String, dynamic>> itemList = [];
    double totalAssVal = 0.00;
    double totalCgstVal = 0.00;
    double totalSgstVal = 0.00;
    double totalIgstVal = 0.00;
    double totalCesVal = 0.00;

    int itemIndex = 1;
    for (final line in voucher.lineItems) {
      if (line.entryType == 'Cr' && docType == 'INV') {
        // Sales Ledger Line Item
        final double assAmt = double.parse(line.amount.toStringAsFixed(2));
        final double cgst = double.parse(line.cgstAmt.toStringAsFixed(2));
        final double sgst = double.parse(line.sgstAmt.toStringAsFixed(2));
        final double igst = double.parse(line.igstAmt.toStringAsFixed(2));
        final double cess = double.parse(line.cessAmt.toStringAsFixed(2));
        final double totItemVal = double.parse((assAmt + cgst + sgst + igst + cess).toStringAsFixed(2));

        totalAssVal += assAmt;
        totalCgstVal += cgst;
        totalSgstVal += sgst;
        totalIgstVal += igst;
        totalCesVal += cess;

        // Compute effective GST rate
        final double effectiveGstRate = assAmt > 0
            ? double.parse((((cgst + sgst + igst) / assAmt) * 100).toStringAsFixed(2))
            : 0.00;

        itemList.add({
          'SlNo': itemIndex.toString(),
          'PrdDesc': line.itemDescription ?? 'Goods / Services',
          'IsServc': 'N',
          'HsnCd': buyerAccount.hsnSacCode ?? '84821010',
          'Qty': 1.00,
          'Unit': 'NOS',
          'UnitPrice': assAmt,
          'TotAmt': assAmt,
          'Discount': 0.00,
          'PreTaxVal': assAmt,
          'AssAmt': assAmt,
          'GstRt': effectiveGstRate,
          'IgstAmt': igst,
          'CgstAmt': cgst,
          'SgstAmt': sgst,
          'CesRt': 0.000,
          'CesAmt': cess,
          'TotItemVal': totItemVal,
        });

        itemIndex++;
      }
    }

    // If no specific credit item was parsed, provide standard summary item
    if (itemList.isEmpty) {
      final double totalVal = voucher.totalCreditAmount > 0 ? voucher.totalCreditAmount : voucher.totalDebitAmount;
      totalAssVal = totalVal;
      itemList.add({
        'SlNo': '1',
        'PrdDesc': 'Commercial Supply',
        'IsServc': 'N',
        'HsnCd': '998311',
        'Qty': 1.00,
        'Unit': 'NOS',
        'UnitPrice': totalVal,
        'TotAmt': totalVal,
        'Discount': 0.00,
        'PreTaxVal': totalVal,
        'AssAmt': totalVal,
        'GstRt': 18.000,
        'IgstAmt': 0.00,
        'CgstAmt': 0.00,
        'SgstAmt': 0.00,
        'CesRt': 0.000,
        'CesAmt': 0.00,
        'TotItemVal': totalVal,
      });
    }

    final double totalInvVal = double.parse(
        (totalAssVal + totalCgstVal + totalSgstVal + totalIgstVal + totalCesVal + roundOff).toStringAsFixed(2));

    return {
      'Version': '1.1',
      'TranDtls': {
        'TaxSch': 'GST',
        'SupTyp': supplyType,
        'RegRev': 'N',
        'EcmGstin': null,
        'IgstOnIntra': 'N',
      },
      'DocDtls': {
        'Typ': docType,
        'No': docNo,
        'Dt': formattedDocDate,
      },
      'SellerDtls': {
        'Gstin': sellerReg.gstin,
        'LglNm': sellerReg.legalName,
        'TrdNm': sellerReg.tradeName ?? sellerReg.legalName,
        'Addr1': sellerReg.principalAddress,
        'Loc': 'City',
        'Pin': sellerReg.pincode,
        'Stcd': sellerReg.stateCode.toString().padLeft(2, '0'),
      },
      'BuyerDtls': {
        'Gstin': buyerAccount.partyGstin ?? 'URP',
        'LglNm': buyerAccount.name,
        'TrdNm': buyerAccount.alias ?? buyerAccount.name,
        'Pos': buyerPos,
        'Addr1': 'Commercial Area',
        'Loc': 'City',
        'Pin': 400001,
        'Stcd': buyerPos,
      },
      'ItemList': itemList,
      'ValDtls': {
        'AssVal': double.parse(totalAssVal.toStringAsFixed(2)),
        'CgstVal': double.parse(totalCgstVal.toStringAsFixed(2)),
        'SgstVal': double.parse(totalSgstVal.toStringAsFixed(2)),
        'IgstVal': double.parse(totalIgstVal.toStringAsFixed(2)),
        'CesVal': double.parse(totalCesVal.toStringAsFixed(2)),
        'RndOffAmt': double.parse(roundOff.toStringAsFixed(2)),
        'TotInvVal': totalInvVal,
      },
    };
  }
}
