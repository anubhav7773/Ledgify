import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/banking/presentation/screens/bank_accounts_screen.dart';
import 'package:ledgify/features/gst_compliance/presentation/screens/gst_compliance_dashboard_screen.dart';
import 'balance_sheet_screen.dart';
import 'day_book_screen.dart';
import 'profit_and_loss_screen.dart';
import 'stock_summary_screen.dart';
import 'trial_balance_screen.dart';

/// Central dashboard for all Indian financial, accounting, and statutory reports (Google Stitch UI).
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Reports Hub', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          children: [
            // Section 1: Financial Statements
            Text('Financial Statements', style: AppTypography.cardHeader),
            const SizedBox(height: 10),

            _buildReportTile(
              context,
              icon: Icons.account_balance_rounded,
              title: 'Balance Sheet',
              subtitle: 'Schedule III Sources & Applications of Funds, Capital, Assets, Liabilities',
              badge: 'Statutory',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BalanceSheetScreen()),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildReportTile(
              context,
              icon: Icons.trending_up_rounded,
              title: 'Profit & Loss Account',
              subtitle: 'Gross Profit, Trading Account, Net Margin, Operating Overheads',
              badge: 'P&L',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfitAndLossScreen()),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildReportTile(
              context,
              icon: Icons.table_chart_rounded,
              title: 'Trial Balance',
              subtitle: '4-Column Ledger Closing Balances & Mathematical Zero-Sum Check',
              badge: 'Multi-Column',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrialBalanceScreen()),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildReportTile(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'Transaction Day Book',
              subtitle: 'Chronological Daily Voucher Journal and Transaction Timeline',
              badge: 'Day Book',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DayBookScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Section 2: Inventory & Operations
            Text('Inventory & Banking', style: AppTypography.cardHeader),
            const SizedBox(height: 10),

            _buildReportTile(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'Stock Summary & Valuation',
              subtitle: 'Real-time Item Inventory, Average Cost Valuation, and Closing Stock',
              badge: 'Inventory',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StockSummaryScreen()),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildReportTile(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Bank Accounts & Reconciliation',
              subtitle: 'BRS Workspace, Statement Import, and Book Balance Alignment',
              badge: 'Banking',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BankAccountsScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Section 3: Statutory & Tax
            Text('Statutory & Compliance', style: AppTypography.cardHeader),
            const SizedBox(height: 10),

            _buildReportTile(
              context,
              icon: Icons.verified_rounded,
              title: 'GST Compliance Dashboard',
              subtitle: 'GSTR-1, GSTR-3B Filing Status, IMS Review, and Section 49 ITC Offset',
              badge: 'GST Portal',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GstComplianceDashboardScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: Text(
            badge,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
