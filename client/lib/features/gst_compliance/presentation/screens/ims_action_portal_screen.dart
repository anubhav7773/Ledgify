import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/gst_compliance/data/repositories/gstr_repository.dart';
import 'package:ledgify/features/gst_compliance/domain/models/ims_entry_model.dart';

/// Screen for the Invoice Management System (IMS) Inward Supplies Action Portal (Google Stitch UI).
class ImsActionPortalScreen extends StatefulWidget {
  final GstrRepository? repository;
  final String returnPeriod; // 'MMYYYY'

  const ImsActionPortalScreen({
    super.key,
    this.repository,
    required this.returnPeriod,
  });

  @override
  State<ImsActionPortalScreen> createState() => _ImsActionPortalScreenState();
}

class _ImsActionPortalScreenState extends State<ImsActionPortalScreen> {
  late final GstrRepository _repository;
  bool _isLoading = true;
  String? _errorMessage;
  List<ImsEntryModel> _entries = [];
  String _selectedFilter = 'PENDING';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? GstrRepository();
    _loadImsEntries();
  }

  Future<void> _loadImsEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entries = await _repository.fetchImsInwardSupplies(
        widget.returnPeriod,
        filterStatus: _selectedFilter == 'ALL' ? null : _selectedFilter,
      );

      if (mounted) {
        setState(() {
          _entries = entries;
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

  Future<void> _processAction(ImsEntryModel entry, String action) async {
    try {
      await _repository.updateImsStatus(entry.id, action, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${entry.invoiceNumber} marked as $action!'),
            backgroundColor: action == 'ACCEPTED'
                ? AppColors.debitGreen
                : (action == 'REJECTED' ? AppColors.creditRed : AppColors.warningAmber),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadImsEntries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('IMS Inward Supplies Review', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Inward Invoices',
            onPressed: _loadImsEntries,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Selector Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterTab('PENDING', 'Pending Review'),
                    const SizedBox(width: 8),
                    _buildFilterTab('ACCEPTED', 'Accepted (ITC Claimed)'),
                    const SizedBox(width: 8),
                    _buildFilterTab('REJECTED', 'Rejected (Excluded)'),
                    const SizedBox(width: 8),
                    _buildFilterTab('ALL', 'All Invoices'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: $_errorMessage', style: const TextStyle(color: AppColors.creditRed)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _loadImsEntries, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _entries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.debitGreenLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_outline_rounded, size: 44, color: AppColors.debitGreen),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No $_selectedFilter invoices in this return period.',
                                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final item = _entries[index];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                                    side: const BorderSide(color: AppColors.border),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Supplier Header
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.supplierName,
                                                style: AppTypography.cardHeader.copyWith(fontSize: 15),
                                              ),
                                            ),
                                            Text(
                                              '₹${item.invoiceValue.toStringAsFixed(2)}',
                                              style: AppTypography.currencyText.copyWith(
                                                fontSize: 16,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'GSTIN: ${item.supplierGstin}',
                                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Inv No: ${item.invoiceNumber} • Date: ${item.invoiceDate.day.toString().padLeft(2, '0')}/${item.invoiceDate.month.toString().padLeft(2, '0')}/${item.invoiceDate.year}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        const Divider(height: 16),

                                        // Tax Breakdown Row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Taxable: ₹${item.taxableValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            Text('CGST: ₹${item.cgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            Text('SGST: ₹${item.sgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            Text('IGST: ₹${item.igst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                        const SizedBox(height: 14),

                                        // Action Button Row (48dp Touch Targets)
                                        Row(
                                          children: [
                                            // Accept Button
                                            Expanded(
                                              child: SizedBox(
                                                height: AppColors.minTouchTargetSize,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: item.imsStatus == 'ACCEPTED'
                                                        ? AppColors.debitGreen
                                                        : AppColors.debitGreenLight,
                                                    foregroundColor: item.imsStatus == 'ACCEPTED'
                                                        ? Colors.white
                                                        : AppColors.debitGreen,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      side: const BorderSide(color: AppColors.debitGreen),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.check_rounded, size: 18),
                                                  label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                                                  onPressed: () => _processAction(item, 'ACCEPTED'),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Reject Button
                                            Expanded(
                                              child: SizedBox(
                                                height: AppColors.minTouchTargetSize,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: item.imsStatus == 'REJECTED'
                                                        ? AppColors.creditRed
                                                        : AppColors.creditRedLight,
                                                    foregroundColor: item.imsStatus == 'REJECTED'
                                                        ? Colors.white
                                                        : AppColors.creditRed,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      side: const BorderSide(color: AppColors.creditRed),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.close_rounded, size: 18),
                                                  label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                                                  onPressed: () => _processAction(item, 'REJECTED'),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Pending Button
                                            Expanded(
                                              child: SizedBox(
                                                height: AppColors.minTouchTargetSize,
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppColors.textSecondary,
                                                    side: const BorderSide(color: AppColors.border),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                  child: const Text('Pend', style: TextStyle(fontWeight: FontWeight.w700)),
                                                  onPressed: () => _processAction(item, 'PENDING'),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = key);
          _loadImsEntries();
        }
      },
      selectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}
