import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/balance_sheet_model.dart';
import '../models/cash_flow_model.dart';
import '../models/profit_and_loss_model.dart';
import '../models/trial_balance_model.dart';

/// Domain service invoking database procedures to aggregate Trial Balance, P&L, Balance Sheet, and Cash Flow reports.
class FinancialReportingService {
  final SupabaseClient _client;

  FinancialReportingService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Aggregates real-time multi-column Trial Balance
  Future<TrialBalanceReportModel> fetchTrialBalance({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await executeSafely<TrialBalanceReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_trial_balance',
        params: {
          'p_business_id': businessId,
          'p_from_date': fromDate.toIso8601String().split('T').first,
          'p_to_date': toDate.toIso8601String().split('T').first,
        },
      );

      return TrialBalanceReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Aggregates Trading and Profit & Loss Statement
  Future<ProfitAndLossReportModel> fetchProfitAndLoss({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await executeSafely<ProfitAndLossReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_profit_and_loss',
        params: {
          'p_business_id': businessId,
          'p_from_date': fromDate.toIso8601String().split('T').first,
          'p_to_date': toDate.toIso8601String().split('T').first,
        },
      );

      return ProfitAndLossReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Aggregates Schedule III compliant Balance Sheet as of a specific date
  Future<BalanceSheetReportModel> fetchBalanceSheet({
    required DateTime asOfDate,
  }) async {
    return await executeSafely<BalanceSheetReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_balance_sheet',
        params: {
          'p_business_id': businessId,
          'p_as_of_date': asOfDate.toIso8601String().split('T').first,
        },
      );

      return BalanceSheetReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Aggregates AS 3 Direct Method Cash Flow statement
  Future<CashFlowReportModel> fetchCashFlow({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await executeSafely<CashFlowReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_cash_flow_statement',
        params: {
          'p_business_id': businessId,
          'p_from_date': fromDate.toIso8601String().split('T').first,
          'p_to_date': toDate.toIso8601String().split('T').first,
        },
      );

      return CashFlowReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }
}
