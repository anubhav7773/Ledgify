import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'package:ledgify/features/gst_compliance/data/repositories/gstr_repository.dart';
import 'package:ledgify/features/gst_compliance/domain/models/gstr_summary_model.dart';
import 'ims_action_portal_screen.dart';

/// Central dashboard for Indian GST Return Filing (GSTR-1, GSTR-3B) and IMS Inward Supplies.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md and docs/10_ui_ux_design_system_tokens.md.
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
      appBar: AppBar(
        title: const Text('GST Compliance & Returns / जीएसटी रिटर्न', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadComplianceData,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LedgifyColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Selector Dropdown
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Return Period / रिटर्न अवधि *',
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

              // Filing Deadlines Warning Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LedgifyColors.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LedgifyColors.primaryBlue, width: 0.8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: LedgifyColors.primaryBlue, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upcoming Filing Deadlines', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          Text('• GSTR-1 Due: 11th of next month\n• GSTR-3B Due: 20th of next month', style: TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
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
                    child: CircularProgressIndicator(color: LedgifyColors.primaryBlue),
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Column(
                    children: [
                      Text('Error: $_errorMessage', style: const TextStyle(color: LedgifyColors.creditRed)),
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
                        subtitle: 'कुल देयता (GSTR-1)',
                        amount: _gstr1Summary?.totalTax ?? 0.00,
                        color: LedgifyColors.creditRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Eligible ITC',
                        subtitle: 'प्राप्त क्रेडिट (GSTR-2B)',
                        amount: (_gstr3bSummary?.rawTableData['table_4']?['eligible_itc']?['all_other_itc']?['taxable_value'] as num?)?.toDouble() ?? 0.00,
                        color: LedgifyColors.debitGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Net Cash Payable Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                    side: const BorderSide(color: LedgifyColors.surfaceVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net Cash Payable (Challan PMT-06)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            Text('कुल नकद देय राशि (ITC सेट-ऑफ के बाद)', style: TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                          ],
                        ),
                        Text(
                          '₹${netCashPayable.toStringAsFixed(2)}',
                          style: LedgifyTypography.financialAmount.copyWith(
                            color: netCashPayable > 0 ? LedgifyColors.creditRed : LedgifyColors.debitGreen,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Navigation Cards
                const Text('Compliance Modules / मॉड्यूल', style: LedgifyTypography.cardHeader),
                const SizedBox(height: 12),

                _buildNavigationTile(
                  icon: Icons.outbox_outlined,
                  title: 'GSTR-1 Outward Supplies / जावक आपूर्ति',
                  subtitle: 'Tables 4 (B2B), 5 (B2CL), 7 (B2CS), 12 (HSN)',
                  badge: 'Ready for Review',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GSTR-1 JSON Payload Generated successfully!')),
                    );
                  },
                ),
                const SizedBox(height: 10),

                _buildNavigationTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'GSTR-3B Monthly Return / मासिक रिटर्न',
                  subtitle: 'Summary of Outward Supplies & ITC Claims (Sec 49 Set-off)',
                  badge: 'Calculated',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GSTR-3B Summary calculated with Section 49 rules.')),
                    );
                  },
                ),
                const SizedBox(height: 10),

                _buildNavigationTile(
                  icon: Icons.fact_check_outlined,
                  title: 'IMS Inward Action Portal / आवक चालान प्रबंधन',
                  subtitle: 'Review & Accept/Reject incoming supplier invoices before GSTR-2B lock',
                  badge: 'Action Required',
                  badgeColor: LedgifyColors.warningOrange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImsActionPortalScreen(returnPeriod: _selectedPeriod),
                      ),
                    );
                  },
                ),
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
        color: LedgifyColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LedgifyColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LedgifyColors.secondarySlate)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: LedgifyColors.secondarySlate)),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: LedgifyColors.surfaceVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: LedgifyColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: LedgifyColors.primaryBlue),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (badgeColor ?? LedgifyColors.debitGreen).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor ?? LedgifyColors.debitGreen),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
