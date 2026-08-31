import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import 'package:ledgify/features/masters/domain/models/voucher_type_model.dart';
import '../../data/repositories/voucher_repository.dart';
import '../../domain/models/voucher_line_item_model.dart';
import '../../domain/models/voucher_model.dart';
import '../widgets/debit_credit_balance_bar.dart';

/// Screen for manual creation of Double-Entry balanced accounting vouchers (Google Stitch UI).
class VoucherEntryScreen extends StatefulWidget {
  final VoucherRepository? voucherRepository;
  final AccountRepository? accountRepository;
  final String? businessId;
  final String? existingVoucherId;

  const VoucherEntryScreen({
    super.key,
    this.voucherRepository,
    this.accountRepository,
    this.businessId,
    this.existingVoucherId,
  });

  @override
  State<VoucherEntryScreen> createState() => _VoucherEntryScreenState();
}

class _LineItemEntry {
  String? accountId;
  String entryType; // 'Dr' or 'Cr'
  final TextEditingController amountController;
  final TextEditingController descController;

  _LineItemEntry({
    this.accountId,
    this.entryType = 'Dr',
    String initialAmount = '',
    String initialDesc = '',
  })  : amountController = TextEditingController(text: initialAmount),
        descController = TextEditingController(text: initialDesc);

  double get amount => double.tryParse(amountController.text.trim()) ?? 0.00;

  void dispose() {
    amountController.dispose();
    descController.dispose();
  }
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final VoucherRepository _voucherRepository;
  late final AccountRepository _accountRepository;

  final TextEditingController _voucherNumberController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();
  final TextEditingController _referenceNumberController = TextEditingController();

  DateTime _voucherDate = DateTime.now();
  String _selectedVoucherType = 'Payment';
  String _selectedVoucherTypeId = '';
  bool _isLoadingMasters = true;
  bool _isSaving = false;

  List<AccountModel> _availableAccounts = [];
  final List<_LineItemEntry> _lineItems = [];

  final List<String> _voucherTypeNames = [
    'Sales',
    'Purchase',
    'Payment',
    'Receipt',
    'Contra',
    'Journal',
    'Debit Note',
    'Credit Note',
  ];

  @override
  void initState() {
    super.initState();
    _voucherRepository = widget.voucherRepository ?? VoucherRepository();
    _accountRepository = widget.accountRepository ?? AccountRepository();

    // Pre-populate with 2 default rows (1 Dr, 1 Cr)
    _lineItems.add(_LineItemEntry(entryType: 'Dr'));
    _lineItems.add(_LineItemEntry(entryType: 'Cr'));

    _generateVoucherNumber();
    _loadMasters();
  }

