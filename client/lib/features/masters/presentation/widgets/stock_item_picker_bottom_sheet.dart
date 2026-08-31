import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../models/stock_item_match_result.dart';
import '../models/stock_item_model.dart';
import 'quick_create_stock_item_dialog.dart';

/// Modal bottom sheet for user disambiguation of inventory stock items during OCR intake.
class StockItemPickerBottomSheet extends StatelessWidget {
  final String rawItemDescription;
  final String? rawHsn;
  final double? rawGstRate;
  final List<StockItemMatchResult> candidates;
  final String? businessId;

  const StockItemPickerBottomSheet({
    super.key,
    required this.rawItemDescription,
    this.rawHsn,
    this.rawGstRate,
    required this.candidates,
    this.businessId,
  });

  static Future<StockItemMatchResult?> show(
    BuildContext context, {
    required String rawItemDescription,
    String? rawHsn,
    double? rawGstRate,
    required List<StockItemMatchResult> candidates,
    String? businessId,
  }) {
    return showModalBottomSheet<StockItemMatchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StockItemPickerBottomSheet(
        rawItemDescription: rawItemDescription,
        rawHsn: rawHsn,
        rawGstRate: rawGstRate,
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
                  const Text('Map Inventory Item / वस्तु चुनें', style: LedgifyTypography.cardHeader),
                  Text('Scanned: "$rawItemDescription"', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 16),

          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text('No stock items matched.', style: LedgifyTypography.bilingualLabel),
              ),
            )
          else
            ...candidates.map((item) {
              final isHigh = item.compositeScore >= 0.75;
              final badgeBg = isHigh ? LedgifyColors.debitGreenBg : LedgifyColors.warningOrange.withOpacity(0.15);
              final badgeColor = isHigh ? LedgifyColors.debitGreen : LedgifyColors.warningOrange;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: LedgifyColors.surfaceVariant),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text('HSN: ${item.hsnSacCode} • GST: ${item.gstRateSlab}% • Unit: ${item.uqc}', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.matchPercentage}% Match',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, item),
                ),
              );
            }),

          const SizedBox(height: 12),

          // Quick Create Stock Item CTA (48dp Touch Target)
          SizedBox(
            height: LedgifyColors.minTouchTargetSize,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: LedgifyColors.primaryBlue,
                side: const BorderSide(color: LedgifyColors.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('+ Create New Item / नई वस्तु बनाएं', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () async {
                Navigator.pop(context);
                final StockItemModel? created = await QuickCreateStockItemDialog.show(
                  context,
                  initialName: rawItemDescription,
                  initialHsn: rawHsn,
                  initialGstRate: rawGstRate ?? 18.00,
                  businessId: businessId,
                );

                if (created != null && context.mounted) {
                  final syntheticMatch = StockItemMatchResult(
                    stockItemId: created.id,
                    itemName: created.name,
                    hsnSacCode: created.hsnSacCode,
                    gstRateSlab: created.gstRateSlab,
                    uqc: created.uqc,
                    compositeScore: 1.0,
                    resolutionStatus: 'AUTO_MATCHED',
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
