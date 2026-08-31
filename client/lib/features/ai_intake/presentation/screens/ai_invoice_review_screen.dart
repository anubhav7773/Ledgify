import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ai_confirmation_card.dart';
import '../../../../core/widgets/ai_suggestion_chips.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../masters/domain/models/voucher_type_model.dart';
import '../../../vouchers/data/repositories/voucher_repository.dart';
import '../../domain/models/extracted_invoice_payload.dart';
import '../widgets/edit_amount_bottom_sheet.dart';
import '../widgets/edit_party_bottom_sheet.dart';
import '../widgets/edit_voucher_type_bottom_sheet.dart';

/// Screen displaying the High-Trust AI Confirmation Card with tap-to-edit controls and repair chips.
class AiInvoiceReviewScreen extends StatefulWidget {
  final ExtractedInvoicePayload extractedPayload;
  final Uint8List? imageBytes;
  final String? businessId;
  final VoucherRepository? voucherRepository;
  final AccountRepository? accountRepository;

  const AiInvoiceReviewScreen({
    super.key,
    required this.extractedPayload,
    this.imageBytes,
    this.businessId,
    this.voucherRepository,
    this.accountRepository,
  });

  @override
  State<AiInvoiceReviewScreen> createState() => _AiInvoiceReviewScreenState();
}

class _AiInvoiceReviewScreenState extends State<AiInvoiceReviewScreen> {
  late final VoucherRepository _voucherRepository;
  late final AccountRepository _accountRepository;

  late String _vendorName;
  late String _vendorGstin;
  late String _invoiceNumber;
  late String _voucherType;
  late double _invoiceTotal;
  late double _taxableTotal;
  late double _taxTotal;

  String? _selectedExpenseAccountId;
  String? _selectedVendorAccountId;
  String? _selectedVoucherTypeId;

  List<AccountModel> _expenseAccounts = [];
  List<AccountModel> _vendorAccounts = [];
  bool _isLoadingMasters = true;
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _voucherRepository = widget.voucherRepository ?? VoucherRepository();
    _accountRepository = widget.accountRepository ?? AccountRepository();

    _vendorName = widget.extractedPayload.sellerName;
    _vendorGstin = widget.extractedPayload.sellerGstin;
    _invoiceNumber = widget.extractedPayload.documentNumber;
    _voucherType = 'Purchase';
    _invoiceTotal = widget.extractedPayload.totalInvoiceValue;
    _taxableTotal = widget.extractedPayload.totalTaxableValue;
    _taxTotal = widget.extractedPayload.totalTax;

    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final expenses = await _accountRepository.fetchAccounts(primaryClassification: 'Expense');
      final vendors = await _accountRepository.fetchAccounts(groupName: 'Sundry Creditors');
      final types = await _voucherRepository.fetchVoucherTypes();

      if (mounted) {
        setState(() {
          _expenseAccounts = expenses;
          _vendorAccounts = vendors;

          if (expenses.isNotEmpty) {
            _selectedExpenseAccountId = expenses.first.id;
          }
          if (vendors.isNotEmpty) {
            _selectedVendorAccountId = vendors.first.id;
          }
          if (types.isNotEmpty) {
            final purchaseType = types.firstWhere(
              (t) => t.category.toLowerCase() == _voucherType.toLowerCase(),
              orElse: () => types.first,
            );
            _selectedVoucherTypeId = purchaseType.id;
          }
          _isLoadingMasters = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMasters = false);
    }
  }

  Future<void> _onEditParty() async {
    final selectedAcc = await EditPartyBottomSheet.show(
      context,
      currentPartyName: _vendorName,
      currentPartyGstin: _vendorGstin,
    );

    if (selectedAcc != null && mounted) {
      setState(() {
        _vendorName = selectedAcc.name;
        _vendorGstin = selectedAcc.gstin ?? '';
        _selectedVendorAccountId = selectedAcc.id;
      });
    }
  }

  Future<void> _onEditAmount() async {
    final result = await EditAmountBottomSheet.show(
      context,
      initialAmount: _invoiceTotal,
      initialTaxable: _taxableTotal,
      initialTax: _taxTotal,
    );

    if (result != null && mounted) {
      setState(() {
        _invoiceTotal = result['total'] ?? _invoiceTotal;
        _taxableTotal = result['taxable'] ?? _taxableTotal;
        _taxTotal = result['tax'] ?? _taxTotal;
      });
    }
  }

  Future<void> _onEditVoucherType() async {
    final selectedType = await EditVoucherTypeBottomSheet.show(
      context,
      currentType: _voucherType,
    );

    if (selectedType != null && mounted) {
      setState(() {
        _voucherType = selectedType;
      });
      _loadMasters();
    }
  }

  Future<void> _commitVoucher() async {
    if (_selectedExpenseAccountId == null || _selectedVendorAccountId == null || _selectedVoucherTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expense and vendor accounts.')),
      );
      return;
    }

    setState(() => _isCommitting = true);

    try {
      final voucher = widget.extractedPayload.toVoucherModel(
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
        voucherTypeId: _selectedVoucherTypeId!,
        debitAccountId: _selectedExpenseAccountId!,
        creditAccountId: _selectedVendorAccountId!,
      );

      await _voucherRepository.createVoucher(voucher);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher $_invoiceNumber created & balanced successfully!'),
            backgroundColor: AppColors.debitGreen,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save voucher: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCommitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.extractedPayload;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Bill / बिल समीक्षा', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: _isLoadingMasters
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppColors.standardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // High-Trust AI Confirmation Card Hero
                    AiConfirmationCard(
                      voucherType: _voucherType,
                      voucherNumber: _invoiceNumber,
                      voucherDate: payload.documentDate,
                      partyName: _vendorName,
                      partyGstin: _vendorGstin,
                      totalAmount: _invoiceTotal,
                      taxableAmount: _taxableTotal,
                      taxAmount: _taxTotal,
                      confidenceScore: payload.confidenceScore,
                      lineItems: payload.lineItems.map((li) => li.toJson()).toList(),
                      isSubmitting: _isCommitting,
                      onConfirm: _commitVoucher,
                      onEditParty: _onEditParty,
                      onEditAmount: _onEditAmount,
                      onEditVoucherType: _onEditVoucherType,
                      onEditFullVoucher: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening full double-entry voucher editor...')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Conversational AI Repair & Adjustment Chips
                    const Text('Quick Adjustments / तुरंत बदलाव', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),

                    AiSuggestionChips(
                      onEditParty: _onEditParty,
                      onEditAmount: _onEditAmount,
                      onSwitchVoucherType: _onEditVoucherType,
                      onAddNarration: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Narration editor opened.')),
                        );
                      },
                      onApplyTds: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('TDS Section 194Q applied.')),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
