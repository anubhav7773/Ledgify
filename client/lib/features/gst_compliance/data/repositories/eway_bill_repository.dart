import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/gst_compliance/domain/models/eway_bill_model.dart';

/// Repository managing E-Way Bill lifecycle via FastAPI backend.
class EWayBillRepository {
  EWayBillRepository();

  /// Creates a new E-Way Bill via FastAPI backend
  Future<EWayBillModel> createEWayBill(
    EWayBillModel ewb, {
    bool isOdc = false,
  }) async {
    return await executeSafely<EWayBillModel>(() async {
      final response = await ApiClient.post(
        '/gst/eway-bills',
        body: {
          'voucher_id': ewb.voucherId,
          'distance_km': ewb.distanceKm,
          'is_odc': isOdc,
          'vehicle_number': ewb.vehicleNumber,
          'transporter_name': ewb.vehicleNumber != null ? 'SafeXpress Roadways' : null,
        },
      );

      final data = response as Map<String, dynamic>;
      return EWayBillModel(
        id: data['id'] ?? '',
        businessId: data['business_id'] ?? ewb.businessId,
        voucherId: data['voucher_id'] ?? ewb.voucherId,
        voucherNumber: 'VCH-EWB-ACTIVE',
        ewbNumber: data['ewb_number'] ?? '',
        ewbDate: DateTime.tryParse(data['ewb_date'] ?? '') ?? DateTime.now(),
        validUpto: DateTime.tryParse(data['valid_upto'] ?? '') ?? DateTime.now().add(const Duration(days: 2)),
        vehicleNumber: data['vehicle_number'],
        distanceKm: (data['distance_km'] as num?)?.toDouble() ?? ewb.distanceKm,
        status: data['status'] ?? 'ACTIVE',
        partAData: ewb.partAData,
        partBData: ewb.partBData,
        createdAt: DateTime.now(),
      );
    });
  }

  /// Fetches E-Way Bills from FastAPI backend
  Future<List<EWayBillModel>> fetchEWayBills({
    String? statusFilter,
    int limit = 50,
  }) async {
    return await executeSafely<List<EWayBillModel>>(() async {
      final response = await ApiClient.get('/gst/eway-bills');
      final list = response as List<dynamic>;

      return list
          .map((json) {
            final data = json as Map<String, dynamic>;
            return EWayBillModel(
              id: data['id'] ?? '',
              businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
              voucherId: data['voucher_id'] ?? '',
              voucherNumber: 'VCH-${data['voucher_id'] ?? 'INV'}',
              ewbNumber: data['ewb_number'] ?? '',
              ewbDate: DateTime.tryParse(data['ewb_date'] ?? '') ?? DateTime.now(),
              validUpto: DateTime.tryParse(data['valid_upto'] ?? '') ?? DateTime.now().add(const Duration(days: 2)),
              vehicleNumber: data['vehicle_number'],
              distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 100.0,
              partAData: const {},
              partBData: const {},
              status: data['status'] ?? 'ACTIVE',
              createdAt: DateTime.now(),
            );
          })
          .toList();
    });
  }

  /// Updates Part B vehicle registration number
  Future<void> updatePartBVehicle({
    required String ewbId,
    required String newVehicleNumber,
    required String reason,
  }) async {
    await executeSafely<void>(() async {
      await ApiClient.post(
        '/gst/eway-bills/$ewbId/update-part-b',
        body: {
          'new_vehicle_number': newVehicleNumber,
          'reason': reason,
        },
      );
    });
  }
}
