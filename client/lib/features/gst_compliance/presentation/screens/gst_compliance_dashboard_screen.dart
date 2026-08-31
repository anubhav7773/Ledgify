import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/gst_compliance/data/repositories/gstr_repository.dart';
import 'package:ledgify/features/gst_compliance/domain/models/gstr_summary_model.dart';
import 'einvoice_details_screen.dart';
import 'eway_bill_list_screen.dart';
import 'ims_action_portal_screen.dart';

/// Central dashboard for Indian GST Return Filing (GSTR-1, GSTR-3B) and IMS Inward Supplies (Google Stitch UI).
class GstComplianceDashboardScreen extends StatefulWidget {
  final GstrRepository? repository;
  final String? initialPeriod;

  const GstComplianceDashboardScreen({
    super.key,
    this.repository,
    this.initialPeriod,
  });

  @override
  State<GstComplianceDashboardScreen> createState() => _GstComplianceDashboardScreenState();
}

class _GstComplianceDashboardScreenState extends State<GstComplianceDashboardScreen> {
  late final GstrRepository _repository;
  late String _selectedPeriod; // MMYYYY format

  bool _isLoading = true;
  String? _errorMessage;
  GstrSummaryModel? _gstr1Summary;
  GstrSummaryModel? _gstr3bSummary;

  final List<String> _availablePeriods = [
    '082026',
    '072026',
    '062026',
    '052026',
    '042026',
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? GstrRepository();
    _selectedPeriod = widget.initialPeriod ?? '082026';
    _loadComplianceData();
  }

  String _formatPeriodLabel(String period) {
    final month = int.parse(period.substring(0, 2));
    final year = period.substring(2, 6);
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${monthNames[month]} $year ($period)';
  }

  Future<void> _loadComplianceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final gstr1 = await _repository.fetchGstr1Report(_selectedPeriod);
      final gstr3b = await _repository.fetchGstr3bReport(_selectedPeriod);

      if (mounted) {
        setState(() {
          _gstr1Summary = GstrSummaryModel.fromGstr1Json(gstr1);
          _gstr3bSummary = GstrSummaryModel.fromGstr3bJson(gstr3b);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final netData = _gstr3bSummary?.rawTableData['net_tax_liability'] as Map<String, dynamic>? ?? {};
    final double netCashPayable = (netData['net_cash_payable'] as num?)?.toDouble() ?? 0.00;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('GST Compliance & Returns', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Compliance Status',
            onPressed: _loadComplianceData,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Selector Dropdown
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Return Filing Period *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: _availablePeriods.map((p) {
                  return DropdownMenuItem(value: p, child: Text(_formatPeriodLabel(p)));
                }).toList(),
                onChanged: (newPeriod) {
                  if (newPeriod != null) {
                    setState(() => _selectedPeriod = newPeriod);
                    _loadComplianceData();
                  }
                },
              ),
              const SizedBox(height: 16),

              // Filing Deadlines Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.event_available_rounded, color: AppColors.primary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upcoming Filing Deadlines', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                          SizedBox(height: 2),
                          Text('• GSTR-1 Due: 11th of the following month\n• GSTR-3B Due: 20th of the following month', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Column(
                    children: [
                      Text('Error: $_errorMessage', style: const TextStyle(color: AppColors.creditRed)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadComplianceData, child: const Text('Retry')),
                    ],
                  ),
                )
              else ...[
                // Top Financial Summary Tiles
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Outward Liability',
                        subtitle: 'GSTR-1 Output Tax',
                        amount: _gstr1Summary?.totalTax ?? 0.00,
                        color: AppColors.creditRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Eligible ITC',
                        subtitle: 'GSTR-2B Input Credit',
                        amount: (_gstr3bSummary?.rawTableData['table_4']?['eligible_itc']?['all_other_itc']?['taxable_value'] as num?)?.toDouble() ?? 0.00,
                        color: AppColors.debitGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Net Cash Payable Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net Cash Payable (Challan PMT-06)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('Net cash liability after Section 49 ITC set-off', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(
                          '₹${netCashPayable.toStringAsFixed(2)}',
                          style: AppTypography.currencyText.copyWith(
                            color: netCashPayable > 0 ? AppColors.creditRed : AppColors.debitGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Navigation Cards
                Text('Statutory Portals & Filing Tools', style: AppTypography.cardHeader),
                const SizedBox(height: 12),

                _buildNavigationTile(
                  icon: Icons.outbox_rounded,
                  title: 'GSTR-1 Outward Supplies',
                  subtitle: 'Tables 4 (B2B), 5 (B2CL), 7 (B2CS), 12 (HSN)',
                  badge: 'Ready for Review',
                  badgeColor: AppColors.debitGreen,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GSTR-1 JSON Payload Generated successfully!')),
                    );
                  },
                ),
                const SizedBox(height: 10),

                _buildNavigationTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'GSTR-3B Monthly Return',
                  subtitle: 'Summary of Outward Supplies & ITC Claims (Sec 49 Set-off)',
                  badge: 'Calculated',
                  badgeColor: AppColors.debitGreen,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GSTR-3B Summary calculated with Section 49 rules.')),
                    );
                  },
                ),
                const SizedBox(height: 10),

                _buildNavigationTile(
                  icon: Icons.fact_check_rounded,
                  title: 'IMS Inward Supplies Action Portal',
                  subtitle: 'Review & Accept/Reject incoming supplier invoices before GSTR-2B lock',
                  badge: 'Action Required',
                  badgeColor: AppColors.warningAmber,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImsActionPortalScreen(returnPeriod: _selectedPeriod),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                _buildNavigationTile(
                  icon: Icons.local_shipping_rounded,
                  title: 'E-Way Bills Management',
                  subtitle: 'Generate Part-A/B, track validity countdown, and manage transporters',
                  badge: 'Active Portal',
                  badgeColor: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EWayBillListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),

                _buildNavigationTile(
                  icon: Icons.qr_code_2_rounded,
                  title: 'E-Invoice IRN & Signed QR Code',
                  subtitle: 'Real-time B2B invoice registration, statutory IRN hash & QR preview',
                  badge: 'NIC Gateway',
                  badgeColor: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EInvoiceDetailScreen(invoiceId: 'INV-DEMO-001')),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: AppTypography.currencyText.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final bColor = badgeColor ?? AppColors.debitGreen;
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
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bColor),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
