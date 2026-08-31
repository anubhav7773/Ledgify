import 'package:flutter/material.dart';

/// Vernacular typography scale and baseline metric alignment for Noto Sans Devanagari.
/// Prevents glyph clipping across English (Latin) and Hindi (Devanagari) scripts.
/// Adheres strictly to docs/10_ui_ux_design_system_tokens.md.
class LedgifyTypography {
  static const String fontDeva = 'NotoSansDevanagari';

  static const TextStyle displayTitle = TextStyle(
    fontFamily: fontDeva,
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    height: 1.30, // Adjusted baseline for Devanagari ascenders/descenders
  );

  static const TextStyle cardHeader = TextStyle(
    fontFamily: fontDeva,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle bilingualLabel = TextStyle(
    fontFamily: fontDeva,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: Color(0xFF535F70),
    height: 1.20,
  );

  static const TextStyle financialAmount = TextStyle(
    fontFamily: fontDeva,
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle suggestionChip = TextStyle(
    fontFamily: fontDeva,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
  );
}
