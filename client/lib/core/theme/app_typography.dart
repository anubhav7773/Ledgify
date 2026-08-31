import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Bilingual typography tokens using Google Fonts Noto Sans & Noto Sans Devanagari.
/// Adheres strictly to docs/10_ui_ux_design_system_tokens.md.
class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.notoSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineMedium => GoogleFonts.notoSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleLarge => GoogleFonts.notoSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.notoSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.notoSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelSmall => GoogleFonts.notoSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  /// Tabular / Monospace style for financial amounts to avoid UI jitter
  static TextStyle get currencyText => GoogleFonts.robotoMono(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// Hindi Subtitle Typography
  static TextStyle get devanagariSubtitle => GoogleFonts.notoSansDevanagari(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// Builds a bilingual rich label with English title and Devanagari Hindi translation
  static Widget bilingualLabel({
    required String english,
    required String hindi,
    TextStyle? englishStyle,
    TextStyle? hindiStyle,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          english,
          style: englishStyle ?? bodyLarge,
        ),
        const SizedBox(height: 1.5),
        Text(
          hindi,
          style: hindiStyle ?? devanagariSubtitle,
        ),
      ],
    );
  }
}
