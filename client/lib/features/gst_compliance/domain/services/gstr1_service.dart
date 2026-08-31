import 'dart:convert';
import '../models/gstr_summary_model.dart';
import '../../data/repositories/gstr_repository.dart';

/// Service managing GSTR-1 payload aggregation and export verification.
class Gstr1Service {
  final GstrRepository _repository;

  Gstr1Service({GstrRepository? repository})
      : _repository = repository ?? GstrRepository();

  /// Fetches and converts GSTR-1 summary for a period
  Future<GstrSummaryModel> fetchGstr1Summary(String returnPeriod) async {
    final payload = await _repository.fetchGstr1Report(returnPeriod);
    return GstrSummaryModel.fromGstr1Json(payload);
  }

  /// Exports formatted GSTR-1 JSON string matching GSTN offline tool schema
  Future<String> exportGstr1JsonPayload(String returnPeriod) async {
    final payload = await _repository.fetchGstr1Report(returnPeriod);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
