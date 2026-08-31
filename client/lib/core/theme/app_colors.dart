import 'package:flutter/material.dart';

/// Semantic color palette and Material 3 Expressive tokens for Ledgify.
/// Adheres strictly to docs/10_ui_ux_design_system_tokens.md.
class AppColors {
  // Primary Brands
  static const Color primary = Color(0xFF1A237E); // Deep Indigo
  static const Color primaryLight = Color(0xFFE8EAF6);
  static const Color primaryDark = Color(0xFF0D1240);

  // Secondary
  static const Color secondary = Color(0xFF00796B); // Teal
  static const Color secondaryLight = Color(0xFFE0F2F1);

  // Financial Semantics (Debit / Credit)
  static const Color debitGreen = Color(0xFF2E7D32); // Dark Green / Balanced
  static const Color debitGreenLight = Color(0xFFE8F5E9);
  static const Color creditRed = Color(0xFFC62828); // Crimson Red / Imbalance
  static const Color creditRedLight = Color(0xFFFFEBEE);

  // Warnings & Info
  static const Color warningAmber = Color(0xFFF57F17);
  static const Color warningAmberLight = Color(0xFFFFFDE7);
  static const Color infoBlue = Color(0xFF0288D1);
  static const Color infoBlueLight = Color(0xFFE1F5FE);

  // Neutrals & Surfaces
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFECEFF1);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color divider = Color(0xFFEEEEEE);

  // Dark Mode Tokens
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);

  // Layout Constants
  static const double minTouchTargetSize = 48.0;
  static const double cardBorderRadius = 12.0;
  static const double standardPadding = 16.0;
}
