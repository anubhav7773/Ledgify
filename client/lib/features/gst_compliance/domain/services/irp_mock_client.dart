import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Client simulating Invoice Registration Portal (IRP) authentication and generation handshakes.
/// Produces deterministic 64-character SHA-256 IRNs and signed QR code JWTs for sandbox/development.
class IrpMockClient {
  /// Simulates registration of an invoice payload with the IRP
  static Future<Map<String, dynamic>> registerInvoice(Map<String, dynamic> inv01Payload) async {
    // Artificial network latency simulation
    await Future.delayed(const Duration(milliseconds: 600));

    final sellerDtls = inv01Payload['SellerDtls'] as Map<String, dynamic>;
    final docDtls = inv01Payload['DocDtls'] as Map<String, dynamic>;
    final valDtls = inv01Payload['ValDtls'] as Map<String, dynamic>;
    final buyerDtls = inv01Payload['BuyerDtls'] as Map<String, dynamic>;

    final String sellerGstin = sellerDtls['Gstin'] as String;
    final String docType = docDtls['Typ'] as String;
    final String docNo = docDtls['No'] as String;
    final String docDt = docDtls['Dt'] as String;
    final double totVal = (valDtls['TotInvVal'] as num).toDouble();
    final String buyerGstin = buyerDtls['Gstin'] as String;

    // Financial Year calculation
    final parts = docDt.split('/');
    final int year = int.parse(parts.last);
    final String finYear = '$year-${year + 1}';

    // 1. Generate 64-character SHA-256 IRN
    final String rawIrnString = '$sellerGstin:$finYear:$docType:$docNo';
    final String irn = sha256.convert(utf8.encode(rawIrnString)).toString();

    // 2. Generate Ack Number & Timestamp
    final String ackNo = '1126${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final DateTime ackDate = DateTime.now();

    // 3. Generate Signed QR Code Data
    final qrData = {
      'irn': irn,
      'sellerGstin': sellerGstin,
      'buyerGstin': buyerGstin,
      'docNo': docNo,
      'docDt': docDt,
      'totVal': totVal,
      'itemCnt': (inv01Payload['ItemList'] as List).length,
      'mainHsn': (inv01Payload['ItemList'] as List).first['HsnCd'],
      'ackNo': ackNo,
      'ackDt': ackDate.toIso8601String(),
    };
    final String signedQrCode = base64Url.encode(utf8.encode(jsonEncode(qrData)));

    return {
      'status': 'SUCCESS',
      'irn': irn,
      'ack_no': ackNo,
      'ack_date': ackDate.toIso8601String(),
      'signed_invoice': jsonEncode(inv01Payload),
      'signed_qr_code': signedQrCode,
      'irp_response': {
        'Success': 'Y',
        'AckNo': ackNo,
        'AckDt': ackDate.toIso8601String(),
        'Irn': irn,
        'Status': 'ACT',
        'SignedInvoice': 'JWT_SIMULATED_HEADER.${base64Url.encode(utf8.encode(jsonEncode(inv01Payload)))}.JWT_SIMULATED_SIG',
        'SignedQRCode': signedQrCode,
      },
    };
  }

  /// Simulates cancellation of an existing IRN
  static Future<Map<String, dynamic>> cancelInvoice({
    required String irn,
    required String cancelReason,
    String remarks = 'Cancelled by user',
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return {
      'status': 'SUCCESS',
      'irn': irn,
      'cancel_date': DateTime.now().toIso8601String(),
      'cancel_reason': cancelReason,
      'remarks': remarks,
    };
  }
}
