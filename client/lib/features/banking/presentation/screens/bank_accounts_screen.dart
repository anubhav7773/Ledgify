import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/banking/data/repositories/banking_repository.dart';
import 'package:ledgify/features/banking/domain/models/bank_account_model.dart';
import 'package:ledgify/features/banking/domain/services/bank_statement_parser_service.dart';
import 'bank_reconciliation_screen.dart';

/// Screen listing company bank accounts and providing 1-tap statement import and reconciliation entry (Google Stitch UI).
class BankAccountsScreen extends StatefulWidget {
  final BankingRepository? repository;

  const BankAccountsScreen({super.key, this.repository});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  late final BankingRepository _repository;
  bool _isLoading = true;
  List<BankAccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BankingRepository();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _repository.fetchBankAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importStatement(BankAccountModel account) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      return;
    }

    try {
      final csvString = utf8.decode(result.files.first.bytes!);
      final entries = BankStatementParserService.parseCsv(
        csvContent: csvString,
        businessId: account.businessId,
        bankAccountId: account.id,
      );

      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid statement transactions detected in file.')),
          );
        }
        return;
      }

      await _repository.importStatementEntries(account.id, entries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${entries.length} statement rows successfully!'),
            backgroundColor: AppColors.debitGreen,
          ),
        );
        _loadAccounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import statement: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Bank Accounts Management', style: AppTypography.cardHeader),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Accounts',
            onPressed: _loadAccounts,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_rounded, size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No bank accounts configured yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppColors.standardPadding),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final bank = _accounts[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(bank.bankName, style: AppTypography.cardHeader.copyWith(fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text(bank.ledgerName ?? 'Bank Ledger Account', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: bank.isConnected ? AppColors.debitGreenLight : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      bank.isConnected ? 'Live Sync' : 'Manual BRS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: bank.isConnected ? AppColors.debitGreen : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Text('A/C: ${bank.maskedAccountNumber} • IFSC: ${bank.ifscCode}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppColors.textPrimary)),
                              const Divider(height: 20),

                              // Actions Row (48dp Touch Targets)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: AppColors.minTouchTargetSize,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.primaryLight),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                                        label: const Text('Import CSV', style: TextStyle(fontWeight: FontWeight.w700)),
                                        onPressed: () => _importStatement(bank),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: SizedBox(
                                      height: AppColors.minTouchTargetSize,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.rule_folder_rounded, size: 18),
                                        label: const Text('Reconcile (BRS)', style: TextStyle(fontWeight: FontWeight.w700)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => BankReconciliationScreen(bankAccount: bank),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
