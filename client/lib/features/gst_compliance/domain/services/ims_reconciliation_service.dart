import '../../data/repositories/gstr_repository.dart';
import '../models/ims_entry_model.dart';

/// Service managing Inward Supplies Management (IMS) tri-state action flow (ACCEPT, REJECT, PENDING).
class ImsReconciliationService {
  final GstrRepository _repository;

  ImsReconciliationService({GstrRepository? repository})
      : _repository = repository ?? GstrRepository();

  /// Submits an IMS decision on an inward supplier invoice
  Future<void> submitAction(
    String imsId,
    String action, {
    String? remarks,
  }) async {
    await _repository.updateImsStatus(imsId, action, remarks);
  }

  /// Fetches counts of IMS invoices grouped by tri-state status
  Future<Map<String, int>> getActionCounts(String returnPeriod) async {
    final entries = await _repository.fetchImsInwardSupplies(returnPeriod);
    int pending = 0;
    int accepted = 0;
    int rejected = 0;

    for (final entry in entries) {
      if (entry.imsStatus == 'ACCEPTED') {
        accepted++;
      } else if (entry.imsStatus == 'REJECTED') {
        rejected++;
      } else {
        pending++;
      }
    }

    return {
      'PENDING': pending,
      'ACCEPTED': accepted,
      'REJECTED': rejected,
      'TOTAL': entries.length,
    };
  }
}
