import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'balance_sheet_screen.dart';
import 'profit_and_loss_screen.dart';
import 'trial_balance_screen.dart';

/// Central dashboard for all Indian financial and accounting analytical statements in Ledgify.
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports / वित्तीय विवरण', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LedgifyColors.standardPadding),
          children: [
            _buildReportTile(
              context,
              icon: Icons.account_balance_outlined,
              title: 'Balance Sheet / तुलन पत्र (बैलेंस शीट)',
              subtitle: 'Schedule III Sources & Applications of Funds, Capital, Assets, Liabilities',
              badge: 'Statutory',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BalanceSheetScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildReportTile(
              context,
              icon: Icons.trending_up,
              title: 'Profit & Loss A/c / लाभ और हानि खाता',
              subtitle: 'Gross Profit, Trading Account, Net Margin, Operating Overheads',
              badge: 'P&L',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfitAndLossScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildReportTile(
              context,
              icon: Icons.table_chart_outlined,
              title: 'Trial Balance / तलपट (ट्रायल बैलेंस)',
              subtitle: '4-Column Ledger Closing Balances & Mathematical Zero-Sum Check',
              badge: 'Multi-Column',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrialBalanceScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildReportTile(
              context,
              icon: Icons.swap_vert_outlined,
              title: 'Cash Flow Statement / रोकड़ प्रवाह विवरण',
              subtitle: 'AS 3 Direct Method: Operating, Investing & Financing Cash Flow',
              badge: 'AS 3',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cash Flow Statement generated.')),
                );
              },
            ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
        side: const BorderSide(color: LedgifyColors.surfaceVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: LedgifyColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: LedgifyColors.primaryBlue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: LedgifyColors.secondarySlate)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: LedgifyColors.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
