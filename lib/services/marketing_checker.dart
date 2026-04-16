class MarketingChecker {
  /// Defines common misleading marketing phrases and the actual ingredients that violate them.
  static final Map<String, List<String>> _marketingViolations = {
    'no added sugar': ['maltodextrin', 'high fructose corn syrup', 'dextrose', 'sucrose', 'fruit juice concentrate', 'agave'],
    'sugar free': ['maltodextrin', 'dextrose', 'sucrose', 'fructose'],
    '100% natural': ['artificial colors', 'red 40', 'blue 1', 'yellow 5', 'high fructose corn syrup', 'potassium sorbate', 'sodium benzoate', 'bht', 'bha'],
    'real fruit': ['fruit juice concentrate', 'artificial flavors'],
    'heart healthy': ['palm oil', 'hydrogenated', 'partially hydrogenated', 'sodium nitrite', 'high sodium'],
    'zero fat': ['mono and diglycerides'],
  };

  /// Cross-references the marketing claims on the front of the package 
  /// with the actual ingredient list on the back.
  /// Returns a warning message string if a violation is found, otherwise null.
  String? realityCheck(String marketingText, List<String> ingredients) {
    if (marketingText.isEmpty || ingredients.isEmpty) return null;

    final lowerMarketing = marketingText.toLowerCase();
    
    // We combine all ingredients into one string for easy sub-string searching
    final combinedIngredients = ingredients.map((e) => e.toLowerCase()).join(' , ');

    for (var claim in _marketingViolations.keys) {
      if (lowerMarketing.contains(claim)) {
        // The product claims something. Let's check if they violate it.
        final violationList = _marketingViolations[claim]!;
        
        for (var violator in violationList) {
          if (combinedIngredients.contains(violator)) {
            // Found a reality check hit!
            return 'Marketing says "\$claim", but contains \$violator.';
          }
        }
      }
    }

    return null; // No strict violations found by basic heuristics
  }
}
