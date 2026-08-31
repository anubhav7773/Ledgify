/// Domain model representing the match output of the inventory fuzzy resolution engine.
class StockItemMatchResult {
  final String stockItemId;
  final String itemName;
  final String hsnSacCode;
  final double gstRateSlab;
  final String uqc;
  final double compositeScore;
  final String resolutionStatus; // 'AUTO_MATCHED', 'AMBIGUOUS_SUGGESTION', 'NEEDS_CREATION'

  const StockItemMatchResult({
    required this.stockItemId,
    required this.itemName,
    required this.hsnSacCode,
    required this.gstRateSlab,
    required this.uqc,
    required this.compositeScore,
    required this.resolutionStatus,
  });

  factory StockItemMatchResult.fromJson(Map<String, dynamic> json) {
    return StockItemMatchResult(
      stockItemId: (json['stock_item_id'] ?? '') as String,
      itemName: (json['item_name'] ?? '') as String,
      hsnSacCode: (json['hsn_sac_code'] ?? '998311') as String,
      gstRateSlab: (json['gst_rate_slab'] as num?)?.toDouble() ?? 18.00,
      uqc: (json['uqc'] ?? 'NOS') as String,
      compositeScore: (json['composite_score'] as num?)?.toDouble() ?? 0.0,
      resolutionStatus: (json['resolution_status'] ?? 'NEEDS_CREATION') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stock_item_id': stockItemId,
      'item_name': itemName,
      'hsn_sac_code': hsnSacCode,
      'gst_rate_slab': gstRateSlab,
      'uqc': uqc,
      'composite_score': compositeScore,
      'resolution_status': resolutionStatus,
    };
  }

  bool get isAutoMatched => resolutionStatus == 'AUTO_MATCHED' || compositeScore >= 0.85;
  bool get isAmbiguous => resolutionStatus == 'AMBIGUOUS_SUGGESTION' || (compositeScore >= 0.50 && compositeScore < 0.85);
  bool get needsCreation => resolutionStatus == 'NEEDS_CREATION' || compositeScore < 0.50;
  int get matchPercentage => (compositeScore * 100).round().clamp(0, 100);
}