  @override
  void dispose() {
    _voucherNumberController.dispose();
    _narrationController.dispose();
    _referenceNumberController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _generateVoucherNumber() {
    final prefix = _selectedVoucherType.substring(0, 3).toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _voucherNumberController.text = '$prefix-$timestamp';
  }

  Future<void> _loadMasters() async {
    try {
      final accounts = await _accountRepository.fetchAccounts();
      final types = await _voucherRepository.fetchVoucherTypes();

      if (mounted) {
        setState(() {
          _availableAccounts = accounts;
          if (types.isNotEmpty) {
            final matched = types.firstWhere(
              (t) => t.category == _selectedVoucherType,
              orElse: () => types.first,
            );
            _selectedVoucherTypeId = matched.id;
          }
          _isLoadingMasters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    }
  }

  double get _totalDebit {
    return _lineItems
        .where((item) => item.entryType == 'Dr')
        .fold(0.00, (sum, item) => sum + item.amount);
  }

  double get _totalCredit {
    return _lineItems
        .where((item) => item.entryType == 'Cr')
        .fold(0.00, (sum, item) => sum + item.amount);
  }

  bool get _isBalanced {
    if (_lineItems.length < 2) return false;
    final diff = (_totalDebit - _totalCredit).abs();
    return diff < 0.001 && _totalDebit > 0;
  }

  void _addLineItem() {
    setState(() {
      final defaultType = _totalDebit > _totalCredit ? 'Cr' : 'Dr';
      _lineItems.add(_LineItemEntry(entryType: defaultType));
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A voucher must contain at least 2 line items for double-entry.'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  Future<void> _saveVoucher() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot save: Total Debits (₹${_totalDebit.toStringAsFixed(2)}) '
              'do not equal Total Credits (₹${_totalCredit.toStringAsFixed(2)}).'),
          backgroundColor: AppColors.creditRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final lineModels = _lineItems.map((item) {
        return VoucherLineItemModel(
          id: '',
          businessId: widget.businessId ?? '',
          voucherId: '',
          accountId: item.accountId!,
          entryType: item.entryType,
          amount: item.amount,
          itemDescription: item.descController.text.trim().isNotEmpty
              ? item.descController.text.trim()
              : null,
        );
      }).toList();

      final voucher = VoucherModel(
        id: '',
        businessId: widget.businessId ?? '',
        voucherTypeId: _selectedVoucherTypeId,
        voucherNumber: _voucherNumberController.text.trim(),
        voucherDate: _voucherDate,
        narration: _narrationController.text.trim().isNotEmpty
            ? _narrationController.text.trim()
            : null,
        referenceNumber: _referenceNumberController.text.trim().isNotEmpty
            ? _referenceNumberController.text.trim()
            : null,
        lineItems: lineModels,
      );

      await _voucherRepository.createVoucher(voucher);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher ${_voucherNumberController.text} posted & balanced successfully!'),
            backgroundColor: AppColors.debitGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post voucher: $e'),
            backgroundColor: AppColors.creditRed,
          ),
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Voucher Entry', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: _isLoadingMasters
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Top Live Balancing Indicator Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: DebitCreditBalanceBar(
                        totalDebit: _totalDebit,
                        totalCredit: _totalCredit,
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Voucher Type & Voucher Number Row
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedVoucherType,
                                  decoration: const InputDecoration(
                                    labelText: 'Voucher Type *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _voucherTypeNames.map((type) {
                                    return DropdownMenuItem(value: type, child: Text(type));
                                  }).toList(),
                                  onChanged: (newType) {
                                    if (newType != null) {
                                      setState(() {
                                        _selectedVoucherType = newType;
                                        _generateVoucherNumber();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _voucherNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Voucher No. *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Voucher Date Picker
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _voucherDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => _voucherDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Voucher Date *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                '${_voucherDate.day.toString().padLeft(2, '0')}/${_voucherDate.month.toString().padLeft(2, '0')}/${_voucherDate.year}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Line Items Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Line Items', style: AppTypography.cardHeader),
                              TextButton.icon(
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: const Text('Add Row', style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: _addLineItem,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Dynamic Line Items List
                          ..._lineItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Dr / Cr Selector
                                        SizedBox(
                                          width: 78,
                                          child: DropdownButtonFormField<String>(
                                            value: item.entryType,
                                            decoration: const InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                              border: OutlineInputBorder(),
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'Dr', child: Text('Dr', style: TextStyle(color: AppColors.debitGreen, fontWeight: FontWeight.w800))),
                                              DropdownMenuItem(value: 'Cr', child: Text('Cr', style: TextStyle(color: AppColors.creditRed, fontWeight: FontWeight.w800))),
                                            ],
                                            onChanged: (newVal) {
                                              if (newVal != null) {
                                                setState(() => item.entryType = newVal);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Account Selector Dropdown
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: item.accountId,
                                            hint: const Text('Select Ledger *'),
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                              border: OutlineInputBorder(),
                                            ),
                                            items: _availableAccounts.map((acc) {
                                              return DropdownMenuItem(
                                                value: acc.id,
                                                child: Text(
                                                  '${acc.name} (${acc.groupName})',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            validator: (val) => val == null ? 'Select ledger' : null,
                                            onChanged: (newAcc) {
                                              setState(() => item.accountId = newAcc);
                                            },
                                          ),
                                        ),

                                        // Delete Button
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.creditRed, size: 20),
                                          tooltip: 'Remove Row',
                                          onPressed: () => _removeLineItem(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Amount & Description Row
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: item.amountController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(
                                              labelText: 'Amount (₹) *',
                                              prefixText: '₹ ',
                                              border: OutlineInputBorder(),
                                            ),
                                            validator: (val) {
                                              if (val == null || val.trim().isEmpty) return 'Required';
                                              final numVal = double.tryParse(val.trim());
                                              if (numVal == null || numVal <= 0) return 'Must be > 0';
                                              return null;
                                            },
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: item.descController,
                                            decoration: const InputDecoration(
                                              labelText: 'Description (Optional)',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 12),

                          // Narration Input
                          TextFormField(
                            controller: _narrationController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Narration (Optional)',
                              hintText: 'e.g., Being payment made towards invoice #1024',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    // Save Voucher Button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: SizedBox(
                        height: AppColors.minTouchTargetSize,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isBalanced
                                ? AppColors.primary
                                : AppColors.textTertiary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _isSaving
                                ? 'Posting Transaction...'
                                : _isBalanced
                                    ? 'Post Voucher'
                                    : 'Unbalanced (₹${(_totalDebit - _totalCredit).abs().toStringAsFixed(2)})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: (_isSaving || !_isBalanced) ? null : _saveVoucher,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
