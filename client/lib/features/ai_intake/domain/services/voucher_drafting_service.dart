import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../vouchers/domain/models/voucher_line_item_model.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../models/extracted_invoice_payload.dart';

/// Result of resolving an extracted entity against the local Chart of Accounts.
class PartyResolutionResult {
  final AccountModel? matchedAccount;
  final bool needsCreation;
  final String suggestedName;
  final String suggestedGroup; // 'Sundry Creditors' or 'Sundry Debtors'
  final String? suggestedGstin;
  final String? suggestedPan;
  final double confidenceScore;

  const PartyResolutionResult({
    this.matchedAccount,
    required this.needsCreation,
    required this.suggestedName,
    required this.suggestedGroup,
    this.suggestedGstin,
    this.suggestedPan,
    this.confidenceScore = 1.0,
  });
}

/// Service orchestrating automated ledger resolution, statutory tax split routing, and zero-sum round-off balancing.
class VoucherDraftingService {
  final AccountRepository _accountRepository;

  VoucherDraftingService({AccountRepository? accountRepository})
      : _accountRepository = accountRepository ?? AccountRepository();

  /// Resolves an extracted party name and GSTIN against existing accounts
  Future<PartyResolutionResult> resolvePartyLedger({
    required String partyName,
    String? partyGstin,
    required String voucherType, // 'Purchase', 'Sales', 'Payment', 'Receipt'
  }) async {
    final bool isPurchaseOrPay = voucherType == 'Purchase' || voucherType == 'Payment';
    final String defaultGroup = isPurchaseOrPay ? 'Sundry Creditors' : 'Sundry Debtors';

    // 1. Attempt exact match by 15-character GSTIN
    if (partyGstin != null && partyGstin.trim().length == 15) {
      final accounts = await _accountRepository.fetchAccounts();
      final exactGstinMatch = accounts.where(
        (a) => a.partyGstin != null && a.partyGstin!.toUpperCase() == partyGstin.trim().toUpperCase(),
      );

      if (exactGstinMatch.isNotEmpty) {
        return PartyResolutionResult(
          matchedAccount: exactGstinMatch.first,
          needsCreation: false,
          suggestedName: exactGstinMatch.first.name,
          suggestedGroup: exactGstinMatch.first.groupName,
          confidenceScore: 1.0,
        );
      }
    }

    // 2. Attempt name/alias matching
    final cleanName = partyName.trim().toLowerCase();
    final allAccounts = await _accountRepository.fetchAccounts();
    
    for (final acc in allAccounts) {
      final accName = acc.name.toLowerCase();
      final alias = acc.alias?.toLowerCase() ?? '';
      if (accName == cleanName || (alias.isNotEmpty && alias == cleanName)) {
        return PartyResolutionResult(
          matchedAccount: acc,
          needsCreation: false,
          suggestedName: acc.name,
          suggestedGroup: acc.groupName,
          confidenceScore: 0.95,
        );
      }
    }

    // 3. Fallback: Needs On-the-Fly Creation
    String? extractedPan;
    if (partyGstin != null && partyGstin.trim().length >= 12) {
      extractedPan = partyGstin.trim().substring(2, 12).toUpperCase();
    }

    return PartyResolutionResult(
      matchedAccount: null,
      needsCreation: true,
      suggestedName: partyName.trim(),
      suggestedGroup: defaultGroup,
      suggestedGstin: partyGstin?.trim(),
      suggestedPan: extractedPan,
      confidenceScore: 0.50,
    );
  }

