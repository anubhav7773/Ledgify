import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../data/repositories/fixed_asset_repository.dart';
import '../../domain/models/fixed_asset_model.dart';
import 'create_fixed_asset_screen.dart';

/// Screen for the Companies Act 2013 (Schedule II) Fixed Asset Register.
/// Displays asset carrying values, shift settings, and triggers periodic depreciation runs.
/// Adheres strictly to docs/10_ui_ux_design_system_tokens.md.
class FixedAssetRegisterScreen extends StatefulWidget {
  final FixedAssetRepository? repository;
  final String? businessId;

  const FixedAssetRegisterScreen({
    super.key,
    this.repository,
    this.businessId,
  });

  @override
  State<FixedAssetRegisterScreen> createState() => _FixedAssetRegisterScreenState();
}

class _FixedAssetRegisterScreenState extends State<FixedAssetRegisterScreen> {
  late final FixedAssetRepository _repository;
  bool _isLoading = true;
  bool _isRunningDepreciation = false;
  String? _errorMessage;
  List<FixedAssetModel> _assets = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FixedAssetRepository();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assets = await _repository.fetchFixedAssets();
      if (mounted) {
        setState(() {
          _assets = assets;
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

  double get _totalOriginalCost =>
      _assets.fold(0.00, (sum, a) => sum + a.originalCost);
  double get _totalAccumulatedDep =>
      _assets.fold(0.00, (sum, a) => sum + a.accumulatedDepreciation);
  double get _totalNetBookValue =>
      _assets.fold(0.00, (sum, a) => sum + a.currentBookValue);

  Future<void> _runDepreciationDialog() async {
    DateTime selectedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Run Depreciation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will automatically calculate and post Schedule II straight-line depreciation journal entries up to the selected period end date.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: LedgifyColors.primaryBlue),
                title: const Text('Period End Date:'),
                subtitle: Text(
                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LedgifyColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Execute Run'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isRunningDepreciation = true);
      try {
        final result = await _repository.executeDepreciationRun(
          widget.businessId ?? '',
          selectedDate,
        );

        if (mounted) {
          final total = result['total_depreciation'];
          final count = result['assets_processed'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Depreciation posted! Total: ₹$total across $count asset(s).'),
              backgroundColor: LedgifyColors.debitGreen,
            ),
          );
          _loadAssets();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Depreciation run failed: $e'),
              backgroundColor: LedgifyColors.creditRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isRunningDepreciation = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixed Asset Register', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAssets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage', style: const TextStyle(color: LedgifyColors.creditRed)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadAssets, child: const Text('Retry')),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      // Summary Financial Metric Cards
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: LedgifyColors.surfaceCard,
                          borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                          border: Border.all(color: LedgifyColors.surfaceVariant),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricColumn('Total Cost', '₹${_totalOriginalCost.toStringAsFixed(2)}', LedgifyColors.secondarySlate),
                                _buildMetricColumn('Acc. Depreciation', '₹${_totalAccumulatedDep.toStringAsFixed(2)}', LedgifyColors.creditRed),
                                _buildMetricColumn('Net Book Value', '₹${_totalNetBookValue.toStringAsFixed(2)}', LedgifyColors.debitGreen),
                              ],
                            ),
                            const Divider(height: 24),

                            // Run Periodic Depreciation Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LedgifyColors.primaryContainer,
                                  foregroundColor: LedgifyColors.primaryBlue,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: _isRunningDepreciation
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.calculate_outlined, size: 20),
                                label: const Text(
                                  'Run Periodic Depreciation',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                onPressed: _isRunningDepreciation ? null : _runDepreciationDialog,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Assets List
                      Expanded(
                        child: _assets.isEmpty
                            ? const Center(
                                child: Text(
                                  'No fixed assets registered yet.',
                                  style: LedgifyTypography.bilingualLabel,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                itemCount: _assets.length,
                                itemBuilder: (context, index) {
                                  final asset = _assets[index];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: LedgifyColors.surfaceVariant),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title & Category
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  asset.assetName,
                                                  style: LedgifyTypography.cardHeader.copyWith(fontSize: 16),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: LedgifyColors.primaryContainer,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  asset.category,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LedgifyColors.primaryBlue),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),

                                          // Shift & NESD badges
                                          Row(
                                            children: [
                                              Chip(
                                                visualDensity: VisualDensity.compact,
                                                label: Text('${asset.shiftWorking} Shift (${asset.shiftMultiplier}x)'),
                                                labelStyle: const TextStyle(fontSize: 11),
                                              ),
                                              const SizedBox(width: 6),
                                              if (asset.isNesd)
                                                const Chip(
                                                  visualDensity: VisualDensity.compact,
                                                  label: Text('NESD (No Extra Shift)'),
                                                  labelStyle: TextStyle(fontSize: 11, color: LedgifyColors.warningOrange),
                                                ),
                                              if (asset.itcClaimedFlag) ...[
                                                const SizedBox(width: 6),
                                                const Chip(
                                                  visualDensity: VisualDensity.compact,
                                                  label: Text('ITC Claimed (Sec 16(3))'),
                                                  labelStyle: TextStyle(fontSize: 11, color: LedgifyColors.primaryBlue),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const Divider(height: 16),

                                          // Cost vs Dep vs Carrying Value
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Cost: ₹${asset.originalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: LedgifyColors.secondarySlate)),
                                              Text('Dep: ₹${asset.accumulatedDepreciation.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: LedgifyColors.creditRed)),
                                              Text(
                                                'Book Value: ₹${asset.currentBookValue.toStringAsFixed(2)}',
                                                style: LedgifyTypography.financialAmount.copyWith(color: LedgifyColors.debitGreen),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LedgifyColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Asset / नई संपत्ति'),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CreateFixedAssetScreen(businessId: widget.businessId),
            ),
          );
          if (result == true) {
            _loadAssets();
          }
        },
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
