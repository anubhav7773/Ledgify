import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../masters/presentation/widgets/quick_create_ledger_bottom_sheet.dart';

/// Modal bottom sheet for changing or re-assigning the extracted vendor/customer party ledger.
class EditPartyBottomSheet extends StatefulWidget {
  final String currentPartyName;
  final String? currentPartyGstin;
  final AccountRepository? accountRepository;

  const EditPartyBottomSheet({
    super.key,
    required this.currentPartyName,
    this.currentPartyGstin,
    this.accountRepository,
  });

  static Future<AccountModel?> show(
    BuildContext context, {
    required String currentPartyName,
    String? currentPartyGstin,
  }) {
    return showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => EditPartyBottomSheet(
        currentPartyName: currentPartyName,
        currentPartyGstin: currentPartyGstin,
      ),
    );
  }

  @override
  State<EditPartyBottomSheet> createState() => _EditPartyBottomSheetState();
}

class _EditPartyBottomSheetState extends State<EditPartyBottomSheet> {
  late final AccountRepository _accountRepository;
  final TextEditingController _searchController = TextEditingController();
  List<AccountModel> _allAccounts = [];
  List<AccountModel> _filteredAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _accountRepository = widget.accountRepository ?? AccountRepository();
    _searchController.text = widget.currentPartyName;
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accs = await _accountRepository.fetchAccounts();
      if (mounted) {
        setState(() {
          _allAccounts = accs;
          _filterAccounts(widget.currentPartyName);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAccounts(String query) {
    if (query.trim().isEmpty) {
      _filteredAccounts = List.from(_allAccounts);
    } else {
      final q = query.toLowerCase();
      _filteredAccounts = _allAccounts.where((a) {
        return a.name.toLowerCase().contains(q) ||
            (a.gstin != null && a.gstin!.toLowerCase().contains(q));
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Party Ledger / व्यापारी चुनें', style: AppTypography.cardHeader),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          AppTextField(
            controller: _searchController,
            label: 'Search Party Name / GSTIN',
            hint: 'Type to filter ledgers...',
            prefixIcon: const Icon(Icons.search),
            onChanged: (val) {
              setState(() => _filterAccounts(val));
            },
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredAccounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No matching ledger found in Chart of Accounts.'),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                              icon: const Icon(Icons.add),
                              label: const Text('Create New Ledger / नया लेजर बनाएं'),
                              onPressed: () async {
                                final created = await QuickCreateLedgerBottomSheet.show(
                                  context,
                                  initialName: _searchController.text.trim(),
                                  initialGstin: widget.currentPartyGstin,
                                );
                                if (created != null && mounted) {
                                  Navigator.pop(context, created);
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredAccounts.length,
                        itemBuilder: (context, index) {
                          final acc = _filteredAccounts[index];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${acc.groupName} • ${acc.gstin ?? "Unregistered"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.check, color: AppColors.primary),
                            onTap: () => Navigator.pop(context, acc),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
