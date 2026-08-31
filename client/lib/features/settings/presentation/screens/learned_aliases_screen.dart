import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../masters/domain/services/active_learning_service.dart';

/// Settings screen for managing learned voice/OCR entity mappings and phonetic aliases.
class LearnedAliasesScreen extends StatefulWidget {
  final ActiveLearningService? service;

  const LearnedAliasesScreen({super.key, this.service});

  @override
  State<LearnedAliasesScreen> createState() => _LearnedAliasesScreenState();
}

class _LearnedAliasesScreenState extends State<LearnedAliasesScreen> {
  late final ActiveLearningService _service;
  bool _isLoading = true;
  List<DisambiguationCacheItem> _aliases = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ActiveLearningService();
    _loadAliases();
  }

  Future<void> _loadAliases() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.fetchLearnedAliases();
      if (mounted) {
        setState(() {
          _aliases = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAlias(String id) async {
    await _service.deleteLearnedAlias(id);
    _loadAliases();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _aliases.where(
      (a) => a.rawQueryText.toLowerCase().contains(_searchQuery.toLowerCase()),
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learned Aliases / सीखे गए उपनाम', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAliases,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search learned aliases / खोजें',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
                  : filtered.isEmpty
                      ? const Center(
                          child: Text('No learned entity mappings found.', style: LedgifyTypography.bilingualLabel),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isAccount = item.entityType == 'ACCOUNT';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: LedgifyColors.surfaceVariant),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isAccount ? LedgifyColors.primaryBlue : LedgifyColors.debitGreen).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isAccount ? Icons.account_balance_outlined : Icons.inventory_2_outlined,
                                    color: isAccount ? LedgifyColors.primaryBlue : LedgifyColors.debitGreen,
                                  ),
                                ),
                                title: Text(item.rawQueryText, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${item.entityType} • Hits: ${item.hitCount} • Last: ${item.lastUsedAt.day}/${item.lastUsedAt.month}/${item.lastUsedAt.year}',
                                  style: const TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: LedgifyColors.creditRed),
                                  tooltip: 'Delete Mapping',
                                  onPressed: () => _deleteAlias(item.id),
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
