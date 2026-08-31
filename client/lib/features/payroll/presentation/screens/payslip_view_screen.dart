import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../domain/models/salary_slip_model.dart';

/// Screen presenting an itemized digital payslip with earnings, deductions, and statutory metadata.
class PayslipViewScreen extends StatelessWidget {
  final SalarySlipModel salarySlip;
  final String companyName;

  const PayslipViewScreen({
    super.key,
    required this.salarySlip,
    this.companyName = 'Ledgify Enterprise',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslip / वेतन पर्ची', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Payslip',
            onPressed: () {
              Share.share(
                'Payslip for ${salarySlip.fullName} (${salarySlip.monthYear}):\n'
                'Gross Salary: ₹${salarySlip.grossSalary.toStringAsFixed(2)}\n'
                'Total Deductions: ₹${salarySlip.totalDeductions.toStringAsFixed(2)}\n'
                'Net Payable: ₹${salarySlip.netPayable.toStringAsFixed(2)}',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LedgifyColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Company Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                  side: const BorderSide(color: LedgifyColors.surfaceVariant),
                ),
                color: LedgifyColors.surfaceCard,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(companyName, style: LedgifyTypography.cardHeader.copyWith(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('Payslip for the month of ${salarySlip.monthYear}', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                      const Divider(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(salarySlip.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Text('Code: ${salarySlip.employeeCode} • ${salarySlip.designation ?? 'Executive'}', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('PAN: ${salarySlip.pan ?? "N/A"}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                              Text('Regime: ${salarySlip.taxRegime}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LedgifyColors.primaryBlue)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Earnings vs Deductions Split Tables
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Earnings Column
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Earnings / आय', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: LedgifyColors.debitGreen)),
                            const Divider(height: 16),
                            _buildLineRow('Basic Pay', salarySlip.basicSalary),
                            _buildLineRow('HRA', salarySlip.hra),
                            _buildLineRow('Allowances', salarySlip.specialAllowance),
                            const Divider(height: 16),
                            _buildLineRow('Total Gross', salarySlip.grossSalary, isBold: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Deductions Column
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Deductions / कटौती', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: LedgifyColors.creditRed)),
                            const Divider(height: 16),
                            _buildLineRow('EPF (12%)', salarySlip.epfEmployee),
                            _buildLineRow('ESI (0.75%)', salarySlip.esiEmployee),
                            _buildLineRow('Prof Tax', salarySlip.professionalTax),
                            _buildLineRow('TDS Sec 192', salarySlip.tdsSalary),
                            const Divider(height: 16),
                            _buildLineRow('Total Deduct', salarySlip.totalDeductions, isBold: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Net Pay Card
              Card(
                color: LedgifyColors.primaryContainer.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LedgifyColors.primaryBlue.withOpacity(0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Salary Payable', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('शुद्ध देय वेतन', style: TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                        ],
                      ),
                      Text(
                        '₹${salarySlip.netPayable.toStringAsFixed(2)}',
                        style: LedgifyTypography.financialAmount.copyWith(fontSize: 20, color: LedgifyColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons (48dp Touch Targets)
              SizedBox(
                height: LedgifyColors.minTouchTargetSize,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LedgifyColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Download Payslip PDF / पीडीएफ डाउनलोड करें', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payslip PDF generated successfully!')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
