import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/models/account_model.dart';

/// Lightweight modal sheet for fast on-the-fly ledger creation directly from AI intake workflows (Google Stitch UI).
class QuickCreateLedgerBottomSheet extends StatefulWidget {
  final String initialName;
  final String? initialGstin;
  final String? initialPan;
  final String initialGroup; // 'Sundry Creditors' or 'Sundry Debtors'
  final String? businessId;
  final AccountRepository? repository;

  const QuickCreateLedgerBottomSheet({
    super.key,
    required this.initialName,
    this.initialGstin,
    this.initialPan,
    this.initialGroup = 'Sundry Creditors',
    this.businessId,
    this.repository,
  });

  static Future<AccountModel?> show(
    BuildContext context, {
    required String initialName,
    String? initialGstin,
    String? initialPan,
    String initialGroup = 'Sundry Creditors',
    String? businessId,
    AccountRepository? repository,
  }) {
    return showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QuickCreateLedgerBottomSheet(
        initialName: initialName,
        initialGstin: initialGstin,
        initialPan: initialPan,
        initialGroup: initialGroup,
        businessId: businessId,
        repository: repository,
      ),
    );
  }

  @override
  State<QuickCreateLedgerBottomSheet> createState() => _QuickCreateLedgerBottomSheetState();
}

class _QuickCreateLedgerBottomSheetState extends State<QuickCreateLedgerBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final AccountRepository _repository;

  late final TextEditingController _nameController;
  late final TextEditingController _gstinController;
  late final TextEditingController _panController;
  late String _selectedGroup;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AccountRepository();
    _nameController = TextEditingController(text: widget.initialName);
    _gstinController = TextEditingController(text: widget.initialGstin ?? '');
    _panController = TextEditingController(text: widget.initialPan ?? '');
    _selectedGroup = widget.initialGroup;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _createAndLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final isDebtor = _selectedGroup == 'Sundry Debtors';
      final account = AccountModel(
        id: '',
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
        name: _nameController.text.trim(),
        groupName: _selectedGroup,
        primaryClassification: isDebtor ? 'Asset' : 'Liability',
        openingBalance: 0.00,
        openingBalanceType: isDebtor ? 'Dr' : 'Cr',
        partyGstin: _gstinController.text.trim().isNotEmpty ? _gstinController.text.trim() : null,
        partyPan: _panController.text.trim().isNotEmpty ? _panController.text.trim() : null,
        isActive: true,
      );

      final created = await _repository.createLedger(account);

      if (mounted) {
        Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create ledger: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Quick Create Ledger', style: AppTypography.cardHeader),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Party Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Party Name *',
                  hintText: 'e.g., Apex Distributors',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Parent Group Dropdown
              DropdownButtonFormField<String>(
                value: _selectedGroup,
                decoration: const InputDecoration(
                  labelText: 'Under Group *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Sundry Creditors', child: Text('Sundry Creditors (Supplier / Vendor)')),
                  DropdownMenuItem(value: 'Sundry Debtors', child: Text('Sundry Debtors (Customer)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedGroup = val);
                },
              ),
              const SizedBox(height: 12),

              // GSTIN & PAN Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gstinController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _panController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'PAN (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button (48dp Touch Target)
              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isCreating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_link_rounded),
                  label: Text(
                    _isCreating ? 'Creating Ledger...' : 'Create & Link Ledger',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _isCreating ? null : _createAndLink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
