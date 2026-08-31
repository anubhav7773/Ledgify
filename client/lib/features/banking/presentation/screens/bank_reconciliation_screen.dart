import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/masters/data/repositories/account_repository.dart';
import 'package:ledgify/features/masters/domain/models/account_model.dart';
import 'package:ledgify/features/banking/data/repositories/banking_repository.dart';
import 'package:ledgify/features/banking/domain/models/bank_account_model.dart';
import 'package:ledgify/features/banking/domain/models/bank_statement_entry_model.dart';

/// Screen for interactive and automated Bank Reconciliation Statement (BRS) workflows (Google Stitch UI).
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
            backgroundColor: AppColors.debitGreen,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-reconciliation error: $e'), backgroundColor: AppColors.creditRed),
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
            backgroundColor: AppColors.debitGreen,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post voucher: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('BRS: ${widget.bankAccount.bankName}', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Statement',
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
                    height: AppColors.minTouchTargetSize,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isAutoReconciling
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _statementLines.isEmpty
                      ? const Center(
                          child: Text('No statement transactions found in this view.', style: TextStyle(color: AppColors.textSecondary)),
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
                                borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                                side: BorderSide(
                                  color: item.isReconciled
                                      ? AppColors.debitGreen.withOpacity(0.5)
                                      : (item.trgmSimilarityScore != null && item.trgmSimilarityScore! >= 0.60
                                          ? AppColors.warningAmber.withOpacity(0.5)
                                          : AppColors.border),
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
                                          '${item.transactionDate.day.toString().padLeft(2, '0')}/${item.transactionDate.month.toString().padLeft(2, '0')}/${item.transactionDate.year}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          item.reconciliationStatusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: item.isReconciled
                                                ? AppColors.debitGreen
                                                : (item.trgmSimilarityScore != null ? AppColors.warningAmber : AppColors.textSecondary),
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
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                          ),
                                        ),
                                        Text(
                                          '${isWithdrawal ? '-' : '+'}₹${item.amount.toStringAsFixed(2)}',
                                          style: AppTypography.currencyText.copyWith(
                                            color: isWithdrawal ? AppColors.creditRed : AppColors.debitGreen,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (item.chequeReferenceNo != null) ...[
                                      const SizedBox(height: 4),
                                      Text('Ref/Cheque: ${item.chequeReferenceNo}', style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AppColors.textSecondary)),
                                    ],

                                    // Quick Action Chips if un-reconciled
                                    if (!item.isReconciled) ...[
                                      const Divider(height: 18),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (isWithdrawal)
                                            ActionChip(
                                              avatar: const Icon(Icons.receipt_long_outlined, size: 14),
                                              label: const Text('Bank Charges'),
                                              onPressed: () => _post1ClickVoucher(item, 'Bank Charges', 'Payment'),
                                            )
                                          else
                                            ActionChip(
                                              avatar: const Icon(Icons.savings_outlined, size: 14),
                                              label: const Text('Interest Received'),
                                              onPressed: () => _post1ClickVoucher(item, 'Interest Received', 'Receipt'),
                                            ),
                                          ActionChip(
                                            avatar: const Icon(Icons.link_rounded, size: 14),
                                            label: const Text('Link Ledger'),
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
