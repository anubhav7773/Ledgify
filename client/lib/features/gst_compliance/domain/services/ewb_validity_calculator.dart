import 'dart:math';

/// Computational helper for statutory E-Way Bill validity periods under Rule 138(10).
class EwbValidityCalculator {
  /// Calculates valid days from distance (1 day per 200 km for standard cargo; 1 day per 20 km for ODC)
  static int calculateValidityDays(double distanceKm, {bool isOdc = false}) {
    if (distanceKm <= 0) return 1;
    if (isOdc) {
      return max(1, (distanceKm / 20.0).ceil());
    } else {
      return max(1, (distanceKm / 200.0).ceil());
    }
  }

  /// Computes the exact expiry timestamp for an E-Way Bill
  static DateTime computeExpiryDate(DateTime generatedAt, int validityDays) {
    return generatedAt.add(Duration(days: validityDays));
  }

  /// Formats remaining time into a human-readable bilingual countdown string
  static String formatRemainingTime(DateTime validUpto) {
    final now = DateTime.now();
    final difference = validUpto.difference(now);

    if (difference.isNegative) {
      return 'Expired / समाप्त';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    if (hours >= 24) {
      final days = difference.inDays;
      final remHours = hours % 24;
      return '$days d $remHours h remaining / $days दिन $remHours घंटे शेष';
    }

    return '$hours h $minutes m remaining / $hours घंटे $minutes मिनट शेष';
  }
}
