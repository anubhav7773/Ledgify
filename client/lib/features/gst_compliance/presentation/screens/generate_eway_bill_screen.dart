import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../vouchers/data/repositories/voucher_repository.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../data/repositories/eway_bill_repository.dart';
import '../domain/models/eway_bill_model.dart';
import '../domain/services/ewb_validity_calculator.dart';
import '../domain/services/eway_bill_service.dart';

/// Screen for generating statutory E-Way Bills (FORM GST EWB-01).
/// Enforces Rule 138(10) distance validity calculations and <10 km intra-state exemptions.
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
    try {
      final vouchers = await _voucherRepository.fetchVouchers(limit: 50);
      if (mounted) {
        setState(() {
          _salesVouchers = vouchers;
          if (_selectedVoucherId == null && vouchers.isNotEmpty) {
            _selectedVoucherId = vouchers.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _calculatedValidityDays {
    final distance = double.tryParse(_distanceController.text.trim()) ?? 0.0;
    return EwbValidityCalculator.calculateValidityDays(distance, isOdc: _isOdc);
  }

  Future<void> _generateEwb() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isUnder10KmExempt && _vehicleNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle number is mandatory for Part B (or check <10km exemption).'),
          backgroundColor: LedgifyColors.creditRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final distance = double.tryParse(_distanceController.text.trim()) ?? 0.0;
      final ewbNumber = EWayBillService.generateMockEwbNumber();
      final now = DateTime.now();
      final validUpto = EwbValidityCalculator.computeExpiryDate(now, _calculatedValidityDays);

      final ewb = EWayBillModel(
        id: '',
        businessId: widget.businessId ?? '',
        voucherId: _selectedVoucherId!,
        ewbNumber: ewbNumber,
        ewbDate: now,
        validUpto: validUpto,
        vehicleNumber: _isUnder10KmExempt ? 'DEF_INTRA_10KM' : _vehicleNumberController.text.trim().toUpperCase(),
        transporterName: _transporterNameController.text.trim().isNotEmpty ? _transporterNameController.text.trim() : null,
        distanceKm: distance,
        partAData: {
          'transDistance': distance,
          'transporterId': _transporterIdController.text.trim(),
          'transporterName': _transporterNameController.text.trim(),
        },
        partBData: {
          'vehicleNo': _isUnder10KmExempt ? 'DEF_INTRA_10KM' : _vehicleNumberController.text.trim().toUpperCase(),
          'isOdc': _isOdc,
          'transportMode': '1',
        },
      );

      await _ewbRepository.createEWayBill(ewb, isOdc: _isOdc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('E-Way Bill $ewbNumber generated! Valid for $_calculatedValidityDays days.'),
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate EWB: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate E-Way Bill / नया ई-वे बिल', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(LedgifyColors.standardPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Select Parent Voucher
                      DropdownButtonFormField<String>(
                        value: _selectedVoucherId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Sales Voucher / वाउचर चुनें *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                        items: _salesVouchers.map((v) {
                          final amt = v.totalCreditAmount > 0 ? v.totalCreditAmount : v.totalDebitAmount;
                          return DropdownMenuItem(
                            value: v.id,
                            child: Text('${v.voucherNumber} (₹${amt.toStringAsFixed(2)})'),
                          );
                        }).toList(),
                        validator: (val) => val == null ? 'Please select a voucher' : null,
                        onChanged: (newId) => setState(() => _selectedVoucherId = newId),
                      ),
                      const SizedBox(height: 16),

                      // Distance & Validity Live Preview Card
                      Card(
                        color: LedgifyColors.primaryContainer.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: LedgifyColors.primaryBlue, width: 0.8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              const Icon(Icons.speed, color: LedgifyColors.primaryBlue, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Statutory Rule 138(10) Validity Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LedgifyColors.secondarySlate)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Valid for $_calculatedValidityDays Day(s) / $_calculatedValidityDays दिन वैध (${_isOdc ? "20km/day (ODC)" : "200km/day"})',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Distance in KM & ODC Switch
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _distanceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Distance (KM) / दूरी *',
                                suffixText: 'KM',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.straighten_outlined),
                              ),
                              validator: (val) {
                                final numVal = double.tryParse(val ?? '');
                                if (numVal == null || numVal <= 0) return 'Enter valid KM';
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilterChip(
                              label: const Text('ODC Cargo'),
                              selected: _isOdc,
                              onSelected: (val) => setState(() => _isOdc = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Transporter Name & ID
                      TextFormField(
                        controller: _transporterNameController,
                        decoration: const InputDecoration(
                          labelText: 'Transporter Name / ट्रांसपोर्टर नाम (Optional)',
                          hintText: 'e.g., VRL Logistics',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Part B: Road Vehicle Number
                      TextFormField(
                        controller: _vehicleNumberController,
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_isUnder10KmExempt,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number (Part B) / वाहन संख्या *',
                          hintText: 'e.g., MH04AB1234',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // <10 km Exemption Checkbox
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Distance < 10 km intra-state / 10 किमी से कम', style: TextStyle(fontSize: 14)),
                        subtitle: const Text('Exempts vehicle details (Part B) for short intra-state transit to transport hub'),
                        value: _isUnder10KmExempt,
                        onChanged: (val) => setState(() => _isUnder10KmExempt = val ?? false),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button (48dp Touch Target)
                      SizedBox(
                        height: LedgifyColors.minTouchTargetSize,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LedgifyColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add_road),
                          label: Text(
                            _isSaving ? 'Generating...' : 'Generate E-Way Bill / ई-वे बिल बनाएं',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: _isSaving ? null : _generateEwb,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
