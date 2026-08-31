import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/global_search_service.dart';
import '../../domain/models/search_result_item.dart';

/// Global Spotlight Search Delegate for rapid fuzzy querying across Ledgers, Vouchers, Items, and Reports.
class GlobalSearchDelegate extends SearchDelegate<SearchResultItem?> {
  final GlobalSearchService _searchService = GlobalSearchService();

  @override
  String get searchFieldLabel => 'Search Ledgers, Vouchers, Reports / खोजें...';

  @override
  TextStyle? get searchFieldStyle => AppTypography.bodyLarge;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildQuickSuggestions(context);
    }
    return _buildSearchResults(context);
  }

  Widget _buildQuickSuggestions(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Quick Access Reports / त्वरित रिपोर्ट', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        _buildQuickTile(context, 'Balance Sheet / तुलन पत्र', Icons.account_balance_outlined, () {
          query = 'Balance Sheet';
          showResults(context);
        }),
        _buildQuickTile(context, 'Profit & Loss / लाभ-हानि', Icons.trending_up, () {
          query = 'Profit & Loss';
          showResults(context);
        }),
        _buildQuickTile(context, 'Day Book / दैनिक बही', Icons.receipt_long_outlined, () {
          query = 'Day Book';
          showResults(context);
        }),
        _buildQuickTile(context, 'GST Compliance & IMS / जीएसटी', Icons.verified_outlined, () {
          query = 'GSTR-1';
          showResults(context);
        }),
      ],
    );
  }

  Widget _buildQuickTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: const Icon(Icons.north_west, size: 16, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<List<SearchResultItem>>(
      future: _searchService.search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return const Center(
            child: Text(
              'No matching records found.\nकोई परिणाम नहीं मिला',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = results[index];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 20, color: item.categoryColor),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.categoryLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              onTap: () => close(context, item),
            );
          },
        );
      },
    );
  }
}
