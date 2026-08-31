import 'dart:convert';
import '../models/bank_statement_entry_model.dart';

/// Service parsing bank e-statement files (CSV text) into normalized BankStatementEntryModel instances.
class BankStatementParserService {
  /// Parses standard CSV statement content from Indian banks
  static List<BankStatementEntryModel> parseCsv({
    required String csvContent,
    required String businessId,
    required String bankAccountId,
  }) {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.isEmpty) return [];

    final List<BankStatementEntryModel> entries = [];
    int headerIndex = -1;
    int dateCol = -1;
    int descCol = -1;
    int refCol = -1;
    int withdrawalCol = -1;
    int depositCol = -1;
    int balanceCol = -1;

    // Scan for header row
    for (int i = 0; i < lines.length; i++) {
      final row = _splitCsvLine(lines[i].toLowerCase());
      for (int c = 0; c < row.length; c++) {
        final col = row[c].trim();
        if (col.contains('date') || col.contains('txn date') || col.contains('tran date')) {
          dateCol = c;
        } else if (col.contains('narration') || col.contains('description') || col.contains('particulars') || col.contains('remarks')) {
          descCol = c;
        } else if (col.contains('ref') || col.contains('chq') || col.contains('cheque') || col.contains('utr')) {
          refCol = c;
        } else if (col.contains('debit') || col.contains('withdrawal') || col.contains('dr')) {
          withdrawalCol = c;
        } else if (col.contains('credit') || col.contains('deposit') || col.contains('cr')) {
          depositCol = c;
        } else if (col.contains('balance') || col.contains('closing')) {
          balanceCol = c;
        }
      }

      if (dateCol != -1 && descCol != -1 && (withdrawalCol != -1 || depositCol != -1)) {
        headerIndex = i;
        break;
      }
    }

    if (headerIndex == -1) {
      // Default fallbacks if header not explicitly recognized
      dateCol = 0;
      descCol = 1;
      refCol = 2;
      withdrawalCol = 3;
      depositCol = 4;
      balanceCol = 5;
      headerIndex = 0;
    }

    // Process rows after header
    for (int i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsvLine(line);
      if (cols.length <= descCol || cols.length <= dateCol) continue;

      final rawDate = cols[dateCol].trim();
      final parsedDate = _parseIndianDate(rawDate);
      if (parsedDate == null) continue;

      final description = cols[descCol].trim();
      if (description.isEmpty) continue;

      final refNo = (refCol != -1 && refCol < cols.length) ? cols[refCol].trim() : null;

      double withdrawal = 0.0;
      if (withdrawalCol != -1 && withdrawalCol < cols.length) {
        withdrawal = _cleanAmount(cols[withdrawalCol]);
      }

      double deposit = 0.0;
      if (depositCol != -1 && depositCol < cols.length) {
        deposit = _cleanAmount(cols[depositCol]);
      }

      double balance = 0.0;
      if (balanceCol != -1 && balanceCol < cols.length) {
        balance = _cleanAmount(cols[balanceCol]);
      }

      if (withdrawal == 0.0 && deposit == 0.0) continue;

      entries.add(
        BankStatementEntryModel(
          id: '',
          businessId: businessId,
          bankAccountId: bankAccountId,
          transactionDate: parsedDate,
          description: description,
          chequeReferenceNo: refNo?.isNotEmpty == true ? refNo : null,
          withdrawalAmount: withdrawal,
          depositAmount: deposit,
          balance: balance,
        ),
      );
    }

    return entries;
  }

  static List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  static DateTime? _parseIndianDate(String raw) {
    final clean = raw.replaceAll('/', '-').replaceAll('.', '-').trim();
    final parts = clean.split('-');

    if (parts.length == 3) {
      if (parts[0].length == 4) {
        // YYYY-MM-DD
        return DateTime.tryParse(clean);
      } else {
        // DD-MM-YYYY
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          final fullYear = year < 100 ? (year + 2000) : year;
          return DateTime(fullYear, month, day);
        }
      }
    }
    return DateTime.tryParse(clean);
  }

  static double _cleanAmount(String raw) {
    final clean = raw.replaceAll(',', '').replaceAll('₹', '').replaceAll(' ', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
