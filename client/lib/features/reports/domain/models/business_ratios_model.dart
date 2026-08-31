import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';

/// Domain model representing Core Financial & Liquidity Business Ratios.
class BusinessRatiosModel {
  final DateTime asOfDate;
  final double currentRatio;
  final double quickRatio;
  final double workingCapital;
  final double grossProfitMargin;
  final double netProfitMargin;
  final double debtorDaysDso;
  final double creditorDaysDpo;
  final double inventoryTurnover;
  final double debtToEquity;
  final double currentAssets;
  final double currentLiabilities;
  final double sundryDebtors;
  final double sundryCreditors;

  const BusinessRatiosModel({
    required this.asOfDate,
    required this.currentRatio,
    required this.quickRatio,
    required this.workingCapital,
    required this.grossProfitMargin,
    required this.netProfitMargin,
    required this.debtorDaysDso,
    required this.creditorDaysDpo,
    required this.inventoryTurnover,
    required this.debtToEquity,
    required this.currentAssets,
    required this.currentLiabilities,
    required this.sundryDebtors,
    required this.sundryCreditors,
  });

  factory BusinessRatiosModel.fromJson(Map<String, dynamic> json) {
    return BusinessRatiosModel(
      asOfDate: DateTime.parse(json['as_of_date'] as String? ?? DateTime.now().toIso8601String()),
      currentRatio: (json['current_ratio'] as num?)?.toDouble() ?? 1.0,
      quickRatio: (json['quick_ratio'] as num?)?.toDouble() ?? 1.0,
      workingCapital: (json['working_capital'] as num?)?.toDouble() ?? 0.0,
      grossProfitMargin: (json['gross_profit_margin'] as num?)?.toDouble() ?? 0.0,
      netProfitMargin: (json['net_profit_margin'] as num?)?.toDouble() ?? 0.0,
      debtorDaysDso: (json['debtor_days_dso'] as num?)?.toDouble() ?? 0.0,
      creditorDaysDpo: (json['creditor_days_dpo'] as num?)?.toDouble() ?? 0.0,
      inventoryTurnover: (json['inventory_turnover'] as num?)?.toDouble() ?? 0.0,
      debtToEquity: (json['debt_to_equity'] as num?)?.toDouble() ?? 0.0,
      currentAssets: (json['current_assets'] as num?)?.toDouble() ?? 0.0,
      currentLiabilities: (json['current_liabilities'] as num?)?.toDouble() ?? 0.0,
      sundryDebtors: (json['sundry_debtors'] as num?)?.toDouble() ?? 0.0,
      sundryCreditors: (json['sundry_creditors'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Color get currentRatioColor {
    if (currentRatio >= 1.5) return LedgifyColors.debitGreen;
    if (currentRatio >= 1.0) return LedgifyColors.warningOrange;
    return LedgifyColors.creditRed;
  }

  String get currentRatioStatus {
    if (currentRatio >= 1.5) return 'Healthy / सुरक्षित';
    if (currentRatio >= 1.0) return 'Moderate / सामान्य';
    return 'Critical / जोखिम';
  }
}
