import 'package:intl/intl.dart';

/// Statutory Indian currency and accounting date formatters for Ledgify.
class CurrencyFormatter {
  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _inrPlainFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );

  /// Formats amount in statutory Indian numbering format (e.g. ₹50,00,000.00 or ₹1,23,456.78)
  static String formatInr(double amount, {bool showSymbol = true}) {
    if (showSymbol) {
      return _inrFormatter.format(amount).trim();
    }
    return _inrPlainFormatter.format(amount).trim();
  }

  /// Compact representation for high-density cards (e.g. ₹1.5 L, ₹2.4 Cr)
  static String formatInrCompact(double amount) {
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (absAmount >= 10000000) {
      return '$sign₹${(absAmount / 10000000).toStringAsFixed(2)} Cr';
    } else if (absAmount >= 100000) {
      return '$sign₹${(absAmount / 100000).toStringAsFixed(2)} L';
    } else if (absAmount >= 1000) {
      return '$sign₹${(absAmount / 1000).toStringAsFixed(1)} k';
    }
    return formatInr(amount);
  }

  /// Formats amount with Dr / Cr suffix (e.g. ₹1,23,456.00 Dr)
  static String formatDrCr(double amount, String entryType) {
    return '${formatInr(amount)} ${entryType.trim()}';
  }
}

class DateFormatter {
  static final DateFormat _voucherDateFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _displayMonthFormat = DateFormat('MMMM yyyy');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  /// Formats date for vouchers and registers (DD-MM-YYYY)
  static String formatVoucherDate(DateTime date) {
    return _voucherDateFormat.format(date);
  }

  /// Formats date for API payloads (YYYY-MM-DD)
  static String formatIsoDate(DateTime date) {
    return _isoDateFormat.format(date);
  }

  /// Formats month and year header (e.g. August 2026)
  static String formatMonthYear(DateTime date) {
    return _displayMonthFormat.format(date);
  }

  /// Determines Indian Financial Year string (e.g. '2026-2027')
  static String formatFinancialYear(DateTime date) {
    if (date.month >= 4) {
      return '${date.year}-${date.year + 1}';
    } else {
      return '${date.year - 1}-${date.year}';
    }
  }
}
