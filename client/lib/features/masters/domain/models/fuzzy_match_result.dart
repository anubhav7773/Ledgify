/// Domain model representing the output of the Two-Stage Hybrid Entity Resolution Engine.
/// Adheres strictly to docs/07_fuzzy_entity_matching_spec.md.
class FuzzyMatchResult {
  final String entityId;
  final String entityName;
  final String primaryClassification;
  final String groupName;
  final double compositeScore; // 0.0000 to 1.0000
  final String matchReason;

  const FuzzyMatchResult({
    required this.entityId,
    required this.entityName,
    required this.primaryClassification,
    required this.groupName,
    required this.compositeScore,
    required this.matchReason,
  });

  factory FuzzyMatchResult.fromJson(Map<String, dynamic> json) {
    return FuzzyMatchResult(
      entityId: (json['entity_id'] ?? json['account_id'] ?? json['item_id']) as String,
      entityName: (json['entity_name'] ?? json['account_name'] ?? json['item_name']) as String,
      primaryClassification: (json['primary_classification'] ?? 'Asset') as String,
      groupName: (json['group_name'] ?? 'Sundry Debtors') as String,
      compositeScore: ((json['composite_score'] ?? json['final_confidence'] ?? json['confidence_score']) as num).toDouble(),
      matchReason: (json['match_reason'] ?? json['decision_action'] ?? 'HYBRID_MATCH') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entity_id': entityId,
      'entity_name': entityName,
      'primary_classification': primaryClassification,
      'group_name': groupName,
      'composite_score': compositeScore,
      'match_reason': matchReason,
    };
  }

  /// Score >= 0.85: Auto-links directly to voucher without user prompt
  bool get isAutoMatchEligible => compositeScore >= 0.85;

  /// 0.50 <= Score < 0.85: Displays visual candidate picker sheet for user disambiguation
  bool get isAmbiguousCandidate => compositeScore >= 0.50 && compositeScore < 0.85;

  /// Score < 0.50: Prompts 1-click on-the-fly master ledger creation
  bool get isUnmatched => compositeScore < 0.50;

  /// Human-readable match percentage
  int get matchPercentage => (compositeScore * 100).round().clamp(0, 100);
}
