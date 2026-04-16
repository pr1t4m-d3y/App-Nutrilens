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

  /// Performs an instant, localized RegEx scan of OCR text against the user's specific avoid list.
  /// Returns a list of detected threat strings. Empty list means "Safe" (locally).
  List<String> scanForThreats({
    required String ocrText,
    required List<String> userAllergies,
    required List<String> userConditions,
  }) {
    final Set<String> detectedThreats = {};
    final lowerOcr = ocrText.toLowerCase();

    // 1. Scan direct user allergies (Targeted matches)
    for (String allergy in userAllergies) {
      final allergyKey = allergy.toLowerCase();
      
      // If we have a robust multi-word regex library for it, use it
      if (_libraries.containsKey(allergyKey)) {
        final matches = _libraries[allergyKey]!.allMatches(lowerOcr);
        for (var match in matches) {
          detectedThreats.add(match.group(0)!);
        }
      } else {
        // Fallback to strict string contains
        if (lowerOcr.contains(allergyKey)) {
          detectedThreats.add(allergyKey);
        }
      }
    }

    // 2. Scan for specific conditions (e.g. Pre-diabetes -> hidden sugars)
    for (String condition in userConditions) {
      if (condition.toLowerCase().contains("diabetes")) {
        final matches = _libraries['hidden_sugars']!.allMatches(lowerOcr);
        for (var match in matches) {
          detectedThreats.add("\${match.group(0)} (High Glycemic)");
        }
      }
    }

    return detectedThreats.toList();
  }
}
