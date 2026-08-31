import '../models/gstr_summary_model.dart';
import '../../data/repositories/gstr_repository.dart';

/// Service managing GSTR-3B monthly return aggregation and Section 49/49A/49B ITC set-off hierarchy.
class Gstr3bService {
  final GstrRepository _repository;

  Gstr3bService({GstrRepository? repository})
      : _repository = repository ?? GstrRepository();

  /// Fetches aggregated GSTR-3B table summaries
  Future<GstrSummaryModel> fetchGstr3bSummary(String returnPeriod) async {
    final payload = await _repository.fetchGstr3bReport(returnPeriod);
    return GstrSummaryModel.fromGstr3bJson(payload);
  }

  /// Calculates statutory ITC set-off according to Sections 49, 49A, and 49B of the CGST Act
  static Map<String, dynamic> calculateStatutoryItcSetOff({
    required double liabilityIgst,
    required double liabilityCgst,
    required double liabilitySgst,
    required double creditIgst,
    required double creditCgst,
    required double creditSgst,
  }) {
    double remLiabIgst = liabilityIgst;
    double remLiabCgst = liabilityCgst;
    double remLiabSgst = liabilitySgst;

    double remCreditIgst = creditIgst;
    double remCreditCgst = creditCgst;
    double remCreditSgst = creditSgst;

    // Step 1: Utilize IGST Credit against IGST liability first
    final double igstAgainstIgst = remCreditIgst > remLiabIgst ? remLiabIgst : remCreditIgst;
    remLiabIgst -= igstAgainstIgst;
    remCreditIgst -= igstAgainstIgst;

    // Step 2: Utilize remaining IGST Credit against CGST liability
    final double igstAgainstCgst = remCreditIgst > remLiabCgst ? remLiabCgst : remCreditIgst;
    remLiabCgst -= igstAgainstCgst;
    remCreditIgst -= igstAgainstCgst;

    // Step 3: Utilize remaining IGST Credit against SGST liability
    final double igstAgainstSgst = remCreditIgst > remLiabSgst ? remLiabSgst : remCreditIgst;
    remLiabSgst -= igstAgainstSgst;
    remCreditIgst -= igstAgainstSgst;

    // Step 4: Utilize CGST Credit against remaining CGST liability, then remaining IGST
    final double cgstAgainstCgst = remCreditCgst > remLiabCgst ? remLiabCgst : remCreditCgst;
    remLiabCgst -= cgstAgainstCgst;
    remCreditCgst -= cgstAgainstCgst;

    final double cgstAgainstIgst = remCreditCgst > remLiabIgst ? remLiabIgst : remCreditCgst;
    remLiabIgst -= cgstAgainstIgst;
    remCreditCgst -= cgstAgainstIgst;

    // Step 5: Utilize SGST Credit against remaining SGST liability, then remaining IGST
    final double sgstAgainstSgst = remCreditSgst > remLiabSgst ? remLiabSgst : remCreditSgst;
    remLiabSgst -= sgstAgainstSgst;
    remCreditSgst -= sgstAgainstSgst;

    final double sgstAgainstIgst = remCreditSgst > remLiabIgst ? remLiabIgst : remCreditSgst;
    remLiabIgst -= sgstAgainstIgst;
    remCreditSgst -= sgstAgainstIgst;

    final double totalCashPayable = remLiabIgst + remLiabCgst + remLiabSgst;

    return {
      'set_off': {
        'igst_against_igst': igstAgainstIgst,
        'igst_against_cgst': igstAgainstCgst,
        'igst_against_sgst': igstAgainstSgst,
        'cgst_against_cgst': cgstAgainstCgst,
        'cgst_against_igst': cgstAgainstIgst,
        'sgst_against_sgst': sgstAgainstSgst,
        'sgst_against_igst': sgstAgainstIgst,
      },
      'cash_payable': {
        'igst': double.parse(remLiabIgst.toStringAsFixed(2)),
        'cgst': double.parse(remLiabCgst.toStringAsFixed(2)),
        'sgst': double.parse(remLiabSgst.toStringAsFixed(2)),
        'total': double.parse(totalCashPayable.toStringAsFixed(2)),
      },
      'closing_credit_balance': {
        'igst': double.parse(remCreditIgst.toStringAsFixed(2)),
        'cgst': double.parse(remCreditCgst.toStringAsFixed(2)),
        'sgst': double.parse(remCreditSgst.toStringAsFixed(2)),
      }
    };
  }
}
