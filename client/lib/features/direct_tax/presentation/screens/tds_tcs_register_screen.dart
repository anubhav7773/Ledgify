import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../data/repositories/direct_tax_repository.dart';
import '../domain/models/tds_tcs_entry_model.dart';
import 'record_challan_payment_dialog.dart';

/// Screen managing TDS Section 194Q & TCS Section 206C register, Challan tracking, and Form 26Q export.
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
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedEntries = _selectedTab == 'PENDING' ? _pendingEntries : _depositedEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Tax (TDS / TCS) / आयकर टीडीएस', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export Form 26Q JSON',
            onPressed: _exportForm26Q,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
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
                        child: _buildMetricTile('TDS Sec 194Q', '₹${_totalTds194Q.toStringAsFixed(2)}', LedgifyColors.creditRed),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile('TCS Sec 206C', '₹${_totalTcs206C.toStringAsFixed(2)}', LedgifyColors.primaryBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Due Date Warning Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LedgifyColors.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: LedgifyColors.primaryBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TDS Deposit Due Date / जमा अंतिम तिथि', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('Due by 7th of next month ($_daysRemainingForDeposit days left)', style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
                          ],
                        ),
                        Text(
                          '₹${_totalPendingTax.toStringAsFixed(2)}',
                          style: LedgifyTypography.financialAmount.copyWith(fontSize: 16, color: LedgifyColors.creditRed),
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
                  ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
                  : displayedEntries.isEmpty
                      ? const Center(
                          child: Text('No tax records found in this category.', style: LedgifyTypography.bilingualLabel),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayedEntries.length,
                          itemBuilder: (context, index) {
                            final item = displayedEntries[index];

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
                                    Text('Section ${item.sectionCode}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    Text('₹${item.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: LedgifyColors.creditRed)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text('PAN: ${item.partyPan} • Rate: ${item.taxRatePercentage}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                    Text('Assessable Value: ₹${item.assessedAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
                                    if (item.isDeposited)
                                      Text('Challan Ref: ${item.challanNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LedgifyColors.debitGreen)),
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
                  height: LedgifyColors.minTouchTargetSize,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LedgifyColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.payment),
                    label: const Text('Record Challan Payment / चालान भुगतान दर्ज करें', style: TextStyle(fontWeight: FontWeight.w700)),
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
        color: LedgifyColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LedgifyColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
