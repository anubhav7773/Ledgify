import '../../../masters/domain/models/stock_item_match_result.dart';
import '../../../masters/domain/services/inventory_matching_service.dart';
import '../../../vouchers/domain/models/voucher_line_item_model.dart';
import '../models/extracted_invoice_payload.dart';

/// Resolved line item with linked stock item metadata and tax allocation
class ResolvedLineItem {
  final ExtractedLineItem rawLineItem;
  final StockItemMatchResult? matchResult;
  final String? matchedStockItemId;
  final String confirmedHsnCode;
  final double confirmedGstRate;

  const ResolvedLineItem({
    required this.rawLineItem,
    this.matchResult,
    this.matchedStockItemId,
    required this.confirmedHsnCode,
    required this.confirmedGstRate,
  });

  bool get isAutoMatched => matchResult?.isAutoMatched ?? false;
  bool get needsUserReview => matchResult?.isAmbiguous ?? false;
  bool get needsCreation => matchResult?.needsCreation ?? true;
}

/// Pipeline service that resolves line items concurrently against inventory stock items
class LineItemResolverPipeline {
  final InventoryMatchingService _inventoryService;

  LineItemResolverPipeline({InventoryMatchingService? inventoryService})
      : _inventoryService = inventoryService ?? InventoryMatchingService();

  /// Concurrently resolves an array of OCR/Voice extracted line items against local catalog
  Future<List<ResolvedLineItem>> resolveLineItems(List<ExtractedLineItem> rawItems) async {
    final futures = rawItems.map((item) async {
      final matches = await _inventoryService.matchStockItem(
        itemName: item.itemDescription,
        extractedHsn: item.hsnCode,
      );

      if (matches.isNotEmpty) {
        final topMatch = matches.first;
        return ResolvedLineItem(
          rawLineItem: item,
          matchResult: topMatch,
          matchedStockItemId: topMatch.isAutoMatched ? topMatch.stockItemId : null,
          confirmedHsnCode: topMatch.hsnSacCode.isNotEmpty ? topMatch.hsnSacCode : item.hsnCode,
          confirmedGstRate: topMatch.gstRateSlab > 0 ? topMatch.gstRateSlab : item.gstRate,
        );
      } else {
        return ResolvedLineItem(
          rawLineItem: item,
          matchResult: null,
          matchedStockItemId: null,
          confirmedHsnCode: item.hsnCode,
          confirmedGstRate: item.gstRate,
        );
      }
    });

    return await Future.wait(futures);
  }

  /// Maps a resolved line item to a double-entry VoucherLineItemModel
  static VoucherLineItemModel toVoucherLineItem({
    required String businessId,
    required ResolvedLineItem resolved,
    required String expenseOrSalesAccountId,
    required String entryType, // 'Dr' or 'Cr'
  }) {
    final raw = resolved.rawLineItem;

    return VoucherLineItemModel(
      id: '',
      businessId: businessId,
      voucherId: '',
      accountId: expenseOrSalesAccountId,
      stockItemId: resolved.matchedStockItemId,
      entryType: entryType,
      amount: raw.itemTotal,
      quantity: raw.quantity,
      rate: raw.unitPrice,
      hsnCode: resolved.confirmedHsnCode,
      gstRate: resolved.confirmedGstRate,
      cgstAmt: raw.cgstAmount,
      sgstAmt: raw.sgstAmount,
      igstAmt: raw.igstAmount,
      itemDescription: raw.itemDescription,
    );
  }
}
