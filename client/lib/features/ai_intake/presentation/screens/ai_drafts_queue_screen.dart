import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../data/repositories/draft_voucher_repository.dart';
import '../domain/models/extracted_invoice_payload.dart';
import 'ai_invoice_review_screen.dart';
import 'document_scanner_screen.dart';

/// Screen displaying the queue of AI-extracted bill and voice drafts pending review (Google Stitch UI).
class AiDraftsQueueScreen extends StatefulWidget {
  final DraftVoucherRepository? repository;
  final String? businessId;

  const AiDraftsQueueScreen({
    super.key,
    this.repository,
    this.businessId,
  });

  @override
  State<AiDraftsQueueScreen> createState() => _AiDraftsQueueScreenState();
}

class _AiDraftsQueueScreenState extends State<AiDraftsQueueScreen> {
  late final DraftVoucherRepository _repository;
  bool _isLoading = true;
  Map<String, ExtractedInvoicePayload> _drafts = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DraftVoucherRepository();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    try {
      final drafts = await _repository.getPendingDrafts();
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    await _repository.deleteDraft(draftId);
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('AI Drafts Queue', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: _loadDrafts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Scan Bill', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentScannerScreen(businessId: widget.businessId),
            ),
          );
          _loadDrafts();
        },
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _drafts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.debitGreenLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded, size: 44, color: AppColors.debitGreen),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'All Caught Up!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'No pending AI intake drafts to review.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _drafts.length,
                    itemBuilder: (context, index) {
                      final draftId = _drafts.keys.elementAt(index);
                      final draft = _drafts[draftId]!;

                      final bool isHighConfidence = draft.confidenceScore >= 0.85;
                      final bool isNewParty = draft.sellerGstin.isEmpty;

                      Color badgeBg = isHighConfidence ? AppColors.debitGreenLight : AppColors.creditRedLight;
                      Color badgeColor = isHighConfidence ? AppColors.debitGreen : AppColors.creditRed;
                      String badgeText = isHighConfidence ? 'Ready to Post' : 'Low Confidence';

                      if (isNewParty) {
                        badgeBg = AppColors.warningAmberLight;
                        badgeColor = AppColors.warningAmber;
                        badgeText = 'New Party';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AiInvoiceReviewScreen(
                                  extractedPayload: draft,
                                  businessId: widget.businessId,
                                ),
                              ),
                            );
                            _loadDrafts();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        draft.sellerName,
                                        style: AppTypography.cardHeader.copyWith(fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bill #${draft.documentNumber} • Date: ${draft.documentDate}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const Divider(height: 18),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹${draft.totalInvoiceValue.toStringAsFixed(2)}',
                                      style: AppTypography.currencyText.copyWith(
                                        fontSize: 17,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.creditRed, size: 20),
                                          tooltip: 'Discard Draft',
                                          onPressed: () => _deleteDraft(draftId),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
