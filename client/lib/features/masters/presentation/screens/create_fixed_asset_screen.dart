import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/fixed_asset_repository.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/fixed_asset_model.dart';

/// Screen for creating and registering Fixed Assets under Schedule II (Companies Act 2013).
/// Enforces max 5% residual value cap, shift multipliers, and CGST Sec 16(3) ITC exclusivity.
class CreateFixedAssetScreen extends StatefulWidget {
  final FixedAssetRepository? fixedAssetRepository;
  final AccountRepository? accountRepository;
  final String? businessId;

  const CreateFixedAssetScreen({
    super.key,
    this.fixedAssetRepository,
    this.accountRepository,
    this.businessId,
  });

  @override
  State<CreateFixedAssetScreen> createState() => _CreateFixedAssetScreenState();
}

class _CreateFixedAssetScreenState extends State<CreateFixedAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FixedAssetRepository _fixedAssetRepository;
  late final AccountRepository _accountRepository;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _residualController = TextEditingController(text: '0.00');
  final TextEditingController _lifeController = TextEditingController(text: '15');

  String? _selectedAccountId;
  String _selectedCategory = 'General Plant & Machinery';
  String _selectedShift = 'Single';
  DateTime _purchaseDate = DateTime.now();
  bool _isNesd = false;
  bool _itcClaimed = false;
  bool _isLoadingMasters = true;
  bool _isSaving = false;

  List<AccountModel> _fixedAssetAccounts = [];

  // Schedule II Categories mapping to (Useful Life Years, is_nesd)
  final Map<String, Map<String, dynamic>> _scheduleIICategories = {
    'General Plant & Machinery': {'life': 15.0, 'nesd': false},
    'Continuous Process Plant': {'life': 8.0, 'nesd': true},
    'Computers & Laptops': {'life': 3.0, 'nesd': true},
    'Servers & Networks': {'life': 6.0, 'nesd': true},
    'Non-Factory Building (RCC)': {'life': 60.0, 'nesd': true},
    'Factory Buildings': {'life': 30.0, 'nesd': true},
    'Furniture & Fittings': {'life': 10.0, 'nesd': true},
    'Commercial Vehicles (Hire)': {'life': 6.0, 'nesd': true},
    'Non-Commercial Vehicles': {'life': 8.0, 'nesd': true},
    'Office Equipment': {'life': 5.0, 'nesd': true},
  };

  @override
  void initState() {
    super.initState();
    _fixedAssetRepository = widget.fixedAssetRepository ?? FixedAssetRepository();
    _accountRepository = widget.accountRepository ?? AccountRepository();
    _loadMasters();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _residualController.dispose();
    _lifeController.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final accounts = await _accountRepository.fetchAccounts(groupName: 'Fixed Assets');
      if (mounted) {
        setState(() {
          _fixedAssetAccounts = accounts;
          if (accounts.isNotEmpty) {
            _selectedAccountId = accounts.first.id;
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

  void _onCategoryChanged(String? newCategory) {
    if (newCategory != null && _scheduleIICategories.containsKey(newCategory)) {
      final config = _scheduleIICategories[newCategory]!;
      setState(() {
        _selectedCategory = newCategory;
        _lifeController.text = config['life'].toString();
        _isNesd = config['nesd'] as bool;
        if (_isNesd) {
          _selectedShift = 'Single';
        }
      });
    }
  }

  void _onCostChanged(String val) {
    final cost = double.tryParse(val.trim()) ?? 0.00;
    // Auto populate recommended 5% residual value default
    if (cost > 0 && double.tryParse(_residualController.text) == 0.0) {
      _residualController.text = (cost * 0.05).toStringAsFixed(2);
    }
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final cost = double.tryParse(_costController.text.trim()) ?? 0.00;
    final residual = double.tryParse(_residualController.text.trim()) ?? 0.00;
    final life = double.tryParse(_lifeController.text.trim()) ?? 1.0;

    if (residual > (cost * 0.05)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule II Violation: Residual value (₹$residual) cannot exceed 5% of cost (₹${(cost * 0.05).toStringAsFixed(2)}).'),
          backgroundColor: LedgifyColors.creditRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final asset = FixedAssetModel(
        id: '',
        businessId: widget.businessId ?? '',
        assetAccountId: _selectedAccountId!,
        assetName: _nameController.text.trim(),
        category: _selectedCategory,
        purchaseDate: _purchaseDate,
        originalCost: cost,
        residualValue: residual,
        usefulLifeYears: life,
        isNesd: _isNesd,
        shiftWorking: _selectedShift,
        itcClaimedFlag: _itcClaimed,
      );

      await _fixedAssetRepository.createFixedAsset(asset);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asset "${asset.assetName}" registered under Schedule II!'),
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register asset: $e'),
            backgroundColor: LedgifyColors.creditRed,
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
      appBar: AppBar(
        title: const Text('New Fixed Asset / नई संपत्ति', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
      ),
      body: _isLoadingMasters
          ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(LedgifyColors.standardPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Asset Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Asset Name *',
                          hintText: 'e.g., CNC Milling Machine #02',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Asset name required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Schedule II Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Schedule II Category *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _scheduleIICategories.keys.map((cat) {
                          final config = _scheduleIICategories[cat]!;
                          return DropdownMenuItem(
                            value: cat,
                            child: Text('$cat (${config['life']} yrs${config['nesd'] ? " • NESD" : ""})'),
                          );
                        }).toList(),
                        onChanged: _onCategoryChanged,
                      ),
                      const SizedBox(height: 16),

                      // Linked Fixed Asset Ledger
                      DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Asset Ledger *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.book_outlined),
                        ),
                        items: _fixedAssetAccounts.map((acc) {
                          return DropdownMenuItem(value: acc.id, child: Text(acc.name));
                        }).toList(),
                        validator: (val) => val == null ? 'Select asset ledger' : null,
                        onChanged: (newId) => setState(() => _selectedAccountId = newId),
                      ),
                      const SizedBox(height: 16),

                      // Purchase Date Picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _purchaseDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _purchaseDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Purchase Date *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            '${_purchaseDate.day.toString().padLeft(2, '0')}/${_purchaseDate.month.toString().padLeft(2, '0')}/${_purchaseDate.year}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Original Cost & Residual Value
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Original Cost (₹) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: _onCostChanged,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Cost required';
                                final numVal = double.tryParse(val.trim());
                                if (numVal == null || numVal <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _residualController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Residual Value (Max 5%) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                final numVal = double.tryParse(val.trim());
                                if (numVal == null || numVal < 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Useful Life Years & Shift Working
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lifeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Useful Life (Years) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                              validator: (val) {
                                final numVal = double.tryParse(val ?? '');
                                if (numVal == null || numVal <= 0) return 'Invalid years';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedShift,
                              decoration: InputDecoration(
                                labelText: 'Shift Working / पाली',
                                border: const OutlineInputBorder(),
                                enabled: !_isNesd,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Single', child: Text('Single (1.0x)')),
                                DropdownMenuItem(value: 'Double', child: Text('Double (1.5x)')),
                                DropdownMenuItem(value: 'Triple', child: Text('Triple (2.0x)')),
                              ],
                              onChanged: _isNesd ? null : (val) => setState(() => _selectedShift = val ?? 'Single'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // CGST Sec 16(3) ITC Claimed Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ITC Claimed on Capital Goods? (CGST Sec 16(3))'),
                        subtitle: const Text('If ON, ensures capital cost excludes GST to prevent double tax deduction'),
                        value: _itcClaimed,
                        onChanged: (val) => setState(() => _itcClaimed = val),
                      ),
                      const SizedBox(height: 24),

                      // Save Asset Button (48dp Touch Target)
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
                              : const Icon(Icons.check),
                          label: Text(
                            _isSaving ? 'Registering Asset...' : 'Register Fixed Asset / संपत्ति दर्ज करें',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: _isSaving ? null : _saveAsset,
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
