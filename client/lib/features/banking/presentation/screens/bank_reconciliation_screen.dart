import 'package:flutter/material.dart';
import 'package:ledgify/core/theme/color_tokens.dart';
import 'package:ledgify/core/theme/typography_tokens.dart';
import 'package:ledgify/features/masters/data/repositories/account_repository.dart';
import 'package:ledgify/features/masters/domain/models/account_model.dart';
import 'package:ledgify/features/banking/data/repositories/banking_repository.dart';
import 'package:ledgify/features/banking/domain/models/bank_account_model.dart';
import 'package:ledgify/features/banking/domain/models/bank_statement_entry_model.dart';

/// Screen for interactive and automated Bank Reconciliation Statement (BRS) workflows.
/// Adheres strictly to docs/08_banking_brs_payroll_direct_tax.md and docs/10_ui_ux_design_system_tokens.md.
class BankReconciliationScreen extends StatefulWidget {
  final BankAccountModel bankAccount;
  final BankingRepository? repository;
  final AccountRepository? accountRepository;

  const BankReconciliationScreen({
    super.key,
    required this.bankAccount,
    this.repository,
    this.accountRepository,
  });

  @override
  State<BankReconciliationScreen> createState() => _BankReconciliationScreenState();
}

class _BankReconciliationScreenState extends State<BankReconciliationScreen> {
  late final BankingRepository _repository;
  late final AccountRepository _accountRepository;

  bool _isLoading = true;
  bool _isAutoReconciling = false;
  List<BankStatementEntryModel> _statementLines = [];
  List<AccountModel> _expenseIncomeAccounts = [];

  String _filter = 'UNRECONCILED'; // 'UNRECONCILED' or 'ALL'

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BankingRepository();
    _accountRepository = widget.accountRepository ?? AccountRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lines = await _repository.fetchStatementEntries(
        widget.bankAccount.id,
        isReconciled: _filter == 'UNRECONCILED' ? false : null,
      );
      final accounts = await _accountRepository.fetchAccounts();

      if (mounted) {
        setState(() {
          _statementLines = lines;
          _expenseIncomeAccounts = accounts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runAutoReconcile() async {
    setState(() => _isAutoReconciling = true);

    try {
      final results = await _repository.runAutoReconciliation(widget.bankAccount.id);
      final autoCount = results.where((r) => r['reconciliation_action'] == 'AUTO_RECONCILED').length;
      final suggestCount = results.where((r) => r['reconciliation_action'] == 'SUGGESTION').length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('BRS Match Complete: $autoCount Auto-Reconciled, $suggestCount Suggested!'),
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-reconciliation error: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoReconciling = false);
      }
    }
  }

  Future<void> _post1ClickVoucher(BankStatementEntryModel entry, String accountName, String voucherType) async {
    try {
      final targetAcc = _expenseIncomeAccounts.firstWhere(
        (a) => a.name.toLowerCase().contains(accountName.toLowerCase()),
        orElse: () => _expenseIncomeAccounts.first,
      );

      await _repository.createVoucherFromStatementLine(
        statementId: entry.id,
        contraAccountId: targetAcc.id,
        voucherType: voucherType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Posted $voucherType for ${entry.description} to ${targetAcc.name}!'),
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post voucher: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BRS: ${widget.bankAccount.bankName}', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Filter toggle
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'UNRECONCILED', label: Text('Un-reconciled')),
                      ButtonSegment(value: 'ALL', label: Text('All Lines')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (val) {
                      setState(() => _filter = val.first);
                      _loadData();
                    },
                  ),
                  const Spacer(),

                  // Auto Reconcile Button (48dp Touch Target)
                  SizedBox(
                    height: LedgifyColors.minTouchTargetSize,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LedgifyColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isAutoReconciling
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Auto-BRS', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: _isAutoReconciling ? null : _runAutoReconcile,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
                  : _statementLines.isEmpty
                      ? const Center(
                          child: Text('No statement transactions found in this view.', style: LedgifyTypography.bilingualLabel),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _statementLines.length,
                          itemBuilder: (context, index) {
                            final item = _statementLines[index];
                            final isWithdrawal = item.isWithdrawal;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: item.isReconciled
                                      ? LedgifyColors.debitGreen.withOpacity(0.5)
                                      : (item.trgmSimilarityScore != null && item.trgmSimilarityScore! >= 0.60
                                          ? LedgifyColors.warningOrange.withOpacity(0.5)
                                          : LedgifyColors.surfaceVariant),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${item.transactionDate.day}/${item.transactionDate.month}/${item.transactionDate.year}',
                                          style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate),
                                        ),
                                        Text(
                                          item.reconciliationStatusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: item.isReconciled
                                                ? LedgifyColors.debitGreen
                                                : (item.trgmSimilarityScore != null ? LedgifyColors.warningOrange : LedgifyColors.secondarySlate),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.description,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          '${isWithdrawal ? '-' : '+'}₹${item.amount.toStringAsFixed(2)}',
                                          style: LedgifyTypography.financialAmount.copyWith(
                                            color: isWithdrawal ? LedgifyColors.creditRed : LedgifyColors.debitGreen,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (item.chequeReferenceNo != null) ...[
                                      const SizedBox(height: 4),
                                      Text('Ref/Cheque: ${item.chequeReferenceNo}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                    ],

                                    // Quick Action Chips if un-reconciled
                                    if (!item.isReconciled) ...[
                                      const Divider(height: 18),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (isWithdrawal)
                                            ActionChip(
                                              avatar: const Icon(Icons.receipt_long, size: 14),
                                              label: const Text('Bank Charges / शुल्क'),
                                              onPressed: () => _post1ClickVoucher(item, 'Bank Charges', 'Payment'),
                                            )
                                          else
                                            ActionChip(
                                              avatar: const Icon(Icons.savings_outlined, size: 14),
                                              label: const Text('Interest / ब्याज'),
                                              onPressed: () => _post1ClickVoucher(item, 'Interest Received', 'Receipt'),
                                            ),
                                          ActionChip(
                                            avatar: const Icon(Icons.link, size: 14),
                                            label: const Text('Link Ledger / लेजर जोड़ें'),
                                            onPressed: () => _post1ClickVoucher(item, isWithdrawal ? 'Sundry Creditors' : 'Sundry Debtors', isWithdrawal ? 'Payment' : 'Receipt'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
