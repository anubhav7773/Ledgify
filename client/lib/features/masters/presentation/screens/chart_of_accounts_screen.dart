import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/models/account_model.dart';
import 'create_ledger_screen.dart';

/// Screen rendering the hierarchical Chart of Accounts (COA) tree (Google Stitch UI).
class ChartOfAccountsScreen extends StatefulWidget {
  final AccountRepository? repository;

  const ChartOfAccountsScreen({super.key, this.repository});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen>
    with SingleTickerProviderStateMixin {
  late final AccountRepository _repository;
  late final TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = true;
  String? _errorMessage;
  List<AccountModel> _allAccounts = [];

  final List<String> _classifications = [
    'Asset',
    'Liability',
    'Equity',
    'Income',
    'Expense',
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AccountRepository();
    _tabController = TabController(length: _classifications.length, vsync: this);
    _loadAccounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _repository.fetchAccounts();
      if (mounted) {
        setState(() {
          _allAccounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<AccountModel> _filteredAccountsFor(String classification) {
    return _allAccounts.where((account) {
      final matchesClassification = account.primaryClassification == classification;
      if (!matchesClassification) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final nameMatches = account.name.toLowerCase().contains(query);
      final aliasMatches = account.alias?.toLowerCase().contains(query) ?? false;
      final groupMatches = account.groupName.toLowerCase().contains(query);

      return nameMatches || aliasMatches || groupMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Chart of Accounts', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search ledger, group or alias...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),

              // Classification Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: _classifications.map((c) => Tab(text: c)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage', style: const TextStyle(color: AppColors.creditRed)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadAccounts, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _classifications.map((classification) {
                    final accounts = _filteredAccountsFor(classification);
                    if (accounts.isEmpty) {
                      return Center(
                        child: Text(
                          'No accounts found in $classification',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    // Group by group_name
                    final Map<String, List<AccountModel>> grouped = {};
                    for (final acc in accounts) {
                      grouped.putIfAbsent(acc.groupName, () => []).add(acc);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: grouped.keys.length,
                      itemBuilder: (context, index) {
                        final groupName = grouped.keys.elementAt(index);
                        final groupAccounts = grouped[groupName]!;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Text(groupName, style: AppTypography.cardHeader.copyWith(fontSize: 15)),
                            subtitle: Text('${groupAccounts.length} Ledgers', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            children: groupAccounts.map((acc) {
                              return Container(
                                decoration: const BoxDecoration(
                                  border: Border(top: BorderSide(color: AppColors.divider)),
                                ),
                                child: ListTile(
                                  dense: true,
                                  title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: acc.alias != null && acc.alias!.isNotEmpty
                                      ? Text('Alias: ${acc.alias}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                                      : null,
                                  trailing: Text(
                                    acc.formattedBalance,
                                    style: AppTypography.currencyText.copyWith(
                                      color: acc.openingBalanceType == 'Dr'
                                          ? AppColors.debitGreen
                                          : AppColors.creditRed,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Ledger', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const CreateLedgerScreen()),
          );
          if (result == true) {
            _loadAccounts();
          }
        },
      ),
    );
  }
}
