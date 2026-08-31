import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../data/repositories/draft_voucher_repository.dart';
import '../domain/models/extracted_invoice_payload.dart';
import 'ai_invoice_review_screen.dart';

/// Screen displaying the queue of AI-extracted bill and voice drafts pending review and posting.
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
      appBar: AppBar(
        title: const Text('AI Drafts Queue / ड्राफ्ट कतार', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrafts,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
            : _drafts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mark_chat_read_outlined, size: 48, color: LedgifyColors.debitGreen),
                        const SizedBox(height: 12),
                        const Text(
                          'No pending AI intake drafts!\nसभी ड्राफ्ट पोस्ट हो चुके हैं',
                          textAlign: TextAlign.center,
                          style: LedgifyTypography.bilingualLabel,
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

                      Color badgeBg = isHighConfidence ? LedgifyColors.debitGreenBg : LedgifyColors.creditRedBg;
                      Color badgeColor = isHighConfidence ? LedgifyColors.debitGreen : LedgifyColors.creditRed;
                      String badgeText = isHighConfidence ? 'Ready to Post' : 'Low Confidence';

                      if (isNewParty) {
                        badgeBg = LedgifyColors.warningOrange.withOpacity(0.15);
                        badgeColor = LedgifyColors.warningOrange;
                        badgeText = 'New Party';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: LedgifyColors.surfaceVariant),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
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
                                        style: LedgifyTypography.cardHeader.copyWith(fontSize: 16),
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
                                  style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate),
                                ),
                                const Divider(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Amount: ₹${draft.totalInvoiceValue.toStringAsFixed(2)}',
                                      style: LedgifyTypography.financialAmount.copyWith(
                                        fontSize: 16,
                                        color: LedgifyColors.primaryBlue,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: LedgifyColors.creditRed, size: 20),
                                          tooltip: 'Discard',
                                          onPressed: () => _deleteDraft(draftId),
                                        ),
                                        const Icon(Icons.chevron_right, color: LedgifyColors.secondarySlate),
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
