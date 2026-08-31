import 'package:flutter/material.dart';

/// Design tokens and semantic color codes for the Ledgify Material 3 Expressive UI.
/// Adheres strictly to docs/10_ui_ux_design_system_tokens.md.
class LedgifyColors {
  // Brand Primary & Accents (Trust & Security)
  static const Color primaryBlue = Color(0xFF0F4C81); // Deep Indigo Blue
  static const Color primaryContainer = Color(0xFFD6E4FF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary (Financial Operations)
  static const Color secondarySlate = Color(0xFF535F70);
  static const Color secondaryContainer = Color(0xFFD7E3F8);

  // Accounting Specific Semantic Codes
  static const Color debitGreen = Color(0xFF1B873F); // Inward / Debit / Asset increase
  static const Color debitGreenBg = Color(0xFFE8F5E9);
  static const Color creditRed = Color(0xFFBA1A1A); // Outward / Credit / Liability increase
  static const Color creditRedBg = Color(0xFFFFDAD6);
  static const Color warningOrange = Color(0xFFE65100); // Blocked ITC / Review Required
  static const Color warningOrangeBg = Color(0xFFFFF3E0);

  // Neutral Backgrounds & Card Surfaces (M3 Expressive)
  static const Color surfaceLight = Color(0xFFFDFBFF);
  static const Color surfaceVariant = Color(0xFFE1E2EC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color outlineBorder = Color(0xFF74777F);

  // Touch Target Minimums & Dimensions
  static const double minTouchTargetSize = 48.0;
  static const double standardPadding = 16.0;
  static const double cardBorderRadius = 16.0;
}
