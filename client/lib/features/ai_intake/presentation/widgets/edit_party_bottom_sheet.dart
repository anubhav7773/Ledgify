import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../masters/presentation/widgets/quick_create_ledger_bottom_sheet.dart';

/// Modal bottom sheet for changing or re-assigning the extracted vendor/customer party ledger (Google Stitch UI).
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
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 12,
          left: 20,
          right: 20,
        ),
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
                Text('Select Party Ledger', style: AppTypography.cardHeader),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Field
            AppTextField(
              controller: _searchController,
              label: 'Search Party Name or GSTIN',
              hint: 'Type to filter ledgers...',
              prefixIcon: const Icon(Icons.search_rounded),
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
                              const Text('No matching ledger found in Chart of Accounts.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create New Ledger'),
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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border.withOpacity(0.5)),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                subtitle: Text('${acc.groupName} • ${acc.gstin ?? "Unregistered"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                trailing: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 20),
                                onTap: () => Navigator.pop(context, acc),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
