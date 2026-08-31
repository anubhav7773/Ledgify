import 'package:flutter/material.dart';

/// Semantic color palette and Material 3 Expressive tokens for Ledgify (Google Stitch Fintech System).
class AppColors {
  // Primary Brands (Stitch Deep Indigo)
  static const Color primary = Color(0xFF1E3A8A); // Deep Indigo Blue
  static const Color primaryLight = Color(0xFFDBEAFE); // Blue 100
  static const Color primaryContainer = Color(0xFFEFF6FF); // Blue 50
  static const Color primaryDark = Color(0xFF172554); // Blue 950

  // Secondary (Stitch Emerald Teal)
  static const Color secondary = Color(0xFF0D9488); // Teal 600
  static const Color secondaryLight = Color(0xFFCCFBF1); // Teal 100
  static const Color secondaryContainer = Color(0xFFF0FDFA); // Teal 50

  // Financial Semantics (Debit / Credit)
  static const Color debitGreen = Color(0xFF16A34A); // Emerald 600
  static const Color debitGreenLight = Color(0xFFDCFCE7); // Emerald 100
  static const Color creditRed = Color(0xFFDC2626); // Red 600
  static const Color creditRedLight = Color(0xFFFEE2E2); // Red 100

  // Warnings & Info
  static const Color warningAmber = Color(0xFFD97706); // Amber 600
  static const Color warningAmberLight = Color(0xFFFEF3C7); // Amber 100
  static const Color infoBlue = Color(0xFF2563EB); // Blue 600
  static const Color infoBlueLight = Color(0xFFE0E7FF); // Indigo 100

  // Neutrals & Surfaces (Stitch Slate System)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400
  static const Color divider = Color(0xFFE2E8F0);

  // Dark Mode Tokens
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Layout Constants
  static const double minTouchTargetSize = 48.0;
  static const double cardBorderRadius = 16.0;
  static const double standardPadding = 16.0;
}
