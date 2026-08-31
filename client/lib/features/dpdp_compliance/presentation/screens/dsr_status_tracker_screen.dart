import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/dpdp_data_request_model.dart';
import '../../domain/services/dpdp_dsr_service.dart';

/// Screen tracking past Data Principal Rights (DSR) requests and download links.
class DsrStatusTrackerScreen extends StatefulWidget {
  final DpdpDsrService? dsrService;

  const DsrStatusTrackerScreen({super.key, this.dsrService});

  @override
  State<DsrStatusTrackerScreen> createState() => _DsrStatusTrackerScreenState();
}

class _DsrStatusTrackerScreenState extends State<DsrStatusTrackerScreen> {
  late final DpdpDsrService _dsrService;
  List<DpdpDataRequestModel> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dsrService = widget.dsrService ?? DpdpDsrService();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final list = await _dsrService.fetchMyRequests();
    if (mounted) {
      setState(() {
        _requests = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DSR Request Tracker / अनुरोध स्थिति', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _requests.isEmpty
              ? const Center(
                  child: Text(
                    'No Data Principal requests filed yet.\nकोई अनुरोध इतिहास नहीं मिला।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppColors.standardPadding),
                    itemCount: _requests.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final req = _requests[index];

                      final isDone = req.status == 'COMPLETED';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.surfaceVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      req.typeLabelBilingual,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDone ? AppColors.debitGreenLight : AppColors.warningAmberLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      req.status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDone ? AppColors.debitGreen : AppColors.warningAmber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Text(
                                'Requested: ${DateFormatter.formatVoucherDate(req.requestedAt)}' +
                                    (req.completedAt != null ? ' • Completed: ${DateFormatter.formatVoucherDate(req.completedAt!)}' : ''),
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                              if (req.requestDetails.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Details: ${req.requestDetails}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
