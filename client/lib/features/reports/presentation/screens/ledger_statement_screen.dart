import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import 'package:ledgify/features/reports/domain/models/ledger_statement_model.dart';
import 'package:ledgify/features/reports/domain/services/statutory_registers_service.dart';

/// Screen presenting the Ledger Account Statement with continuous running balance.
class LedgerStatementScreen extends StatefulWidget {
  final String? accountId;
  final StatutoryRegistersService? service;
  final AccountRepository? accountRepository;

  const LedgerStatementScreen({
    super.key,
    this.accountId,
    this.service,
    this.accountRepository,
  });

  @override
  State<LedgerStatementScreen> createState() => _LedgerStatementScreenState();
}

class _LedgerStatementScreenState extends State<LedgerStatementScreen> {
  late final StatutoryRegistersService _service;
  late final AccountRepository _accountRepository;

  List<AccountModel> _accounts = [];
  String? _selectedAccountId;
  bool _isLoading = true;
  LedgerStatementReportModel? _statement;

  DateTime _fromDate = DateTime(DateTime.now().year, 4, 1);
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StatutoryRegistersService();
    _accountRepository = widget.accountRepository ?? AccountRepository();
    _selectedAccountId = widget.accountId;
    _initData();
  }

  Future<void> _initData() async {
    try {
      final accs = await _accountRepository.fetchAccounts();
      if (mounted && accs.isNotEmpty) {
        setState(() {
          _accounts = accs;
          _selectedAccountId ??= accs.first.id;
        });
        _loadStatement();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatement() async {
    if (_selectedAccountId == null) return;

    setState(() => _isLoading = true);
    try {
      final report = await _service.fetchLedgerStatement(
        accountId: _selectedAccountId!,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      if (mounted) {
        setState(() {
          _statement = report;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareViaWhatsApp() {
    if (_statement == null) return;

    final summary = 'Ledger Statement for ${_statement!.accountName}\n'
        'Period: ${_fromDate.day}/${_fromDate.month}/${_fromDate.year} to ${_toDate.day}/${_toDate.month}/${_toDate.year}\n'
        'Opening: ₹${_statement!.openingBalance.toStringAsFixed(2)} ${_statement!.openingBalanceType}\n'
        'Total Debit: ₹${_statement!.totalDebit.toStringAsFixed(2)}\n'
        'Total Credit: ₹${_statement!.totalCredit.toStringAsFixed(2)}\n'
        'Closing Balance: ₹${_statement!.closingBalance.toStringAsFixed(2)} ${_statement!.closingBalanceType}';

    Share.share(summary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger Statement / खाता विवरण', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share via WhatsApp',
            onPressed: _shareViaWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatement,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Account Selector Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedAccountId,
                decoration: const InputDecoration(
                  labelText: 'Select Ledger Account / खाता चुनें *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_box_outlined),
                ),
                items: _accounts.map((a) {
                  return DropdownMenuItem(value: a.id, child: Text(a.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedAccountId = val);
                    _loadStatement();
                  }
                },
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue)))
            else if (_statement == null)
              const Expanded(child: Center(child: Text('Select an account to view statement.')))
            else ...[
              // Statement Overview Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LedgifyColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LedgifyColors.surfaceVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opening: ₹${_statement!.openingBalance.toStringAsFixed(2)} ${_statement!.openingBalanceType}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Total Dr: ₹${_statement!.totalDebit.toStringAsFixed(0)} | Cr: ₹${_statement!.totalCredit.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Closing Balance', style: TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
                        Text(
                          '₹${_statement!.closingBalance.toStringAsFixed(2)} ${_statement!.closingBalanceType}',
                          style: LedgifyTypography.financialAmount.copyWith(
                            fontSize: 15,
                            color: _statement!.closingBalanceType == 'Dr' ? LedgifyColors.debitGreen : LedgifyColors.creditRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Table Headers
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: LedgifyColors.surfaceVariant.withOpacity(0.4),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Date & Particulars', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Running Bal', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                  ],
                ),
              ),

              // Statement Rows
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _statement!.entries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _statement!.entries[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.voucherDate.day}/${item.voucherDate.month} • ${item.particulars}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text('${item.voucherType} #${item.voucherNumber}', style: const TextStyle(fontSize: 10, color: LedgifyColors.secondarySlate, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.debitAmount > 0 ? item.debitAmount.toStringAsFixed(2) : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: LedgifyColors.debitGreen),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.creditAmount > 0 ? item.creditAmount.toStringAsFixed(2) : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: LedgifyColors.creditRed),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${item.runningBalance.toStringAsFixed(0)} ${item.runningBalanceType}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
