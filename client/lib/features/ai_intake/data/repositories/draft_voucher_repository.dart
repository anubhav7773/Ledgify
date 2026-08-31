import 'package:uuid/uuid.dart';
import '../../../../core/utils/safe_executor.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../vouchers/data/repositories/voucher_repository.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../domain/models/extracted_invoice_payload.dart';
import '../domain/services/voucher_drafting_service.dart';

/// Repository managing the storage, resolution, and atomic finalization of AI-drafted vouchers.
class DraftVoucherRepository {
  final AccountRepository _accountRepository;
  final VoucherRepository _voucherRepository;
  final VoucherDraftingService _draftingService;

  // In-memory cache for pending AI drafts
  static final Map<String, ExtractedInvoicePayload> _draftsCache = {};

  DraftVoucherRepository({
    AccountRepository? accountRepository,
    VoucherRepository? voucherRepository,
    VoucherDraftingService? draftingService,
  })  : _accountRepository = accountRepository ?? AccountRepository(),
        _voucherRepository = voucherRepository ?? VoucherRepository(),
        _draftingService = draftingService ?? VoucherDraftingService();

  /// Saves a newly extracted AI payload to the drafts queue
  Future<String> saveDraft(ExtractedInvoicePayload payload) async {
    return await executeSafely<String>(() async {
      final draftId = const Uuid().v4();
      _draftsCache[draftId] = payload;
      return draftId;
    });
  }

  /// Retrieves all pending unprocessed AI intake drafts
  Future<Map<String, ExtractedInvoicePayload>> getPendingDrafts() async {
    return await executeSafely<Map<String, ExtractedInvoicePayload>>(() async {
      return Map.unmodifiable(_draftsCache);
    });
  }

  /// Deletes a rejected or discarded draft
  Future<void> deleteDraft(String draftId) async {
    await executeSafely<void>(() async {
      _draftsCache.remove(draftId);
    });
  }

  /// Finalizes an AI draft: creates any new party ledgers, builds balanced lines, and commits to PostgreSQL
  Future<Map<String, dynamic>> finalizeAndPostDraft({
    required String draftId,
    required ExtractedInvoicePayload draft,
    required String businessId,
    required String voucherTypeId,
    required String primaryExpenseOrSalesAccountId,
    AccountModel? newPartyToCreate,
    String? existingPartyAccountId,
    int supplierStateCode = 27,
    int buyerStateCode = 27,
  }) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      String partyAccountId = existingPartyAccountId ?? '';

      // 1. If new party ledger needs to be created on-the-fly, create it first
      if (newPartyToCreate != null) {
        final created = await _accountRepository.createLedger(newPartyToCreate);
        partyAccountId = created.id;
      }

      final isPurchase = draft.accountingPosting['voucher_type'] == 'Purchase' ||
          draft.accountingPosting['voucher_type'] == null;

      // 2. Build balanced line items with taxes and round-off
      final balancedLines = await _draftingService.buildBalancedLines(
        businessId: businessId,
        payload: draft,
        primaryExpenseOrSalesAccountId: primaryExpenseOrSalesAccountId,
        partyAccountId: partyAccountId,
        isPurchase: isPurchase,
        supplierStateCode: supplierStateCode,
        buyerStateCode: buyerStateCode,
      );

      final narration = VoucherDraftingService.generateBilingualNarration(
        voucherType: isPurchase ? 'Purchase' : 'Sales',
        partyName: draft.sellerName,
        docNo: draft.documentNumber,
        docDate: draft.documentDate,
      );

      // 3. Assemble complete double-entry VoucherModel
      final voucher = VoucherModel(
        id: '',
        businessId: businessId,
        voucherTypeId: voucherTypeId,
        voucherNumber: draft.documentNumber,
        voucherDate: DateTime.tryParse(draft.documentDate) ?? DateTime.now(),
        narration: narration,
        aiConfidenceScore: draft.confidenceScore,
        lineItems: balancedLines,
      );

      // 4. Commit atomically to PostgreSQL
      final result = await _voucherRepository.createVoucher(voucher);

      // 5. Purge draft from cache upon success
      _draftsCache.remove(draftId);

      return result;
    });
  }
}
