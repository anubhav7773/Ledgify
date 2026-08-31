import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../data/repositories/direct_tax_repository.dart';
import '../domain/models/tds_tcs_entry_model.dart';
import 'record_challan_payment_dialog.dart';

/// Screen managing TDS Section 194Q & TCS Section 206C register, Challan tracking, and Form 26Q export (Google Stitch UI).
class TdsTcsRegisterScreen extends StatefulWidget {
  final DirectTaxRepository? repository;
  final String? businessId;

  const TdsTcsRegisterScreen({
    super.key,
    this.repository,
    this.businessId,
  });

  @override
  State<TdsTcsRegisterScreen> createState() => _TdsTcsRegisterScreenState();
}

class _TdsTcsRegisterScreenState extends State<TdsTcsRegisterScreen> {
  late final DirectTaxRepository _repository;
  bool _isLoading = true;
  List<TdsTcsEntryModel> _pendingEntries = [];
  List<TdsTcsEntryModel> _depositedEntries = [];
  String _selectedTab = 'PENDING'; // 'PENDING' or 'DEPOSITED'

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DirectTaxRepository();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _repository.fetchPendingTdsEntries();
      final history = await _repository.fetchTdsHistory();

      if (mounted) {
        setState(() {
          _pendingEntries = pending;
          _depositedEntries = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalPendingTax => _pendingEntries.fold(0.0, (sum, e) => sum + e.taxAmount);
  double get _totalTds194Q => _pendingEntries.where((e) => e.sectionCode == '194Q').fold(0.0, (s, e) => s + e.taxAmount);
  double get _totalTcs206C => _pendingEntries.where((e) => e.sectionCode.contains('206C')).fold(0.0, (s, e) => s + e.taxAmount);

  int get _daysRemainingForDeposit {
    final now = DateTime.now();
    final nextMonthSeventh = DateTime(now.year, now.month + 1, 7);
    return nextMonthSeventh.difference(now).inDays;
  }

  Future<void> _exportForm26Q() async {
    try {
      final payload = await _repository.exportQuarterlyReturn(
        financialYear: '2026-2027',
        quarter: 'Q2',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Form 26Q exported successfully with ${payload['total_entries']} deductee rows!'),
            backgroundColor: AppColors.debitGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedEntries = _selectedTab == 'PENDING' ? _pendingEntries : _depositedEntries;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Direct Tax (TDS / TCS) Register', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export Form 26Q JSON',
            onPressed: _exportForm26Q,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Tax Register',
            onPressed: _loadEntries,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Metrics Container
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile('TDS Sec 194Q', '₹${_totalTds194Q.toStringAsFixed(2)}', AppColors.creditRed),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile('TCS Sec 206C', '₹${_totalTcs206C.toStringAsFixed(2)}', AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Due Date Warning Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                      border: Border.all(color: AppColors.primaryLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TDS Deposit Due Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                            const SizedBox(height: 2),
                            Text('Due by 7th of next month ($_daysRemainingForDeposit days remaining)', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(
                          '₹${_totalPendingTax.toStringAsFixed(2)}',
                          style: AppTypography.currencyText.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.creditRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('Pending Challan (${_pendingEntries.length})'),
                    selected: _selectedTab == 'PENDING',
                    onSelected: (val) => setState(() => _selectedTab = 'PENDING'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Deposited (${_depositedEntries.length})'),
                    selected: _selectedTab == 'DEPOSITED',
                    onSelected: (val) => setState(() => _selectedTab = 'DEPOSITED'),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Entries List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : displayedEntries.isEmpty
                      ? const Center(
                          child: Text('No tax records found in this category.', style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayedEntries.length,
                          itemBuilder: (context, index) {
                            final item = displayedEntries[index];

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
                                    Text('Section ${item.sectionCode}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary)),
                                    Text('₹${item.taxAmount.toStringAsFixed(2)}', style: AppTypography.currencyText.copyWith(fontWeight: FontWeight.w800, color: AppColors.creditRed, fontSize: 15)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 3),
                                    Text('PAN: ${item.partyPan} • Tax Rate: ${item.taxRatePercentage}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary)),
                                    Text('Assessable Value: ₹${item.assessedAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                    if (item.isDeposited) ...[
                                      const SizedBox(height: 2),
                                      Text('Challan Ref: ${item.challanNumber}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.debitGreen)),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Bottom CTA for recording challan payment
            if (_pendingEntries.isNotEmpty)
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
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Record Challan Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    onPressed: () async {
                      final updated = await RecordChallanPaymentDialog.show(
                        context,
                        pendingEntries: _pendingEntries,
                        businessId: widget.businessId,
                      );
                      if (updated == true) _loadEntries();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
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
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.currencyText.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
