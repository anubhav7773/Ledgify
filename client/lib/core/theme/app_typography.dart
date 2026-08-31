import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Clean modern English typography tokens using Google Fonts Inter.
class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardHeader => titleLarge;

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
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

  /// English subtitle style
  static TextStyle get subtitleStyle => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// Builds a clean English label
  static Widget label({
    required String text,
    String? subtitle,
    TextStyle? textStyle,
    TextStyle? subtitleStyle,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    if (subtitle == null || subtitle.isEmpty) {
      return Text(text, style: textStyle ?? bodyLarge);
    }
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: textStyle ?? bodyLarge,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: subtitleStyle ?? AppTypography.subtitleStyle,
        ),
      ],
    );
  }

  /// Backward compatibility alias for bilingualLabel
  static Widget bilingualLabel({
    required String english,
    String? hindi,
    TextStyle? englishStyle,
    TextStyle? hindiStyle,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return label(
      text: english,
      subtitle: (hindi != null && hindi != english && !hindi.contains('बही') && !hindi.contains('खाता') && !hindi.contains('वाउचर')) ? hindi : null,
      textStyle: englishStyle,
      subtitleStyle: hindiStyle,
      crossAxisAlignment: crossAxisAlignment,
    );
  }
}
