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

/// Handler for Tally-style alphanumeric quick keyboard shortcuts and thumb jump modal.
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gateway Shortcuts / त्वरित नेविगेशन', style: AppTypography.cardHeader),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),

              _buildShortcutTile(ctx, 'V', 'Voucher Entry / वाउचर प्रविष्टि', Icons.edit_note, () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen()));
              }),
              _buildShortcutTile(ctx, 'D', 'Day Book / दैनिक बही', Icons.receipt_long_outlined, () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen()));
              }),
              _buildShortcutTile(ctx, 'B', 'Balance Sheet / तुलन पत्र', Icons.account_balance_outlined, () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BalanceSheetScreen()));
              }),
              _buildShortcutTile(ctx, 'P', 'Profit & Loss / लाभ-हानि', Icons.trending_up, () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfitAndLossScreen()));
              }),
              _buildShortcutTile(ctx, 'S', 'Stock Summary / स्टॉक सारांश', Icons.inventory_2_outlined, () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const StockSummaryScreen()));
              }),
              _buildShortcutTile(ctx, 'R', 'Bank Reconciliation / बैंक समाधान (BRS)', Icons.rule, () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BankAccountsScreen()));
              }),
              const SizedBox(height: 10),
            ],
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          hotkey,
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 15),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      trailing: Icon(icon, size: 20, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
