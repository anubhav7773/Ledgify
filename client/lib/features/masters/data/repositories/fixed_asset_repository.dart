import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../../domain/models/fixed_asset_model.dart';

/// Repository managing the Fixed Asset Register and Schedule II Depreciation execution.
class FixedAssetRepository {
  final SupabaseClient _client;

  FixedAssetRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Fetches fixed assets for the active tenant
  Future<List<FixedAssetModel>> fetchFixedAssets({bool activeOnly = true}) async {
    return await executeSafely<List<FixedAssetModel>>(() async {
      var query = _client.from('fixed_assets').select('''
        id,
        business_id,
        asset_account_id,
        asset_name,
        category,
        purchase_date,
        original_cost,
        residual_value,
        useful_life_years,
        is_nesd,
        shift_working,
        itc_claimed_flag,
        accumulated_depreciation,
        is_disposed,
        disposal_date,
        created_at,
        accounts(name)
      ''');

      if (activeOnly) {
        query = query.eq('is_disposed', false);
      }

      final response = await query.order('purchase_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => FixedAssetModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Inserts a new fixed asset record into the database
  Future<FixedAssetModel> createFixedAsset(FixedAssetModel asset) async {
    return await executeSafely<FixedAssetModel>(() async {
      final insertData = asset.toJson();
      if (asset.id.isEmpty) {
        insertData.remove('id');
      }

      final response = await _client
          .from('fixed_assets')
          .insert(insertData)
          .select('''
            id,
            business_id,
            asset_account_id,
            asset_name,
            category,
            purchase_date,
            original_cost,
            residual_value,
            useful_life_years,
            is_nesd,
            shift_working,
            itc_claimed_flag,
            accumulated_depreciation,
            is_disposed,
            disposal_date,
            created_at,
            accounts(name)
          ''')
          .single();

      return FixedAssetModel.fromJson(response as Map<String, dynamic>);
    });
  }

  /// Calls the stored procedure to preview pro-rata depreciation for an asset
  Future<double> calculateDepreciationPreview(
    String assetId,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    return await executeSafely<double>(() async {
      final response = await _client.rpc(
        'calculate_asset_depreciation',
        params: {
          'p_asset_id': assetId,
          'p_period_start': periodStart.toIso8601String().split('T').first,
          'p_period_end': periodEnd.toIso8601String().split('T').first,
        },
      );

      return (response as num?)?.toDouble() ?? 0.00;
    });
  }

  /// Executes periodic depreciation run and posts the balanced Journal voucher
  Future<Map<String, dynamic>> executeDepreciationRun(
    String businessId,
    DateTime periodEnd,
  ) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final response = await _client.rpc(
        'post_periodic_depreciation_voucher',
        params: {
          'p_business_id': businessId,
          'p_period_end': periodEnd.toIso8601String().split('T').first,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    });
  }

  /// Disposes of an asset (records disposal date and marks is_disposed = true)
  Future<void> disposeAsset(String assetId, DateTime disposalDate) async {
    await executeSafely<void>(() async {
      await _client.from('fixed_assets').update({
        'is_disposed': true,
        'disposal_date': disposalDate.toIso8601String().split('T').first,
      }).eq('id', assetId);
    });
  }
}
