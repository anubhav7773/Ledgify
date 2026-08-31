import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../data/repositories/payroll_repository.dart';
import '../domain/services/payroll_service.dart';
import 'payslip_view_screen.dart';

/// Screen executing monthly payroll calculation, dry-run previews, and double-entry salary journal postings (Google Stitch UI).
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
          SnackBar(content: Text('Payroll preview error: $e'), backgroundColor: AppColors.creditRed),
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
            backgroundColor: AppColors.debitGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post payroll voucher: $e'), backgroundColor: AppColors.creditRed),
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Monthly Payroll Execution', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Payroll Preview',
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
                  labelText: 'Payroll Period (Month-Year) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: _months.map((m) {
                  return DropdownMenuItem(value: m, child: Text('Month: $m'));
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
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_preview == null || _preview!.employeeCount == 0)
              const Expanded(
                child: Center(
                  child: Text('No active employees for this payroll month.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else ...[
              // Summary Metrics Tiles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard('Total Gross', '₹${_preview!.totalGross.toStringAsFixed(0)}', AppColors.debitGreen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard('Statutory Dues', '₹${(_preview!.totalEpfEmployee + _preview!.totalEsiEmployee).toStringAsFixed(0)}', AppColors.creditRed),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard('Net Payout', '₹${_preview!.totalNetPayable.toStringAsFixed(0)}', AppColors.primary),
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
                        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(slip.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                            Text('₹${slip.netPayable.toStringAsFixed(2)}', style: AppTypography.currencyText.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 15)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text('Code: ${slip.employeeCode} • Gross: ₹${slip.grossSalary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('Deductions (PF+ESI+PT+TDS): ₹${slip.totalDeductions.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
                  height: AppColors.minTouchTargetSize,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isPosting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      _isPosting ? 'Posting Salary Journal...' : 'Post Salary Journal & Issue Slips',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.currencyText.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
