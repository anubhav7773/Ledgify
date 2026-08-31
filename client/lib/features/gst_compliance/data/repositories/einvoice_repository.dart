import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../vouchers/data/repositories/voucher_repository.dart';
import '../domain/models/einvoice_log_model.dart';
import '../domain/models/gst_registration_model.dart';
import '../domain/services/einvoice_payload_generator.dart';
import '../domain/services/irp_mock_client.dart';

/// Repository orchestrating E-Invoice generation, IRP transmission, and database audit logging.
class EInvoiceRepository {
  final SupabaseClient _client;
  final VoucherRepository _voucherRepository;

  EInvoiceRepository({
    SupabaseClient? client,
    VoucherRepository? voucherRepository,
  })  : _client = client ?? SupabaseClientService.client,
        _voucherRepository = voucherRepository ?? VoucherRepository();

  /// Generates FORM GST INV-01 payload, submits to IRP, and commits IRN and QR code to PostgreSQL
  Future<EInvoiceLogModel> generateAndRegisterEInvoice({
    required String voucherId,
    required GstRegistrationModel sellerReg,
    required AccountModel buyerAccount,
    String? placeOfSupply,
  }) async {
    return await executeSafely<EInvoiceLogModel>(() async {
      // 1. Validate voucher eligibility via PostgreSQL function
      final validationRes = await _client.rpc(
        'validate_voucher_for_einvoice',
        params: {'p_voucher_id': voucherId},
      );

      final bool isValid = (validationRes as Map)['is_valid'] as bool? ?? false;
      if (!isValid) {
        final List<dynamic> errors = validationRes['errors'] as List<dynamic>? ?? [];
        throw StatutoryComplianceFailure(
          message: 'Voucher failed statutory E-Invoice validation: ${errors.join(", ")}',
        );
      }

      // 2. Fetch full voucher details
      final voucher = await _voucherRepository.fetchVoucherById(voucherId);

      // 3. Generate FORM GST INV-01 Version 1.1 JSON Payload
      final payload = EInvoicePayloadGenerator.generateInv01Payload(
        voucher: voucher,
        sellerReg: sellerReg,
        buyerAccount: buyerAccount,
        placeOfSupply: placeOfSupply,
      );

      // 4. Submit to IRP (via simulated/real client)
      final irpResponse = await IrpMockClient.registerInvoice(payload);

      // 5. Commit response to PostgreSQL atomically
      final logId = await _client.rpc(
        'record_einvoice_irp_response',
        params: {
          'p_business_id': sellerReg.businessId,
          'p_voucher_id': voucherId,
          'p_irn': irpResponse['irn'],
          'p_ack_no': irpResponse['ack_no'],
          'p_ack_date': irpResponse['ack_date'],
          'p_signed_invoice': irpResponse['signed_invoice'],
          'p_signed_qr_code': irpResponse['signed_qr_code'],
          'p_payload_json': payload,
          'p_irp_response': irpResponse['irp_response'],
          'p_status': 'SUCCESS',
        },
      );

      return EInvoiceLogModel(
        id: logId.toString(),
        businessId: sellerReg.businessId,
        voucherId: voucherId,
        irn: irpResponse['irn'] as String,
        ackNo: irpResponse['ack_no'] as String,
        ackDate: DateTime.parse(irpResponse['ack_date'] as String),
        signedInvoice: irpResponse['signed_invoice'] as String?,
        signedQrCode: irpResponse['signed_qr_code'] as String,
        payloadJson: payload,
        irpResponse: irpResponse['irp_response'] as Map<String, dynamic>,
        status: 'SUCCESS',
      );
    });
  }

  /// Fetches the E-Invoice log for a voucher
  Future<EInvoiceLogModel?> fetchEInvoiceLogByVoucher(String voucherId) async {
    return await executeSafely<EInvoiceLogModel?>(() async {
      final response = await _client
          .from('einvoice_logs')
          .select()
          .eq('voucher_id', voucherId)
          .order('created_at', ascending: false)
          .limit(1);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return null;

      return EInvoiceLogModel.fromJson(data.first as Map<String, dynamic>);
    });
  }

  /// Submits cancellation request to IRP
  Future<void> cancelEInvoice({
    required String voucherId,
    required String irn,
    required String cancelReason,
  }) async {
    await executeSafely<void>(() async {
      await IrpMockClient.cancelInvoice(irn: irn, cancelReason: cancelReason);

      await _client
          .from('einvoice_logs')
          .update({'status': 'CANCELLED'})
          .eq('voucher_id', voucherId);

      await _client
          .from('vouchers')
          .update({'is_cancelled': true})
          .eq('id', voucherId);
    });
  }
}
