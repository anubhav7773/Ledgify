import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../data/repositories/gstr_repository.dart';
import '../domain/models/ims_entry_model.dart';

/// Screen for the Invoice Management System (IMS) Inward Supplies Action Portal.
/// Enables MSME accountants to Accept, Reject, or Pend supplier invoices before GSTR-2B generation.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md and docs/10_ui_ux_design_system_tokens.md.
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
                ? LedgifyColors.debitGreen
                : (action == 'REJECTED' ? LedgifyColors.creditRed : LedgifyColors.warningOrange),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadImsEntries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMS Inward Portal / आवक चालान', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadImsEntries,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildFilterTab('PENDING', 'Pending (लंबित)'),
                  const SizedBox(width: 8),
                  _buildFilterTab('ACCEPTED', 'Accepted (स्वीकृत)'),
                  const SizedBox(width: 8),
                  _buildFilterTab('REJECTED', 'Rejected (अस्वीकृत)'),
                  const SizedBox(width: 8),
                  _buildFilterTab('ALL', 'All'),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: $_errorMessage', style: const TextStyle(color: LedgifyColors.creditRed)),
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
                                  const Icon(Icons.check_circle_outline, size: 48, color: LedgifyColors.debitGreen),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No $_selectedFilter invoices in this period.',
                                    style: LedgifyTypography.bilingualLabel,
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
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: LedgifyColors.surfaceVariant),
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
                                                style: LedgifyTypography.cardHeader.copyWith(fontSize: 16),
                                              ),
                                            ),
                                            Text(
                                              '₹${item.invoiceValue.toStringAsFixed(2)}',
                                              style: LedgifyTypography.financialAmount.copyWith(
                                                fontSize: 16,
                                                color: LedgifyColors.primaryBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'GSTIN: ${item.supplierGstin}',
                                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: LedgifyColors.secondarySlate),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Inv No: ${item.invoiceNumber} • Date: ${item.invoiceDate.day}/${item.invoiceDate.month}/${item.invoiceDate.year}',
                                          style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate),
                                        ),
                                        const Divider(height: 16),

                                        // Tax Breakdown Row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Taxable: ₹${item.taxableValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                            Text('CGST: ₹${item.cgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                            Text('SGST: ₹${item.sgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                            Text('IGST: ₹${item.igst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 14),

                                        // Action Button Row (48dp Touch Targets)
                                        Row(
                                          children: [
                                            // Accept Button
                                            Expanded(
                                              child: SizedBox(
                                                height: LedgifyColors.minTouchTargetSize,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: item.imsStatus == 'ACCEPTED'
                                                        ? LedgifyColors.debitGreen
                                                        : LedgifyColors.debitGreenBg,
                                                    foregroundColor: item.imsStatus == 'ACCEPTED'
                                                        ? Colors.white
                                                        : LedgifyColors.debitGreen,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      side: const BorderSide(color: LedgifyColors.debitGreen),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.check, size: 18),
                                                  label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                                                  onPressed: () => _processAction(item, 'ACCEPTED'),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Reject Button
                                            Expanded(
                                              child: SizedBox(
                                                height: LedgifyColors.minTouchTargetSize,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: item.imsStatus == 'REJECTED'
                                                        ? LedgifyColors.creditRed
                                                        : LedgifyColors.creditRedBg,
                                                    foregroundColor: item.imsStatus == 'REJECTED'
                                                        ? Colors.white
                                                        : LedgifyColors.creditRed,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      side: const BorderSide(color: LedgifyColors.creditRed),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.close, size: 18),
                                                  label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                                                  onPressed: () => _processAction(item, 'REJECTED'),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Pending Button
                                            Expanded(
                                              child: SizedBox(
                                                height: LedgifyColors.minTouchTargetSize,
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: LedgifyColors.secondarySlate,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  child: const Text('Pending', style: TextStyle(fontWeight: FontWeight.w600)),
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
      selectedColor: LedgifyColors.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? LedgifyColors.primaryBlue : LedgifyColors.secondarySlate,
      ),
    );
  }
}
