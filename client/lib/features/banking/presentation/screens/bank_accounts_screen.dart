import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../data/repositories/banking_repository.dart';
import '../domain/models/bank_account_model.dart';
import '../domain/services/bank_statement_parser_service.dart';
import 'bank_reconciliation_screen.dart';

/// Screen listing company bank accounts and providing 1-tap statement import and reconciliation entry.
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
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        _loadAccounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import statement: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts & BRS / बैंक खाते', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccounts,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
            : _accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance, size: 48, color: LedgifyColors.secondarySlate),
                        const SizedBox(height: 12),
                        const Text(
                          'No bank accounts configured.\nखाता जोड़ने के लिए लेजर बनाएं',
                          textAlign: TextAlign.center,
                          style: LedgifyTypography.bilingualLabel,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final bank = _accounts[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                          side: const BorderSide(color: LedgifyColors.surfaceVariant),
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
                                        Text(bank.bankName, style: LedgifyTypography.cardHeader.copyWith(fontSize: 17)),
                                        Text(bank.ledgerName ?? 'Bank Ledger', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: bank.isConnected ? LedgifyColors.debitGreenBg : LedgifyColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      bank.isConnected ? 'Live Sync' : 'Manual BRS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: bank.isConnected ? LedgifyColors.debitGreen : LedgifyColors.secondarySlate,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Text('A/C: ${bank.maskedAccountNumber} • IFSC: ${bank.ifscCode}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                              const Divider(height: 20),

                              // Actions Row (48dp Touch Targets)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: LedgifyColors.minTouchTargetSize,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: LedgifyColors.primaryBlue,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.upload_file, size: 18),
                                        label: const Text('Import CSV', style: TextStyle(fontWeight: FontWeight.w700)),
                                        onPressed: () => _importStatement(bank),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: SizedBox(
                                      height: LedgifyColors.minTouchTargetSize,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: LedgifyColors.primaryBlue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.rule, size: 18),
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
