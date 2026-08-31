import '../../../masters/domain/services/active_learning_service.dart';

/// Interceptor that captures user disambiguation decisions and feeds them into the Active Learning engine.
class EntityFeedbackInterceptor {
  final ActiveLearningService _learningService;

  EntityFeedbackInterceptor({ActiveLearningService? learningService})
      : _learningService = learningService ?? ActiveLearningService();

  /// Inspects party and stock item mappings at voucher confirmation time and registers feedback asynchronously
  void interceptAndLearnPartyMapping({
    required String rawExtractedName,
    required String selectedAccountId,
    required bool wasUserDisambiguated,
  }) {
    if (rawExtractedName.trim().isEmpty || !wasUserDisambiguated) return;

    // Fire and forget in the background without blocking the UI
    _learningService.submitResolutionFeedback(
      rawQueryText: rawExtractedName,
      entityType: 'ACCOUNT',
      resolvedEntityId: selectedAccountId,
    ).catchError((_) {});
  }

  /// Inspects inventory line item selections at voucher confirmation time
  void interceptAndLearnStockItemMapping({
    required String rawExtractedItemName,
    required String selectedStockItemId,
    required bool wasUserDisambiguated,
  }) {
    if (rawExtractedItemName.trim().isEmpty || !wasUserDisambiguated) return;

    _learningService.submitResolutionFeedback(
      rawQueryText: rawExtractedItemName,
      entityType: 'STOCK_ITEM',
      resolvedEntityId: selectedStockItemId,
    ).catchError((_) {});
  }
}
