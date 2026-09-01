import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../vouchers/data/repositories/voucher_repository.dart';
import '../../../vouchers/domain/models/voucher_line_item_model.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../data/repositories/direct_tax_repository.dart';
import '../domain/models/tds_tcs_entry_model.dart';

/// Modal dialog for recording government Challan tax payments (e.g. ITNS 281) and creating double-entry payment vouchers.
class RecordChallanPaymentDialog extends StatefulWidget {
  final List<TdsTcsEntryModel> pendingEntries;
  final String? businessId;
  final DirectTaxRepository? repository;
  final VoucherRepository? voucherRepository;
  final AccountRepository? accountRepository;

  const RecordChallanPaymentDialog({
    super.key,
    required this.pendingEntries,
    this.businessId,
    this.repository,
    this.voucherRepository,
    this.accountRepository,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<TdsTcsEntryModel> pendingEntries,
    String? businessId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => RecordChallanPaymentDialog(
        pendingEntries: pendingEntries,
        businessId: businessId,
      ),
    );
  }

  @override
  State<RecordChallanPaymentDialog> createState() => _RecordChallanPaymentDialogState();
}

class _RecordChallanPaymentDialogState extends State<RecordChallanPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final DirectTaxRepository _repository;
  late final VoucherRepository _voucherRepository;
  late final AccountRepository _accountRepository;

  final Set<String> _selectedEntryIds = {};
  late final TextEditingController _bsrCodeController;
  late final TextEditingController _challanNoController;
  DateTime _paymentDate = DateTime.now();

  List<AccountModel> _bankAccounts = [];
  String? _selectedBankAccountId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DirectTaxRepository();
    _voucherRepository = widget.voucherRepository ?? VoucherRepository();
    _accountRepository = widget.accountRepository ?? AccountRepository();

    _bsrCodeController = TextEditingController();
    _challanNoController = TextEditingController();

    // Pre-select all entries by default
    _selectedEntryIds.addAll(widget.pendingEntries.map((e) => e.id));
    _loadBankAccounts();
  }

  @override
  void dispose() {
    _bsrCodeController.dispose();
    _challanNoController.dispose();
    super.dispose();
  }

  Future<void> _loadBankAccounts() async {
    try {
      final accounts = await _accountRepository.fetchAccounts(groupName: 'Bank Accounts');
      if (mounted && accounts.isNotEmpty) {
        setState(() {
          _bankAccounts = accounts;
          _selectedBankAccountId = accounts.first.id;
        });
      }
    } catch (_) {}
  }

  double get _totalPayableAmount {
    return widget.pendingEntries
        .where((e) => _selectedEntryIds.contains(e.id))
        .fold(0.0, (sum, e) => sum + e.taxAmount);
  }

  Future<void> _submitChallanPayment() async {
    if (!_formKey.currentState!.validate() || _selectedEntryIds.isEmpty || _selectedBankAccountId == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final challanReference = '${_bsrCodeController.text.trim()}-${_challanNoController.text.trim()}';

      // 1. Link Challan details across selected TDS/TCS entries
      await _repository.linkChallanPayment(
        entryIds: _selectedEntryIds.toList(),
        challanNumber: challanReference,
        challanDate: _paymentDate,
      );

      // 2. Create Double-Entry Payment Voucher
      final voucherTypes = await _voucherRepository.fetchVoucherTypes();
      final paymentType = voucherTypes.firstWhere(
        (t) => t.category == 'Payment',
        orElse: () => voucherTypes.first,
      );

      final accounts = await _accountRepository.fetchAccounts();
      final tdsPayableAcc = accounts.firstWhere(
        (a) => a.name.toLowerCase().contains('tds') || a.groupName == 'Duties & Taxes',
        orElse: () => accounts.first,
      );

      final voucher = VoucherModel(
        id: '',
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
        voucherTypeId: paymentType.id,
        voucherNumber: 'TDS-CHAL-${_challanNoController.text.trim()}',
        voucherDate: _paymentDate,
        narration: 'TDS Payment Challan ITNS 281 Ref: $challanReference',
        referenceNumber: challanReference,
        lineItems: [
          VoucherLineItemModel(
            id: '',
            businessId: widget.businessId ?? '',
            voucherId: '',
            accountId: tdsPayableAcc.id,
            entryType: 'Dr',
            amount: _totalPayableAmount,
            itemDescription: 'Government Tax Deposit Challan $challanReference',
          ),
          VoucherLineItemModel(
            id: '',
            businessId: widget.businessId ?? '',
            voucherId: '',
            accountId: _selectedBankAccountId!,
            entryType: 'Cr',
            amount: _totalPayableAmount,
            itemDescription: 'Bank Payout for TDS Challan',
          ),
        ],
      );

      await _voucherRepository.createVoucher(voucher);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record challan payment: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Record Challan Payment / चालान भुगतान', style: LedgifyTypography.cardHeader),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entries Multi-Select Checklist
              const Text('Select Deductions to Pay:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),

              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  border: Border.all(color: LedgifyColors.surfaceVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.pendingEntries.length,
                  itemBuilder: (context, index) {
                    final item = widget.pendingEntries[index];
                    final isChecked = _selectedEntryIds.contains(item.id);

                    return CheckboxListTile(
                      dense: true,
                      value: isChecked,
                      title: Text('${item.sectionCode}: PAN ${item.partyPan}'),
                      subtitle: Text('Assessable: ₹${item.assessedAmount.toStringAsFixed(2)}'),
                      secondary: Text(
                        '₹${item.taxAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: LedgifyColors.creditRed),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedEntryIds.add(item.id);
                          } else {
                            _selectedEntryIds.remove(item.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Total Amount Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LedgifyColors.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Tax Deposit Amount:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('₹${_totalPayableAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // BSR Code and Challan Serial No Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bsrCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'BSR Code (7-digit)', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().length != 7 ? '7 digits' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _challanNoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Challan Serial No', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bank Ledger Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBankAccountId,
                decoration: const InputDecoration(
                  labelText: 'Paid via Bank Account *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: _bankAccounts.map((a) {
                  return DropdownMenuItem(value: a.id, child: Text(a.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedBankAccountId = val),
                validator: (val) => val == null ? 'Select bank' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LedgifyColors.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(140, LedgifyColors.minTouchTargetSize),
          ),
          onPressed: _isProcessing ? null : _submitChallanPayment,
          child: Text(_isProcessing ? 'Recording...' : 'Record Payment / दर्ज करें'),
        ),
      ],
    );
  }
}
