import '../domain/models/balance_sheet_model.dart';
import '../domain/models/cash_flow_model.dart';
import '../domain/models/profit_and_loss_model.dart';
import '../domain/models/trial_balance_model.dart';
import '../domain/services/financial_reporting_service.dart';

/// Repository managing financial reports with caching support.
class ReportsRepository {
  final FinancialReportingService _reportingService;

  ReportsRepository({FinancialReportingService? reportingService})
      : _reportingService = reportingService ?? FinancialReportingService();

  Future<TrialBalanceReportModel> getTrialBalance({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await _reportingService.fetchTrialBalance(fromDate: fromDate, toDate: toDate);
  }

  Future<ProfitAndLossReportModel> getProfitAndLoss({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await _reportingService.fetchProfitAndLoss(fromDate: fromDate, toDate: toDate);
  }

  Future<BalanceSheetReportModel> getBalanceSheet({
    required DateTime asOfDate,
  }) async {
    return await _reportingService.fetchBalanceSheet(asOfDate: asOfDate);
  }

  Future<CashFlowReportModel> getCashFlow({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await _reportingService.fetchCashFlow(fromDate: fromDate, toDate: toDate);
  }
}
