import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../models/account_model.dart';
import '../models/fuzzy_match_result.dart';
import 'quick_create_ledger_bottom_sheet.dart';

/// Modal bottom sheet for user review when fuzzy resolution yields ambiguous candidate matches (0.50 <= Score < 0.85).
class FuzzyCandidatePickerSheet extends StatelessWidget {
  final String queryName;
  final String? queryGstin;
  final List<FuzzyMatchResult> candidates;
  final String? businessId;

  const FuzzyCandidatePickerSheet({
    super.key,
    required this.queryName,
    this.queryGstin,
    required this.candidates,
    this.businessId,
  });

  static Future<FuzzyMatchResult?> show(
    BuildContext context, {
    required String queryName,
    String? queryGstin,
    required List<FuzzyMatchResult> candidates,
    String? businessId,
  }) {
    return showModalBottomSheet<FuzzyMatchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FuzzyCandidatePickerSheet(
        queryName: queryName,
        queryGstin: queryGstin,
        candidates: candidates,
        businessId: businessId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Matching Ledger / सही खाता चुनें', style: LedgifyTypography.cardHeader),
                  Text('Searched: "$queryName"', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 16),

          // Candidate list
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text('No existing ledgers matched closely.', style: LedgifyTypography.bilingualLabel),
              ),
            )
          else
            ...candidates.map((cand) {
              final isHigh = cand.compositeScore >= 0.75;
              final badgeBg = isHigh ? LedgifyColors.debitGreenBg : LedgifyColors.warningOrange.withOpacity(0.15);
              final badgeColor = isHigh ? LedgifyColors.debitGreen : LedgifyColors.warningOrange;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: LedgifyColors.surfaceVariant),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Text(cand.entityName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text('${cand.groupName} • ${cand.primaryClassification}', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${cand.matchPercentage}% Match',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, cand),
                ),
              );
            }),

          const SizedBox(height: 12),

          // Create New Ledger CTA (48dp Touch Target)
          SizedBox(
            height: LedgifyColors.minTouchTargetSize,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: LedgifyColors.primaryBlue,
                side: const BorderSide(color: LedgifyColors.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('+ Create New Ledger / नया खाता बनाएं', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () async {
                Navigator.pop(context); // Close picker
                final AccountModel? created = await QuickCreateLedgerBottomSheet.show(
                  context,
                  initialName: queryName,
                  initialGstin: queryGstin,
                  businessId: businessId,
                );

                if (created != null && context.mounted) {
                  // Pass back synthetic match result
                  final syntheticMatch = FuzzyMatchResult(
                    entityId: created.id,
                    entityName: created.name,
                    primaryClassification: created.primaryClassification,
                    groupName: created.groupName,
                    compositeScore: 1.0,
                    matchReason: 'NEWLY_CREATED',
                  );
                  Navigator.pop(context, syntheticMatch);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
