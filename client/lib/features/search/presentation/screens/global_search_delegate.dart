import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/global_search_service.dart';
import '../../domain/models/search_result_item.dart';

/// Global Spotlight Universal Search Delegate (Google Stitch UI).
class GlobalSearchDelegate extends SearchDelegate<SearchResultItem?> {
  final GlobalSearchService _searchService = GlobalSearchService();

  @override
  String get searchFieldLabel => 'Search Ledgers, Vouchers, Reports...';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
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
      icon: const Icon(Icons.arrow_back_rounded),
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
      padding: const EdgeInsets.all(AppColors.standardPadding),
      children: [
        const Text('Quick Jump & Top Reports', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        _buildQuickTile(context, 'Balance Sheet Report', Icons.account_balance_rounded, () {
          query = 'Balance Sheet';
          showResults(context);
        }),
        _buildQuickTile(context, 'Profit & Loss Account', Icons.trending_up_rounded, () {
          query = 'Profit & Loss';
          showResults(context);
        }),
        _buildQuickTile(context, 'Transaction Day Book', Icons.receipt_long_rounded, () {
          query = 'Day Book';
          showResults(context);
        }),
        _buildQuickTile(context, 'GST Compliance & IMS Portal', Icons.verified_rounded, () {
          query = 'GSTR-1';
          showResults(context);
        }),
        _buildQuickTile(context, 'Bank Accounts & BRS', Icons.account_balance_wallet_rounded, () {
          query = 'Bank';
          showResults(context);
        }),
      ],
    );
  }

  Widget _buildQuickTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.north_west_rounded, size: 16, color: AppColors.textSecondary),
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
              'No matching records found.',
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: item.categoryColor),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item.categoryLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
              onTap: () => close(context, item),
            );
          },
        );
      },
    );
  }
}
