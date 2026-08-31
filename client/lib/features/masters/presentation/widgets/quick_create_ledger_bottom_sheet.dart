import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/models/account_model.dart';

/// Lightweight modal sheet for fast on-the-fly ledger creation directly from AI intake workflows.
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
      backgroundColor: Colors.transparent,
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
          SnackBar(content: Text('Failed to create ledger: $e'), backgroundColor: LedgifyColors.creditRed),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quick Create Ledger / नया खाता बनाएं', style: LedgifyTypography.cardHeader),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 16),

            // Party Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Party Name / व्यापारी नाम *',
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
                labelText: 'Under Group / समूह *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Sundry Creditors', child: Text('Sundry Creditors (लेनदार / Supplier)')),
                DropdownMenuItem(value: 'Sundry Debtors', child: Text('Sundry Debtors (देनदार / Customer)')),
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
              height: LedgifyColors.minTouchTargetSize,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LedgifyColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isCreating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_link),
                label: Text(
                  _isCreating ? 'Creating...' : 'Create & Link / खाता बनाएं और जोड़ें',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: _isCreating ? null : _createAndLink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
