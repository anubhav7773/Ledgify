import 'package:flutter/material.dart';

/// Design tokens and semantic color codes for Ledgify (Google Stitch Fintech System).
class LedgifyColors {
  // Brand Primary & Accents (Stitch Deep Indigo)
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Indigo Blue
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary
  static const Color secondarySlate = Color(0xFF475569);
  static const Color secondaryContainer = Color(0xFFF1F5F9);

  // Accounting Specific Semantic Codes
  static const Color debitGreen = Color(0xFF16A34A); // Emerald 600
  static const Color debitGreenBg = Color(0xFFDCFCE7); // Emerald 100
  static const Color creditRed = Color(0xFFDC2626); // Red 600
  static const Color creditRedBg = Color(0xFFFEE2E2); // Red 100
  static const Color warningOrange = Color(0xFFD97706); // Amber 600
  static const Color warningOrangeBg = Color(0xFFFEF3C7); // Amber 100

  // Neutral Backgrounds & Card Surfaces (M3 Expressive)
  static const Color surfaceLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color outlineBorder = Color(0xFFE2E8F0); // Slate 200

  // Touch Target Minimums & Dimensions
  static const double minTouchTargetSize = 48.0;
  static const double standardPadding = 16.0;
  static const double cardBorderRadius = 16.0;
}
