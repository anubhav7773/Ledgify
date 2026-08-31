import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/vouchers/data/repositories/voucher_repository.dart';
import 'package:ledgify/features/vouchers/domain/models/voucher_model.dart';
import 'package:ledgify/features/gst_compliance/data/repositories/eway_bill_repository.dart';
import 'package:ledgify/features/gst_compliance/domain/models/eway_bill_model.dart';
import 'package:ledgify/features/gst_compliance/domain/services/ewb_validity_calculator.dart';
import 'package:ledgify/features/gst_compliance/domain/services/eway_bill_service.dart';

/// Screen for generating statutory E-Way Bills (FORM GST EWB-01) with Rule 138(10) distance calculations (Google Stitch UI).
class GenerateEWayBillScreen extends StatefulWidget {
  final EWayBillRepository? ewbRepository;
  final VoucherRepository? voucherRepository;
  final String? businessId;
  final String? initialVoucherId;

  const GenerateEWayBillScreen({
    super.key,
    this.ewbRepository,
    this.voucherRepository,
    this.businessId,
    this.initialVoucherId,
  });

  @override
  State<GenerateEWayBillScreen> createState() => _GenerateEWayBillScreenState();
}

class _GenerateEWayBillScreenState extends State<GenerateEWayBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late final EWayBillRepository _ewbRepository;
  late final VoucherRepository _voucherRepository;

  final TextEditingController _distanceController = TextEditingController(text: '150');
  final TextEditingController _transporterIdController = TextEditingController();
  final TextEditingController _transporterNameController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();

  String? _selectedVoucherId;
  List<VoucherModel> _salesVouchers = [];
  bool _isOdc = false;
  bool _isUnder10KmExempt = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ewbRepository = widget.ewbRepository ?? EWayBillRepository();
    _voucherRepository = widget.voucherRepository ?? VoucherRepository();
    _selectedVoucherId = widget.initialVoucherId;
    _loadSalesVouchers();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _transporterIdController.dispose();
    _transporterNameController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesVouchers() async {
    setState(() => _isLoading = true);
    try {
      final vouchers = await _voucherRepository.fetchVouchers();
      final sales = vouchers.where((v) => v.voucherTypeId.toLowerCase().contains('sales') || v.voucherNumber.startsWith('INV') || v.voucherNumber.startsWith('SAL')).toList();

      if (mounted) {
        setState(() {
          _salesVouchers = sales.isNotEmpty ? sales : vouchers;
          if (_selectedVoucherId == null && _salesVouchers.isNotEmpty) {
            _selectedVoucherId = _salesVouchers.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _calculatedValidityDays {
    final distance = double.tryParse(_distanceController.text.trim()) ?? 0.0;
    return EwbValidityCalculator.calculateValidityDays(distance, isOdc: _isOdc);
  }

  Future<void> _submitEwb() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVoucherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an invoice voucher.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double distance = double.tryParse(_distanceController.text.trim()) ?? 100.0;
      final now = DateTime.now();
      final ewbNumber = EWayBillService.generateMockEwbNumber();
      final validUpto = EwbValidityCalculator.computeExpiryDate(now, _calculatedValidityDays);

      final ewb = EWayBillModel(
        id: '',
        businessId: widget.businessId ?? 'BIZ-DEFAULT-01',
        voucherId: _selectedVoucherId!,
        ewbNumber: ewbNumber,
        ewbDate: now,
        validUpto: validUpto,
        transporterPartyId: _transporterIdController.text.trim().isEmpty ? null : _transporterIdController.text.trim(),
        transporterName: _transporterNameController.text.trim().isEmpty ? null : _transporterNameController.text.trim(),
        vehicleNumber: _isUnder10KmExempt ? 'DEF_INTRA_10KM' : _vehicleNumberController.text.trim().toUpperCase(),
        distanceKm: distance,
        partAData: {
          'docNo': _selectedVoucherId,
          'distance': distance,
          'transporterId': _transporterIdController.text.trim(),
        },
        partBData: {
          'vehicleNo': _isUnder10KmExempt ? 'DEF_INTRA_10KM' : _vehicleNumberController.text.trim().toUpperCase(),
          'isOdc': _isOdc,
        },
        status: 'ACTIVE',
      );

      await _ewbRepository.createEWayBill(ewb, isOdc: _isOdc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('E-Way Bill $ewbNumber Generated Successfully!'),
            backgroundColor: AppColors.debitGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate EWB: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Generate E-Way Bill', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppColors.standardPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Voucher Selector Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedVoucherId,
                        decoration: const InputDecoration(
                          labelText: 'Select Invoice / Sales Voucher *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_outlined),
                        ),
                        items: _salesVouchers.map((v) {
                          return DropdownMenuItem(
                            value: v.id,
                            child: Text('${v.voucherNumber} (₹${v.totalDebitAmount > 0 ? v.totalDebitAmount.toStringAsFixed(0) : v.totalCreditAmount.toStringAsFixed(0)})'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedVoucherId = val),
                      ),
                      const SizedBox(height: 16),

                      // Distance & Rule 138 Preview Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Distance & Statutory Validity', style: AppTypography.cardHeader),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _distanceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Road Distance (in KM) *',
                                  hintText: 'e.g., 250',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.route_outlined),
                                  suffixText: 'KM',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Please enter distance';
                                  if (double.tryParse(val) == null) return 'Enter a valid number';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Live Validity Preview
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primaryLight),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.speed_rounded, color: AppColors.primary, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Rule 138(10) Validity Calculation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                          Text(
                                            'Valid for $_calculatedValidityDays Day${_calculatedValidityDays > 1 ? "s" : ""} (${_isOdc ? "20 km/day for ODC" : "200 km/day standard"})',
                                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Part B: Transport & Vehicle Details
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Part B: Transport & Vehicle', style: AppTypography.cardHeader),
                              const SizedBox(height: 12),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Under 10 KM Intra-State Exemption', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                subtitle: const Text('Part B vehicle number not mandatory for transit under 10 km to transporter yard', style: TextStyle(fontSize: 11.5)),
                                value: _isUnder10KmExempt,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setState(() => _isUnder10KmExempt = val),
                              ),

                              if (!_isUnder10KmExempt) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _vehicleNumberController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Vehicle Registration Number *',
                                    hintText: 'e.g., MH04AB1234',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.local_shipping_outlined),
                                  ),
                                  validator: (val) {
                                    if (!_isUnder10KmExempt && (val == null || val.trim().isEmpty)) {
                                      return 'Vehicle number is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _transporterIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Transporter GSTIN / TRANSIN ID',
                                  hintText: 'e.g., 27AABCT1234F1Z1',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _transporterNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Transporter Name',
                                  hintText: 'e.g., VRL Logistics Ltd.',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Generate EWB CTA (48dp Touch Target)
                      SizedBox(
                        height: AppColors.minTouchTargetSize,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.add_road_rounded),
                          label: Text(
                            _isSaving ? 'Registering on NIC Gateway...' : 'Generate E-Way Bill (FORM GST EWB-01)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          onPressed: _isSaving ? null : _submitEwb,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
