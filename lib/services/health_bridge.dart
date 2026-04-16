class HealthBridge {
  /// Common E-Number / INS Code Additive mappings.
  static const Map<String, Map<String, String>> _additiveDatabase = {
    'E129': {'name': 'Allura Red AC', 'risk': 'May cause hyperactivity in children and allergic reactions.'},
    'E133': {'name': 'Brilliant Blue FCF', 'risk': 'Artificial blue dye, historically linked to mild allergies.'},
    'E211': {'name': 'Sodium Benzoate', 'risk': 'Preservative. Can form benzene (carcinogen) when combined with Vitamin C.'},
    'E250': {'name': 'Sodium Nitrite', 'risk': 'Preservative in meats. High FSSAI hazard rating for cardiovascular health.'},
    'E300': {'name': 'Ascorbic Acid', 'risk': 'Safe. Vitamin C.'},
    'E330': {'name': 'Citric Acid', 'risk': 'Safe. Natural preservative.'},
    'E621': {'name': 'Monosodium Glutamate (MSG)', 'risk': 'Flavor enhancer. Can cause headaches in sensitive individuals (MSG symptom complex).'},
    'E951': {'name': 'Aspartame', 'risk': 'Artificial sweetener. Not recommended for PKU patients.'},
    'INS129': {'name': 'Allura Red AC', 'risk': 'May cause hyperactivity in children.'},
    'INS621': {'name': 'Monosodium Glutamate', 'risk': 'Flavor enhancer. Can cause mild reactions in sensitive users.'},
  };

  /// Decodes a chemical E-number or INS code into a layman-friendly map.
  /// Returns { 'name': '...', 'risk': '...' } or null if unknown.
  Map<String, String>? decodeAdditive(String code) {
    final cleanedCode = code.toUpperCase().trim();
    if (_additiveDatabase.containsKey(cleanedCode)) {
      return _additiveDatabase[cleanedCode];
    }
    // Attempt to match E-number variants if missing the 'E' prefix but numbers match
    for (var entry in _additiveDatabase.entries) {
      if (entry.key.contains(cleanedCode) && cleanedCode.length >= 3) {
        return entry.value;
      }
    }
    return null;
  }

  /// Layman Engine Mapping logic.
  /// Converts a strict clinical health condition into a simple phrasing for the UI.
  String toLaymanTerms(String clinicalCondition, String ingredient) {
    clinicalCondition = clinicalCondition.toLowerCase();
    ingredient = ingredient.toLowerCase();

    if (clinicalCondition.contains("diabetes")) {
      if (ingredient.contains("sugar") || ingredient.contains("maltodextrin") || ingredient.contains("syrup")) {
        return "This ingredient acts like sugar in the body, which can spike your blood glucose rapidly. Not ideal for pre-diabetes.";
      }
    }
    
    if (clinicalCondition.contains("hypertension") || clinicalCondition.contains("blood pressure")) {
      if (ingredient.contains("sodium") || ingredient.contains("salt")) {
        return "Contains significant sodium which directly impacts blood pressure levels. Best to avoid or limit.";
      }
    }

    // Default generic fallback
    return "This ingredient poses a moderate risk to your health profile.";
  }
}
