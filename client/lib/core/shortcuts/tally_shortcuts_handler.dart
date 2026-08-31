import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/banking/presentation/screens/bank_accounts_screen.dart';
import '../../features/reports/presentation/screens/balance_sheet_screen.dart';
import '../../features/reports/presentation/screens/day_book_screen.dart';
import '../../features/reports/presentation/screens/profit_and_loss_screen.dart';
import '../../features/reports/presentation/screens/stock_summary_screen.dart';
import '../../features/search/presentation/screens/global_search_delegate.dart';
import '../../features/vouchers/presentation/screens/voucher_entry_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Handler for Tally-style alphanumeric quick keyboard shortcuts and thumb jump modal (Google Stitch Fintech System).
class TallyShortcutsHandler {
  static void handleKeyEvent(BuildContext context, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey.keyLabel.toUpperCase();

      switch (key) {
        case 'V':
          Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen()));
          break;
        case 'D':
          Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen()));
          break;
        case 'B':
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BalanceSheetScreen()));
          break;
        case 'P':
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfitAndLossScreen()));
          break;
        case 'S':
          Navigator.push(context, MaterialPageRoute(builder: (context) => const StockSummaryScreen()));
          break;
        case 'R':
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BankAccountsScreen()));
          break;
        case 'G':
          showSearch(context: context, delegate: GlobalSearchDelegate());
          break;
      }
    }
  }

  /// Shows the Gateway-of-Tally style single-tap Quick Jump sheet
  static Future<void> showQuickJumpSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gateway Shortcuts', style: AppTypography.cardHeader),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildShortcutTile(ctx, 'V', 'Voucher Entry', Icons.edit_note_rounded, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen()));
                }),
                _buildShortcutTile(ctx, 'D', 'Day Book', Icons.receipt_long_rounded, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen()));
                }),
                _buildShortcutTile(ctx, 'B', 'Balance Sheet', Icons.account_balance_rounded, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const BalanceSheetScreen()));
                }),
                _buildShortcutTile(ctx, 'P', 'Profit & Loss', Icons.trending_up_rounded, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfitAndLossScreen()));
                }),
                _buildShortcutTile(ctx, 'S', 'Stock Summary', Icons.inventory_2_rounded, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const StockSummaryScreen()));
                }),
                _buildShortcutTile(ctx, 'R', 'Bank Reconciliation (BRS)', Icons.rule_rounded, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const BankAccountsScreen()));
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildShortcutTile(
    BuildContext context,
    String hotkey,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        leading: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hotkey,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 15),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary)),
        trailing: Icon(icon, size: 20, color: AppColors.primary),
        onTap: onTap,
      ),
    );
  }
}
