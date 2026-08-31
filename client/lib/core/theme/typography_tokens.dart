import 'package:flutter/material.dart';

/// Clean English typography tokens for Ledgify UI.
class LedgifyTypography {
  static const TextStyle displayTitle = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle cardHeader = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bilingualLabel = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: Color(0xFF535F70),
  );

  static const TextStyle financialAmount = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle suggestionChip = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
  );
}
