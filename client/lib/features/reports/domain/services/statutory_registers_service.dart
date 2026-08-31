import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/day_book_model.dart';
import '../models/ledger_statement_model.dart';
import '../models/stock_summary_model.dart';
import '../models/trade_register_model.dart';

/// Domain service managing Day Book, Sales/Purchase Registers, Ledger Statements, and Stock Summary reports.
class StatutoryRegistersService {
  final SupabaseClient _client;

  StatutoryRegistersService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Fetches chronological daily transactions for Day Book
  Future<DayBookReportModel> fetchDayBook({
    required DateTime date,
    String? voucherTypeId,
  }) async {
    return await executeSafely<DayBookReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_day_book',
        params: {
          'p_business_id': businessId,
          'p_date': date.toIso8601String().split('T').first,
          'p_voucher_type_id': voucherTypeId,
        },
      );

      return DayBookReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Fetches Sales Register
  Future<TradeRegisterReportModel> fetchSalesRegister({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await _fetchTradeRegister('SALES', fromDate, toDate);
  }

  /// Fetches Purchase Register
  Future<TradeRegisterReportModel> fetchPurchaseRegister({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await _fetchTradeRegister('PURCHASE', fromDate, toDate);
  }

  Future<TradeRegisterReportModel> _fetchTradeRegister(
    String registerType,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    return await executeSafely<TradeRegisterReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_trade_register',
        params: {
          'p_business_id': businessId,
          'p_register_type': registerType,
          'p_from_date': fromDate.toIso8601String().split('T').first,
          'p_to_date': toDate.toIso8601String().split('T').first,
        },
      );

      return TradeRegisterReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Fetches itemized ledger statement with continuous running balance
  Future<LedgerStatementReportModel> fetchLedgerStatement({
    required String accountId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await executeSafely<LedgerStatementReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_ledger_statement',
        params: {
          'p_business_id': businessId,
          'p_account_id': accountId,
          'p_from_date': fromDate.toIso8601String().split('T').first,
          'p_to_date': toDate.toIso8601String().split('T').first,
        },
      );

      return LedgerStatementReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Fetches Stock Valuation Summary
  Future<StockSummaryReportModel> fetchStockSummary({
    required DateTime asOfDate,
    String? groupId,
    String? godownId,
  }) async {
    return await executeSafely<StockSummaryReportModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_stock_summary',
        params: {
          'p_business_id': businessId,
          'p_as_of_date': asOfDate.toIso8601String().split('T').first,
          'p_group_id': groupId,
          'p_godown_id': godownId,
        },
      );

      return StockSummaryReportModel.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }
}
