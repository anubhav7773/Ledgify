import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../data/repositories/payroll_repository.dart';
import '../domain/services/payroll_service.dart';
import 'payslip_view_screen.dart';

/// Screen executing monthly payroll calculation, dry-run previews, and double-entry salary journal postings.
class MonthlyPayrollRunScreen extends StatefulWidget {
  final PayrollRepository? repository;
  final String? initialMonthYear;

  const MonthlyPayrollRunScreen({
    super.key,
    this.repository,
    this.initialMonthYear,
  });

  @override
  State<MonthlyPayrollRunScreen> createState() => _MonthlyPayrollRunScreenState();
}

class _MonthlyPayrollRunScreenState extends State<MonthlyPayrollRunScreen> {
  late final PayrollRepository _repository;
  late String _selectedMonthYear;

  bool _isLoading = true;
  bool _isPosting = false;
  PayrollPreviewSummary? _preview;

  final List<String> _months = [
    '2026-08',
    '2026-07',
    '2026-06',
    '2026-05',
    '2026-04',
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PayrollRepository();
    _selectedMonthYear = widget.initialMonthYear ?? '2026-08';
    _loadPayrollPreview();
  }

  Future<void> _loadPayrollPreview() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _repository.previewMonthlyPayroll(_selectedMonthYear);
      if (mounted) {
        setState(() {
          _preview = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payroll preview error: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    }
  }

  Future<void> _postSalaryJournal() async {
    setState(() => _isPosting = true);

    try {
      final voucherId = await _repository.executePayrollRun(
        _selectedMonthYear,
        DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Salary Journal posted successfully (ID: ${voucherId.substring(0, 8)})!'),
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post payroll voucher: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Payroll / मासिक वेतन गणना', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayrollPreview,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Month Selector
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedMonthYear,
                decoration: const InputDecoration(
                  labelText: 'Salary Month / वेतन माह *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                items: _months.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedMonthYear = val);
                    _loadPayrollPreview();
                  }
                },
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue)))
            else if (_preview == null || _preview!.employeeCount == 0)
              const Expanded(
                child: Center(
                  child: Text('No active employees for this payroll month.', style: LedgifyTypography.bilingualLabel),
                ),
              )
            else ...[
              // Summary Metrics Tiles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard('Total Gross / कुल आय', '₹${_preview!.totalGross.toStringAsFixed(0)}', LedgifyColors.debitGreen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard('Statutory Dues (PF/ESI)', '₹${(_preview!.totalEpfEmployee + _preview!.totalEsiEmployee).toStringAsFixed(0)}', LedgifyColors.creditRed),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard('Net Payout / शुद्ध देय', '₹${_preview!.totalNetPayable.toStringAsFixed(0)}', LedgifyColors.primaryBlue),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Employee Payslip List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _preview!.salarySlips.length,
                  itemBuilder: (context, index) {
                    final slip = _preview!.salarySlips[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: LedgifyColors.surfaceVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(slip.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text('₹${slip.netPayable.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('Code: ${slip.employeeCode} • Gross: ₹${slip.grossSalary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                            Text('Deductions (PF+ESI+PT+TDS): ₹${slip.totalDeductions.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: LedgifyColors.secondarySlate),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PayslipViewScreen(salarySlip: slip),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Post Salary Journal Button (48dp Touch Target)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: LedgifyColors.minTouchTargetSize,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LedgifyColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isPosting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isPosting ? 'Posting Salary Journal...' : 'Post Salary Voucher & Generate Slips / वेतन दर्ज करें',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isPosting ? null : _postSalaryJournal,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LedgifyColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LedgifyColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: LedgifyColors.secondarySlate, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