  /// Builds fully balanced double-entry voucher line items including statutory tax and round-off lines
  Future<List<VoucherLineItemModel>> buildBalancedLines({
    required String businessId,
    required ExtractedInvoicePayload payload,
    required String primaryExpenseOrSalesAccountId,
    required String partyAccountId,
    required bool isPurchase,
    required int supplierStateCode,
    required int buyerStateCode,
  }) async {
    final List<VoucherLineItemModel> lines = [];
    final totals = payload.documentTotals;

    final double totalTaxable = (totals['total_taxable_value'] as num?)?.toDouble() ?? 0.00;
    final double cgstAmt = (totals['total_cgst_value'] as num?)?.toDouble() ?? 0.00;
    final double sgstAmt = (totals['total_sgst_value'] as num?)?.toDouble() ?? 0.00;
    final double igstAmt = (totals['total_igst_value'] as num?)?.toDouble() ?? 0.00;
    final double totalInvoiceVal = (totals['total_invoice_value'] as num?)?.toDouble() ?? 0.00;

    final bool isInterState = supplierStateCode != buyerStateCode;

    // Fetch accounts to locate standard Duties & Taxes ledgers and Round Off ledger
    final accounts = await _accountRepository.fetchAccounts();

    AccountModel? findAccount(String name, String fallbackGroup) {
      final matches = accounts.where((a) => a.name.toLowerCase() == name.toLowerCase());
      if (matches.isNotEmpty) return matches.first;
      return null;
    }

    if (isPurchase) {
      // 1. Debit Line: Purchase / Expense Account
      lines.add(
        VoucherLineItemModel(
          id: '',
          businessId: businessId,
          voucherId: '',
          accountId: primaryExpenseOrSalesAccountId,
          entryType: 'Dr',
          amount: totalTaxable,
          itemDescription: 'Assessable Value for Bill #${payload.documentNumber}',
        ),
      );

      // 2. Tax Debit Lines (Input Tax Credit)
      if (isInterState && igstAmt > 0) {
        final igstAcc = findAccount('Input IGST', 'Duties & Taxes') ?? accounts.first;
        lines.add(
          VoucherLineItemModel(
            id: '',
            businessId: businessId,
            voucherId: '',
            accountId: igstAcc.id,
            entryType: 'Dr',
            amount: igstAmt,
            igstAmt: igstAmt,
            itemDescription: 'Input IGST Credit',
          ),
        );
      } else {
        if (cgstAmt > 0) {
          final cgstAcc = findAccount('Input CGST', 'Duties & Taxes') ?? accounts.first;
          lines.add(
            VoucherLineItemModel(
              id: '',
              businessId: businessId,
              voucherId: '',
              accountId: cgstAcc.id,
              entryType: 'Dr',
              amount: cgstAmt,
              cgstAmt: cgstAmt,
              itemDescription: 'Input CGST Credit',
            ),
          );
        }
        if (sgstAmt > 0) {
          final sgstAcc = findAccount('Input SGST', 'Duties & Taxes') ?? accounts.first;
          lines.add(
            VoucherLineItemModel(
              id: '',
              businessId: businessId,
              voucherId: '',
              accountId: sgstAcc.id,
              entryType: 'Dr',
              amount: sgstAmt,
              sgstAmt: sgstAmt,
              itemDescription: 'Input SGST Credit',
            ),
          );
        }
      }

      // 3. Credit Line: Sundry Creditor / Supplier (Total Payable)
      lines.add(
        VoucherLineItemModel(
          id: '',
          businessId: businessId,
          voucherId: '',
          accountId: partyAccountId,
          entryType: 'Cr',
          amount: totalInvoiceVal,
          itemDescription: 'Payable against Invoice #${payload.documentNumber}',
        ),
      );
    } else {
      // Sales Voucher Lines
      // 1. Debit Line: Sundry Debtor / Customer
      lines.add(
        VoucherLineItemModel(
          id: '',
          businessId: businessId,
          voucherId: '',
          accountId: partyAccountId,
          entryType: 'Dr',
          amount: totalInvoiceVal,
          itemDescription: 'Receivable against Invoice #${payload.documentNumber}',
        ),
      );

      // 2. Credit Line: Sales Account
      lines.add(
        VoucherLineItemModel(
          id: '',
          businessId: businessId,
          voucherId: '',
          accountId: primaryExpenseOrSalesAccountId,
          entryType: 'Cr',
          amount: totalTaxable,
          itemDescription: 'Sales Turnover for Invoice #${payload.documentNumber}',
        ),
      );

      // 3. Tax Credit Lines (Output Tax Liability)
      if (isInterState && igstAmt > 0) {
        final igstAcc = findAccount('Output IGST', 'Duties & Taxes') ?? accounts.first;
        lines.add(
          VoucherLineItemModel(
            id: '',
            businessId: businessId,
            voucherId: '',
            accountId: igstAcc.id,
            entryType: 'Cr',
            amount: igstAmt,
            igstAmt: igstAmt,
            itemDescription: 'Output IGST Liability',
          ),
        );
      } else {
        if (cgstAmt > 0) {
          final cgstAcc = findAccount('Output CGST', 'Duties & Taxes') ?? accounts.first;
          lines.add(
            VoucherLineItemModel(
              id: '',
              businessId: businessId,
              voucherId: '',
              accountId: cgstAcc.id,
              entryType: 'Cr',
              amount: cgstAmt,
              cgstAmt: cgstAmt,
              itemDescription: 'Output CGST Liability',
            ),
          );
        }
        if (sgstAmt > 0) {
          final sgstAcc = findAccount('Output SGST', 'Duties & Taxes') ?? accounts.first;
          lines.add(
            VoucherLineItemModel(
              id: '',
              businessId: businessId,
              voucherId: '',
              accountId: sgstAcc.id,
              entryType: 'Cr',
              amount: sgstAmt,
              sgstAmt: sgstAmt,
              itemDescription: 'Output SGST Liability',
            ),
          );
        }
      }
    }

    // 4. Mathematical Zero-Sum Round-Off Balancing Line
    final double totalDr = lines.where((l) => l.entryType == 'Dr').fold(0.0, (s, l) => s + l.amount);
    final double totalCr = lines.where((l) => l.entryType == 'Cr').fold(0.0, (s, l) => s + l.amount);
    final double diff = double.parse((totalDr - totalCr).toStringAsFixed(2));

    if (diff.abs() >= 0.01) {
      final roundOffAcc = findAccount('Round Off A/c', 'Indirect Expenses') ??
          findAccount('Misc. Expenses (ASSET)', 'Current Assets') ??
          accounts.first;

      if (diff > 0) {
        // Debits exceed credits -> add Round-Off Credit
        lines.add(
          VoucherLineItemModel(
            id: '',
            businessId: businessId,
            voucherId: '',
            accountId: roundOffAcc.id,
            entryType: 'Cr',
            amount: diff.abs(),
            itemDescription: 'Round-off balancing adjustment',
          ),
        );
      } else {
        // Credits exceed debits -> add Round-Off Debit
        lines.add(
          VoucherLineItemModel(
            id: '',
            businessId: businessId,
            voucherId: '',
            accountId: roundOffAcc.id,
            entryType: 'Dr',
            amount: diff.abs(),
            itemDescription: 'Round-off balancing adjustment',
          ),
        );
      }
    }

    return lines;
  }

  /// Synthesizes standardized bilingual narrations
  static String generateBilingualNarration({
    required String voucherType,
    required String partyName,
    required String docNo,
    required String docDate,
  }) {
    if (voucherType == 'Purchase') {
      return 'Being purchase of goods against Bill No. $docNo dtd $docDate from $partyName.';
    } else if (voucherType == 'Sales') {
      return 'Being sales of goods against Invoice No. $docNo dtd $docDate to $partyName.';
    }
    return 'Transaction against reference #$docNo with $partyName.';
  }
}
