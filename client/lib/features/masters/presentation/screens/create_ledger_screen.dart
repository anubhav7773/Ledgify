import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/models/account_model.dart';

/// Screen for creating and altering accounting Ledgers and Sub-Ledgers (Google Stitch UI).
class CreateLedgerScreen extends StatefulWidget {
  final AccountRepository? repository;
  final String? businessId;

  const CreateLedgerScreen({
    super.key,
    this.repository,
    this.businessId,
  });

  @override
  State<CreateLedgerScreen> createState() => _CreateLedgerScreenState();
}

class _CreateLedgerScreenState extends State<CreateLedgerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AccountRepository _repository;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _creditDaysController = TextEditingController(text: '0');
  final TextEditingController _balanceController = TextEditingController(text: '0.00');

  String _selectedGroup = 'Sundry Debtors';
  String _selectedClassification = 'Asset';
  String _balanceType = 'Dr';
  bool _isSubLedger = false;
  bool _isLoading = false;

  // 28 Standard Tally Groups with default Primary Classification mapping
  final Map<String, String> _tallyGroups = {
    'Capital Account': 'Equity',
    'Reserves & Surplus': 'Equity',
    'Current Assets': 'Asset',
    'Bank Accounts': 'Asset',
    'Cash-in-Hand': 'Asset',
    'Deposits (Asset)': 'Asset',
    'Loans & Advances (Asset)': 'Asset',
    'Stock-in-Hand': 'Asset',
    'Sundry Debtors': 'Asset',
    'Current Liabilities': 'Liability',
    'Duties & Taxes': 'Liability',
    'Provisions': 'Liability',
    'Sundry Creditors': 'Liability',
    'Fixed Assets': 'Asset',
    'Investments': 'Asset',
    'Loans (Liability)': 'Liability',
    'Bank OD A/c': 'Liability',
    'Secured Loans': 'Liability',
    'Unsecured Loans': 'Liability',
    'Suspense A/c': 'Asset',
    'Direct Incomes': 'Income',
    'Sales Accounts': 'Income',
    'Indirect Incomes': 'Income',
    'Direct Expenses': 'Expense',
    'Purchase Accounts': 'Expense',
    'Indirect Expenses': 'Expense',
    'Misc. Expenses (ASSET)': 'Asset',
    'Branch / Divisions': 'Liability',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AccountRepository();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _hsnController.dispose();
    _creditDaysController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _onGroupChanged(String? newGroup) {
    if (newGroup != null && _tallyGroups.containsKey(newGroup)) {
      setState(() {
        _selectedGroup = newGroup;
        _selectedClassification = _tallyGroups[newGroup]!;
        // Auto default balance type based on classification
        if (_selectedClassification == 'Asset' || _selectedClassification == 'Expense') {
          _balanceType = 'Dr';
        } else {
          _balanceType = 'Cr';
        }
      });
    }
  }

  Future<void> _saveLedger() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final double balance = double.tryParse(_balanceController.text.trim()) ?? 0.00;
      final int creditDays = int.tryParse(_creditDaysController.text.trim()) ?? 0;

      final account = AccountModel(
        id: '',
        businessId: widget.businessId ?? '',
        name: _nameController.text.trim(),
        alias: _aliasController.text.trim().isNotEmpty ? _aliasController.text.trim() : null,
        groupName: _selectedGroup,
        primaryClassification: _selectedClassification,
        isSubLedger: _isSubLedger,
        openingBalance: balance,
        openingBalanceType: _balanceType,
        partyGstin: _gstinController.text.trim().isNotEmpty ? _gstinController.text.trim() : null,
        partyPan: _panController.text.trim().isNotEmpty ? _panController.text.trim() : null,
        hsnSacCode: _hsnController.text.trim().isNotEmpty ? _hsnController.text.trim() : null,
        creditPeriodDays: creditDays,
        isActive: true,
      );

      await _repository.createLedger(account);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ledger "${account.name}" created successfully!'),
            backgroundColor: AppColors.debitGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ledger: $e'),
            backgroundColor: AppColors.creditRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPartyGroup = _selectedGroup == 'Sundry Debtors' || _selectedGroup == 'Sundry Creditors';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Create New Ledger', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ledger Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ledger Name *',
                    hintText: 'e.g., Sharma Enterprises',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ledger name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Alias / Tag
                TextFormField(
                  controller: _aliasController,
                  decoration: const InputDecoration(
                    labelText: 'Alias (Optional)',
                    hintText: 'e.g., Sharma Ji',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Parent Group Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGroup,
                  decoration: const InputDecoration(
                    labelText: 'Under Group *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  items: _tallyGroups.keys.map((group) {
                    return DropdownMenuItem<String>(
                      value: group,
                      child: Text('$group (${_tallyGroups[group]})'),
                    );
                  }).toList(),
                  onChanged: _onGroupChanged,
                ),
                const SizedBox(height: 16),

                // Sub-Ledger Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Is Sub-Ledger?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Mark if this rolls into a parent group ledger', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  value: _isSubLedger,
                  onChanged: (val) => setState(() => _isSubLedger = val),
                ),
                const Divider(height: 24),

                // Opening Balance & Dr/Cr Toggle
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _balanceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Opening Balance',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Enter valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Dr', label: Text('Dr', style: TextStyle(fontWeight: FontWeight.w700))),
                          ButtonSegment(value: 'Cr', label: Text('Cr', style: TextStyle(fontWeight: FontWeight.w700))),
                        ],
                        selected: {_balanceType},
                        onSelectionChanged: (set) {
                          setState(() => _balanceType = set.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Statutory & Compliance Section (Parties)
                if (isPartyGroup) ...[
                  Text(
                    'Statutory & Tax Details',
                    style: AppTypography.cardHeader.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  // GSTIN
                  TextFormField(
                    controller: _gstinController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Party GSTIN',
                      hintText: '27AAAAA0000A1Z5',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final regex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                        if (!regex.hasMatch(val.trim())) {
                          return 'Enter valid 15-character GSTIN';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // PAN
                  TextFormField(
                    controller: _panController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Party PAN',
                      hintText: 'AAAAA0000A',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card_outlined),
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final regex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                        if (!regex.hasMatch(val.trim())) {
                          return 'Enter valid 10-character PAN';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Credit Period
                  TextFormField(
                    controller: _creditDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Credit Period (Days)',
                      hintText: 'e.g., 30',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // HSN/SAC for Sales / Purchase / Services
                if (_selectedGroup == 'Sales Accounts' ||
                    _selectedGroup == 'Purchase Accounts' ||
                    _selectedGroup == 'Direct Incomes' ||
                    _selectedGroup == 'Direct Expenses') ...[
                  TextFormField(
                    controller: _hsnController,
                    decoration: const InputDecoration(
                      labelText: 'HSN / SAC Code (Optional)',
                      hintText: 'e.g., 998311',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 24),

                // Submit Button (48dp Touch Target)
                SizedBox(
                  height: AppColors.minTouchTargetSize,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isLoading ? 'Saving Ledger...' : 'Save Ledger',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isLoading ? null : _saveLedger,
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
