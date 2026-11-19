class LocalScanner {
  // Pre-compiled regex libraries for common medical/allergenic markers
  static final Map<String, RegExp> _libraries = {
    // Tree Nuts
    'tree nuts': RegExp(r'(almond|pecan|walnut|cashew|pistachio|macadamia|hazelnut|brazil nut|pine nut)', caseSensitive: false),
    // Peanuts
    'peanuts': RegExp(r'(peanut|arachis|groundnut|mandelonas)', caseSensitive: false),
    // Dairy / Lactose
    'lactose': RegExp(r'(milk|butter|cheese|whey|casein|lactose|cream|ghee|yogurt|curd)', caseSensitive: false),
    // Gluten
    'gluten': RegExp(r'(wheat|barley|rye|oats|spelt|kamut|triticale|malt|seitan)', caseSensitive: false),
    // Soy
    'soy': RegExp(r'(soy|soya|edamame|miso|tempeh|tofu|shoyu|tamari)', caseSensitive: false),
    // Shellfish
    'shellfish': RegExp(r'(shrimp|crab|lobster|crawfish|prawn|barnacle|krill|clam|oyster|scallop|mussel|squid|octopus)', caseSensitive: false),
    // Eggs
    'eggs': RegExp(r'(egg|albumen|lysozyme|mayonnaise|meringue|ovalbumin|surimi|vitellin)', caseSensitive: false),

    // Hidden sugars (for pre-diabetes / diabetes)
    'hidden_sugars': RegExp(r'(maltodextrin|dextrose|fructose|sucrose|glucose|agave|corn syrup|molasses|cane juice|caramel|dextran|diastase|ethyl maltol|galactose)', caseSensitive: false),
  };

  /// The allergen groups that have a pattern library, in a stable order.
  /// Used by the evaluation harness.
  static List<String> get allergenGroups =>
      _libraries.keys.where((k) => k != 'hidden_sugars').toList();

  /// Performs an instant, on-device scan of OCR text against the user's
  /// allergies, conditions and avoid list.
  /// Returns a list of detected threat strings. Empty means nothing matched
  /// locally, which is not a guarantee that the product is safe.
  List<String> scanForThreats({
    required String ocrText,
    required List<String> userAllergies,
    required List<String> userConditions,
    List<String> userAvoidList = const [],
  }) {
    final Set<String> detectedThreats = {};
    final lowerOcr = ocrText.toLowerCase();

    // 1. Scan direct user allergies (targeted matches)
    for (String allergy in userAllergies) {
      final allergyKey = allergy.toLowerCase().trim();
      if (allergyKey.isEmpty) continue;

      // If we have a multi-word regex library for it, use it
      if (_libraries.containsKey(allergyKey)) {
        final matches = _libraries[allergyKey]!.allMatches(lowerOcr);
        for (var match in matches) {
          detectedThreats.add(match.group(0)!);
        }
      } else if (lowerOcr.contains(allergyKey)) {
        // Fallback to strict string contains
        detectedThreats.add(allergyKey);
      }
    }

    // 2. Scan the user's own avoid list (exact substring matches)
    for (String avoid in userAvoidList) {
      final avoidKey = avoid.toLowerCase().trim();
      if (avoidKey.length >= 3 && lowerOcr.contains(avoidKey)) {
        detectedThreats.add(avoidKey);
      }
    }

    // 3. Scan for specific conditions (e.g. diabetes -> hidden sugars)
    for (String condition in userConditions) {
      if (condition.toLowerCase().contains('diabetes')) {
        final matches = _libraries['hidden_sugars']!.allMatches(lowerOcr);
        for (var match in matches) {
          detectedThreats.add('${match.group(0)} (High Glycemic)');
        }
      }
    }

    return detectedThreats.toList();
  }
}
