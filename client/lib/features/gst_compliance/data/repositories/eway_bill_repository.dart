import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../domain/models/eway_bill_model.dart';

/// Repository managing E-Way Bill lifecycle, statutory validity calculations, and Part B vehicle updates.
class EWayBillRepository {
  final SupabaseClient _client;

  EWayBillRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Creates a new E-Way Bill and binds it to the voucher atomically via PostgreSQL stored procedure
  Future<EWayBillModel> createEWayBill(
    EWayBillModel ewb, {
    bool isOdc = false,
  }) async {
    return await executeSafely<EWayBillModel>(() async {
      final logId = await _client.rpc(
        'generate_eway_bill_record',
        params: {
          'p_business_id': ewb.businessId,
          'p_voucher_id': ewb.voucherId,
          'p_ewb_number': ewb.ewbNumber,
          'p_transporter_party_id': ewb.transporterPartyId,
          'p_vehicle_number': ewb.vehicleNumber,
          'p_distance_km': ewb.distanceKm,
          'p_part_a_data': ewb.partAData,
          'p_part_b_data': ewb.partBData,
          'p_is_odc': isOdc,
        },
      );

      final response = await _client
          .from('eway_bills')
          .select('''
            id,
            business_id,
            voucher_id,
            ewb_number,
            ewb_date,
            valid_upto,
            transporter_party_id,
            vehicle_number,
            distance_km,
            part_a_data,
            part_b_data,
            status,
            created_at,
            vouchers(voucher_number)
          ''')
          .eq('id', logId)
          .single();

      return EWayBillModel.fromJson(response as Map<String, dynamic>);
    });
  }

  /// Fetches paginated E-Way Bills with active filtering
  Future<List<EWayBillModel>> fetchEWayBills({
    String? status,
    int limit = 50,
  }) async {
    return await executeSafely<List<EWayBillModel>>(() async {
      var query = _client.from('eway_bills').select('''
        id,
        business_id,
        voucher_id,
        ewb_number,
        ewb_date,
        valid_upto,
        transporter_party_id,
        vehicle_number,
        distance_km,
        part_a_data,
        part_b_data,
        status,
        created_at,
        vouchers(voucher_number)
      ''');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false).limit(limit);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => EWayBillModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Checks if a sales voucher requires a mandatory E-Way Bill (Threshold > ₹50k)
  Future<Map<String, dynamic>> checkVoucherEwbRequirement(String voucherId) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final response = await _client.rpc(
        'check_voucher_ewb_requirement',
        params: {'p_voucher_id': voucherId},
      );

      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Updates Part B road vehicle details for an active movement
  Future<void> updatePartBVehicle({
    required String ewbId,
    required String newVehicleNumber,
    required String reason,
  }) async {
    await executeSafely<void>(() async {
      await _client.from('eway_bills').update({
        'vehicle_number': newVehicleNumber,
        'part_b_data': {
          'vehicleNo': newVehicleNumber,
          'updateReason': reason,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      }).eq('id', ewbId);
    });
  }

  /// Cancels an E-Way Bill
  Future<void> cancelEWayBill({
    required String ewbId,
    required String cancelReason,
  }) async {
    await executeSafely<void>(() async {
      await _client.from('eway_bills').update({
        'status': 'CANCELLED',
      }).eq('id', ewbId);
    });
  }
}
