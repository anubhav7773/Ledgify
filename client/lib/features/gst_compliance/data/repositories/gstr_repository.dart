import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/gst_compliance/domain/models/ims_entry_model.dart';

/// Repository managing GSTR-1, GSTR-3B return payload generation and IMS reconciliation records.
class GstrRepository {
  GstrRepository();

  /// Invokes FastAPI backend to generate GSTR-1 outward supply JSON payload
  Future<Map<String, dynamic>> fetchGstr1Report(String returnPeriod) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final response = await ApiClient.get(
        '/gst/gstr1-summary',
        queryParams: {'return_period': returnPeriod},
      );
      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Invokes FastAPI backend to aggregate GSTR-3B Table 3.1 & Table 4 summaries
  Future<Map<String, dynamic>> fetchGstr3bReport(String returnPeriod) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final response = await ApiClient.get(
        '/gst/gstr3b-summary',
        queryParams: {'return_period': returnPeriod},
      );
      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Fetches IMS inward supplier invoices queue from FastAPI backend
  Future<List<ImsEntryModel>> fetchImsInwardSupplies(
    String returnPeriod, {
    String? filterStatus,
  }) async {
    return await executeSafely<List<ImsEntryModel>>(() async {
      final response = await ApiClient.get('/gst/ims-portal');
      final list = response as List<dynamic>;

      return list
          .map((json) {
            final data = json as Map<String, dynamic>;
            return ImsEntryModel(
              id: data['id'] ?? '',
              businessId: 'BIZ-DEFAULT-01',
              supplierGstin: data['supplier_gstin'] ?? '',
              supplierName: data['supplier_name'] ?? '',
              invoiceNumber: data['invoice_number'] ?? '',
              invoiceDate: DateTime.tryParse(data['invoice_date'] ?? '') ?? DateTime.now(),
              invoiceValue: (data['total_value'] as num?)?.toDouble() ?? 0.0,
              taxableValue: (data['taxable_value'] as num?)?.toDouble() ?? 0.0,
              igst: (data['igst'] as num?)?.toDouble() ?? 0.0,
              cgst: (data['cgst'] as num?)?.toDouble() ?? 0.0,
              sgst: (data['sgst'] as num?)?.toDouble() ?? 0.0,
              cess: 0.0,
              imsStatus: data['action_status'] ?? 'PENDING',
              createdAt: DateTime.now(),
            );
          })
          .toList();
    });
  }

  /// Updates recipient action on IMS inward invoice via FastAPI backend
  Future<void> updateImsStatus(
    String imsEntryId,
    String action,
    String? remarks,
  ) async {
    await executeSafely<void>(() async {
      await ApiClient.post(
        '/gst/ims-portal/action',
        body: {
          'invoice_id': imsEntryId,
          'action_status': action,
          if (remarks != null) 'remarks': remarks,
        },
      );
    });
  }
}
