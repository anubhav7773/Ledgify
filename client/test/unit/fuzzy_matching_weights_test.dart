import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Two-Stage Hybrid Fuzzy Matching Weighting Suite', () {
    double computeFuzzyScore({
      required double trigramSimilarity,
      required double levenshteinSimilarity,
      required bool phoneticMatch,
    }) {
      final base = (0.50 * trigramSimilarity) + (0.30 * levenshteinSimilarity);
      final phoneticBonus = phoneticMatch ? 0.20 : 0.00;
      return double.parse((base + phoneticBonus).clamp(0.0, 1.0).toStringAsFixed(3));
    }

    test('Exact match yields 1.0 composite score', () {
      final score = computeFuzzyScore(
        trigramSimilarity: 1.0,
        levenshteinSimilarity: 1.0,
        phoneticMatch: true,
      );
      expect(score, 1.0);
    });

    test('High Confidence Auto-Match Threshold (>= 0.85)', () {
      // Minor OCR typo: "Shree Ganesh" vs "Shri Ganeshh"
      final score = computeFuzzyScore(
        trigramSimilarity: 0.85,
        levenshteinSimilarity: 0.88,
        phoneticMatch: true, // Phonetic codes match
      );

      expect(score >= 0.85, true);
    });

    test('Ambiguous Suggestion Threshold (0.50 <= Score < 0.85)', () {
      // Partial name match: "Ganesh Traders" vs "Ganesh Enterprises"
      final score = computeFuzzyScore(
        trigramSimilarity: 0.65,
        levenshteinSimilarity: 0.70,
        phoneticMatch: false,
      );

      expect(score >= 0.50 && score < 0.85, true);
    });

    test('Unmapped Fallback (< 0.50)', () {
      // Unrelated entity
      final score = computeFuzzyScore(
        trigramSimilarity: 0.20,
        levenshteinSimilarity: 0.15,
        phoneticMatch: false,
      );

      expect(score < 0.50, true);
    });
  });
}
