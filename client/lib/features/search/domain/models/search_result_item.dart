import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum SearchCategory {
  ledger,
  voucher,
  stockItem,
  report,
  setting,
}

/// Domain model representing a universal search hit across ledgers, vouchers, items, and reports.
class SearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final String? route;
  final dynamic arguments;
  final double score;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.route,
    this.arguments,
    this.score = 1.0,
  });

  String get categoryLabel {
    switch (category) {
      case SearchCategory.ledger:
        return 'Ledger / लेजर';
      case SearchCategory.voucher:
        return 'Voucher / वाउचर';
      case SearchCategory.stockItem:
        return 'Stock Item / वस्तु';
      case SearchCategory.report:
        return 'Report / रिपोर्ट';
      case SearchCategory.setting:
        return 'Menu / मेन्यू';
    }
  }

  IconData get icon {
    switch (category) {
      case SearchCategory.ledger:
        return Icons.account_balance_wallet_outlined;
      case SearchCategory.voucher:
        return Icons.receipt_long_outlined;
      case SearchCategory.stockItem:
        return Icons.inventory_2_outlined;
      case SearchCategory.report:
        return Icons.analytics_outlined;
      case SearchCategory.setting:
        return Icons.settings_outlined;
    }
  }

  Color get categoryColor {
    switch (category) {
      case SearchCategory.ledger:
        return AppColors.primary;
      case SearchCategory.voucher:
        return AppColors.debitGreen;
      case SearchCategory.stockItem:
        return AppColors.secondary;
      case SearchCategory.report:
        return AppColors.infoBlue;
      case SearchCategory.setting:
        return AppColors.textSecondary;
    }
  }
}
