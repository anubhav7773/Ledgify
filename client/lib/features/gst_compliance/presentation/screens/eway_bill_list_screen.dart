import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/gst_compliance/data/repositories/eway_bill_repository.dart';
import 'package:ledgify/features/gst_compliance/domain/models/eway_bill_model.dart';
import 'generate_eway_bill_screen.dart';

/// Screen listing generated E-Way Bills with real-time validity countdowns and Part B vehicle tracking (Google Stitch UI).
class EWayBillListScreen extends StatefulWidget {
  final EWayBillRepository? repository;
  final String? businessId;

  const EWayBillListScreen({
    super.key,
    this.repository,
    this.businessId,
  });

  @override
  State<EWayBillListScreen> createState() => _EWayBillListScreenState();
}

class _EWayBillListScreenState extends State<EWayBillListScreen> {
  late final EWayBillRepository _repository;
  bool _isLoading = true;
  String? _errorMessage;
  List<EWayBillModel> _bills = [];
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? EWayBillRepository();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bills = await _repository.fetchEWayBills();
      if (mounted) {
        setState(() {
          _bills = bills;
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

  List<EWayBillModel> get _filteredBills {
    if (_selectedFilter == 'ACTIVE') {
      return _bills.where((b) => b.status == 'ACTIVE' && !b.isExpired).toList();
    } else if (_selectedFilter == 'EXPIRING') {
      return _bills.where((b) => b.status == 'ACTIVE' && !b.isExpired && b.remainingHours <= 8).toList();
    } else if (_selectedFilter == 'CANCELLED') {
      return _bills.where((b) => b.status == 'CANCELLED').toList();
    }
    return _bills;
  }

  Future<void> _showUpdateVehicleDialog(EWayBillModel bill) async {
    final vehicleController = TextEditingController(text: bill.vehicleNumber ?? '');
    final reasonController = TextEditingController(text: 'Transshipment / Vehicle Break-down');

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Part B Vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vehicleController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'New Vehicle Number *',
                hintText: 'e.g., MH04AB1234',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Change *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update Vehicle'),
          ),
        ],
      ),
    );

    if (updated == true && vehicleController.text.trim().isNotEmpty) {
      try {
        await _repository.updatePartBVehicle(
          ewbId: bill.id,
          newVehicleNumber: vehicleController.text.trim().toUpperCase(),
          reason: reasonController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Part B vehicle updated successfully!'),
              backgroundColor: AppColors.debitGreen,
            ),
          );
          _loadBills();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update vehicle: $e'), backgroundColor: AppColors.creditRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('E-Way Bills Tracking', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh E-Way Bills',
            onPressed: _loadBills,
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
                    _buildFilterChip('ALL', 'All Bills (${_bills.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ACTIVE', 'Active (${_bills.where((EWayBillModel b) => b.status == "ACTIVE" && !b.isExpired).length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('EXPIRING', 'Expiring Soon (${_bills.where((EWayBillModel b) => b.status == "ACTIVE" && !b.isExpired && b.remainingHours <= 8).length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('CANCELLED', 'Cancelled (${_bills.where((EWayBillModel b) => b.status == "CANCELLED").length})'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: $_errorMessage', style: const TextStyle(color: AppColors.creditRed)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadBills, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _filteredBills.isEmpty
                          ? const Center(
                              child: Text(
                                'No E-Way bills found in this category.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: _filteredBills.length,
                              itemBuilder: (context, index) {
                                final bill = _filteredBills[index];
                                final bool isExpired = bill.isExpired;
                                final bool isExpiringSoon = bill.status == 'ACTIVE' && !isExpired && bill.remainingHours <= 8;

                                Color badgeBg = AppColors.debitGreenLight;
                                Color badgeColor = AppColors.debitGreen;
                                if (isExpired || bill.status == 'CANCELLED') {
                                  badgeBg = AppColors.creditRedLight;
                                  badgeColor = AppColors.creditRed;
                                } else if (isExpiringSoon) {
                                  badgeBg = AppColors.warningAmberLight;
                                  badgeColor = AppColors.warningAmber;
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                                    side: BorderSide(
                                      color: bill.isExpired
                                          ? AppColors.creditRed.withOpacity(0.5)
                                          : (isExpiringSoon ? AppColors.warningAmber.withOpacity(0.5) : AppColors.border),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: EWB Number + Validity Countdown
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'E-Way Bill No.',
                                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                                ),
                                                Text(
                                                  bill.ewbNumber,
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: badgeBg,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: badgeColor, width: 0.8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.timer_outlined, size: 13, color: badgeColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    bill.remainingCountdownFormatted,
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 16),

                                        // Route & Vehicle Info
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Distance: ${bill.distanceKm.toStringAsFixed(0)} KM (${(bill.distanceKm / 200).ceil()} days validity)',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            Text(
                                              bill.isPartBCompleted
                                                  ? 'Vehicle: ${bill.vehicleNumber}'
                                                  : 'Part B: Pending / 10km Exemption',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: bill.isPartBCompleted ? AppColors.primary : AppColors.warningAmber,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Quick Part B Update Action
                                        if (bill.status == 'ACTIVE' && !bill.isExpired)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              icon: const Icon(Icons.edit_outlined, size: 14),
                                              label: const Text('Update Vehicle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                              onPressed: () => _showUpdateVehicleDialog(bill),
                                            ),
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_road_rounded),
        label: const Text('Generate EWB', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => GenerateEWayBillScreen(businessId: widget.businessId),
            ),
          );
          if (result == true) {
            _loadBills();
          }
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = key);
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
