import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../../../masters/domain/models/account_model.dart';
import '../domain/models/einvoice_log_model.dart';
import '../domain/models/gst_registration_model.dart';

/// Repository orchestrating E-Invoice generation via FastAPI backend.
class EInvoiceRepository {
  EInvoiceRepository();

  /// Generates FORM GST INV-01 payload, computes SHA-256 IRN and signed QR code via FastAPI backend
  Future<EInvoiceLogModel> generateAndRegisterEInvoice({
    required String voucherId,
    required GstRegistrationModel sellerReg,
    required AccountModel buyerAccount,
    String? placeOfSupply,
  }) async {
    return await executeSafely<EInvoiceLogModel>(() async {
      final response = await ApiClient.post(
        '/gst/einvoice/generate',
        body: {'voucher_id': voucherId},
      );

      final data = response as Map<String, dynamic>;
      return EInvoiceLogModel(
        id: data['id'] ?? '',
        businessId: sellerReg.businessId,
        voucherId: voucherId,
        irn: data['irn_hash'] ?? '',
        ackNo: data['ack_number'] ?? '',
        ackDate: DateTime.tryParse(data['ack_date'] ?? '') ?? DateTime.now(),
        signedQrCode: data['signed_qr_code_data'] ?? '',
        status: EInvoiceStatus.generated,
        rawPayload: data,
        createdAt: DateTime.now(),
      );
    });
  }

  /// Fetches existing E-Invoice log for voucher
  Future<EInvoiceLogModel?> fetchEInvoiceLogByVoucherId(String voucherId) async {
    return await executeSafely<EInvoiceLogModel?>(() async {
      final response = await ApiClient.post(
        '/gst/einvoice/generate',
        body: {'voucher_id': voucherId},
      );
      final data = response as Map<String, dynamic>;
      return EInvoiceLogModel(
        id: data['id'] ?? '',
        businessId: 'BIZ-DEFAULT-01',
        voucherId: voucherId,
        irn: data['irn_hash'] ?? '',
        ackNo: data['ack_number'] ?? '',
        ackDate: DateTime.tryParse(data['ack_date'] ?? '') ?? DateTime.now(),
        signedQrCode: data['signed_qr_code_data'] ?? '',
        status: EInvoiceStatus.generated,
        rawPayload: data,
        createdAt: DateTime.now(),
      );
    });
  }
}
