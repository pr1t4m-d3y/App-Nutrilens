import 'dart:math';

class IndianWeightedScorer {
  /// Defines base negative weights for known harmful ingredients.
  static const Map<String, double> _harmfulWeights = {
    'sugar': 2.0,
    'high fructose corn syrup': 2.5,
    'maltodextrin': 1.5,
    'palm oil': 1.8,
    'artificial colors': 1.0,
    'sodium nitrite': 2.5,
    'msg': 1.0,
    'corn syrup': 2.0,
    'hydrogenated': 2.5,
  };

  /// Calculates a 1.0 - 10.0 score based on FSSAI descending order rules.
  /// Ingredients listed first represent higher proportions of the product.
  /// 
  /// [ingredients]: A raw array of ingredient names in the order they appear on the label.
  double calculateFssaiScore(List<String> ingredients) {
    if (ingredients.isEmpty) return 10.0;

    double baseScore = 10.0;
    double totalPenalty = 0.0;

    for (int i = 0; i < ingredients.length; i++) {
      String item = ingredients[i].toLowerCase();
      double currentPenalty = 0.0;

      // 1. Find if item is harmful
      for (var entry in _harmfulWeights.entries) {
        if (item.contains(entry.key)) {
          currentPenalty = entry.value;
          break;
        }
      }

      // 2. Apply FSSAI position multiplier
      double multiplier = 1.0;
      if (i < 3) {
        // Top 3 ingredients (Bulk of product)
        multiplier = 3.0;
      } else if (i < (ingredients.length / 2).ceil()) {
        // Middle ingredients
        multiplier = 2.0;
      } else {
        // Bottom ingredients (Trace amounts < 2%)
        multiplier = 1.0;
      }

      totalPenalty += (currentPenalty * multiplier);
    }

    // 3. Normalize score strictly bounds between 1.0 and 10.0
    double finalScore = baseScore - totalPenalty;
    return max(1.0, min(10.0, finalScore));
  }
}
