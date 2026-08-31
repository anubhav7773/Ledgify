/// Domain model representing the Stock Valuation and Inventory Summary report.
class StockSummaryItem {
  final String stockItemId;
  final String stockItemName;
  final String? hsnOrSacCode;
  final String? groupName;
  final String? uomSymbol;
  final double openingQty;
  final double openingRate;
  final double openingVal;
  final double closingQty;
  final double closingRate;
  final double closingVal;

  const StockSummaryItem({
    required this.stockItemId,
    required this.stockItemName,
    this.hsnOrSacCode,
    this.groupName,
    this.uomSymbol,
    required this.openingQty,
    required this.openingRate,
    required this.openingVal,
    required this.closingQty,
    required this.closingRate,
    required this.closingVal,
  });

  factory StockSummaryItem.fromJson(Map<String, dynamic> json) {
    return StockSummaryItem(
      stockItemId: json['stock_item_id'] as String? ?? '',
      stockItemName: json['stock_item_name'] as String? ?? '',
      hsnOrSacCode: json['hsn_or_sac_code'] as String?,
      groupName: json['group_name'] as String?,
      uomSymbol: json['uom_symbol'] as String? ?? 'PCS',
      openingQty: (json['opening_qty'] as num?)?.toDouble() ?? 0.00,
      openingRate: (json['opening_rate'] as num?)?.toDouble() ?? 0.00,
      openingVal: (json['opening_val'] as num?)?.toDouble() ?? 0.00,
      closingQty: (json['closing_qty'] as num?)?.toDouble() ?? 0.00,
      closingRate: (json['closing_rate'] as num?)?.toDouble() ?? 0.00,
      closingVal: (json['closing_val'] as num?)?.toDouble() ?? 0.00,
    );
  }
}

class StockSummaryReportModel {
  final DateTime asOfDate;
  final int totalItems;
  final double totalInventoryValue;
  final List<StockSummaryItem> items;

  const StockSummaryReportModel({
    required this.asOfDate,
    required this.totalItems,
    required this.totalInventoryValue,
    required this.items,
  });

  factory StockSummaryReportModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return StockSummaryReportModel(
      asOfDate: DateTime.parse(json['as_of_date'] as String),
      totalItems: json['total_items'] as int? ?? 0,
      totalInventoryValue: (json['total_inventory_value'] as num?)?.toDouble() ?? 0.00,
      items: rawItems.map((i) => StockSummaryItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}
