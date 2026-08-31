import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/stock_item_match_result.dart';
import '../models/stock_item_model.dart';

/// Service managing inventory fuzzy resolution, HSN code auto-linking, and quick stock item creation.
class InventoryMatchingService {
  final SupabaseClient _client;

  InventoryMatchingService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Resolves scanned item description against stock items with HSN validation
  Future<List<StockItemMatchResult>> matchStockItem({
    required String itemName,
    String? extractedHsn,
  }) async {
    return await executeSafely<List<StockItemMatchResult>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'resolve_stock_item_and_hsn',
        params: {
          'p_business_id': businessId,
          'p_item_query': itemName.trim(),
          'p_extracted_hsn': extractedHsn?.trim(),
        },
      );

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => StockItemMatchResult.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Quickly creates and persists a new stock item directly during OCR review
  Future<StockItemModel> quickCreateItem({
    required String name,
    required String hsnCode,
    required double gstRate,
    String uqc = 'NOS',
  }) async {
    return await executeSafely<StockItemModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final newId = await _client.rpc(
        'quick_create_stock_item',
        params: {
          'p_business_id': businessId,
          'p_name': name.trim(),
          'p_hsn_sac_code': hsnCode.trim(),
          'p_gst_rate_slab': gstRate,
          'p_uqc': uqc.toUpperCase().trim(),
        },
      ) as String;

      return StockItemModel(
        id: newId,
        businessId: businessId,
        name: name.trim(),
        hsnSacCode: hsnCode.trim(),
        gstRateSlab: gstRate,
        uqc: uqc.toUpperCase().trim(),
      );
    });
  }

  /// Converts quantities across standard units
  static double normalizeUnitConversion(double quantity, String fromUnit, String toUnit) {
    final from = fromUnit.toUpperCase().trim();
    final to = toUnit.toUpperCase().trim();

    if (from == to) return quantity;

    if (from == 'KGS' && to == 'GMS') return quantity * 1000.0;
    if (from == 'GMS' && to == 'KGS') return quantity / 1000.0;
    if (from == 'MTR' && to == 'CMS') return quantity * 100.0;
    if (from == 'CMS' && to == 'MTR') return quantity / 100.0;

    return quantity;
  }
}
