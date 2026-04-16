import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// On-device medicine database service.
/// Loads a JSON asset once and provides fast lookup by brand name or composition.
class MedicineDbService {
  // Singleton
  static final MedicineDbService _instance = MedicineDbService._();
  factory MedicineDbService() => _instance;
  MedicineDbService._();

  List<Map<String, dynamic>> _medicines = [];
  bool _loaded = false;

  // Pre-built indexes for O(1) lookup
  final Map<String, List<int>> _brandIndex = {};       // lowercase brand -> indices
  final Map<String, List<int>> _compositionIndex = {};  // lowercase composition -> indices

  /// Call once at app start or lazily on first use.
  Future<void> loadDatabase() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/medicine_db.json');
    final List<dynamic> parsed = json.decode(raw);
    _medicines = parsed.cast<Map<String, dynamic>>();

    // Build indexes
    for (int i = 0; i < _medicines.length; i++) {
      final m = _medicines[i];
      final brand = (m['Brand_Name'] ?? '').toString().toLowerCase().trim();
      final comp = (m['Composition'] ?? '').toString().toLowerCase().trim();
      if (brand.isNotEmpty) {
        _brandIndex.putIfAbsent(brand, () => []).add(i);
      }
      if (comp.isNotEmpty) {
        _compositionIndex.putIfAbsent(comp, () => []).add(i);
      }
    }
    _loaded = true;
  }

  /// Search by OCR text. Returns the BEST match only (1 medicine card).
  /// 
  /// Strategy:
  ///   1. Try exact brand name match (highest confidence).
  ///   2. Try brand name + strength match.
  ///   3. Try composition + strength match.
  ///   4. If nothing specific, return the single best composition match.
  ///   5. Return empty list if nothing found.
  List<Map<String, dynamic>> searchByOcrText(String ocrText) {
    if (!_loaded || ocrText.trim().isEmpty) return [];
    final query = ocrText.toLowerCase().trim();

    // Extract strength from OCR text (e.g., "650 mg", "500mg", "100 mg/ml")
    final strengthPattern = RegExp(r'(\d+\.?\d*)\s*(mg|ml|mcg|gm|g)\b', caseSensitive: false);
    final strengthMatches = strengthPattern.allMatches(query).toList();
    final detectedStrengths = strengthMatches.map((m) => m.group(0)!.replaceAll(' ', '').toLowerCase()).toList();

    // --- Phase 1: Exact brand name match ---
    Map<String, dynamic>? bestBrandMatch;
    int bestBrandScore = 0;
    
    for (final entry in _brandIndex.entries) {
      final brandName = entry.key;
      // Check if the brand name appears in the OCR text
      if (query.contains(brandName)) {
        // Score by length (longer match = more specific = better)
        int score = brandName.length * 10;
        
        // Bonus if strength also matches
        for (final idx in entry.value) {
          final med = _medicines[idx];
          final medStrength = (med['Strength'] ?? '').toString().toLowerCase().replaceAll(' ', '');
          for (final ds in detectedStrengths) {
            if (medStrength.contains(ds) || ds.contains(medStrength.split('/').first)) {
              score += 50; // Big bonus for strength match
            }
          }
          if (score > bestBrandScore) {
            bestBrandScore = score;
            bestBrandMatch = med;
          }
        }
      }
    }

    if (bestBrandMatch != null) {
      return [bestBrandMatch];
    }

    // --- Phase 2: Composition + strength match ---
    Map<String, dynamic>? bestCompMatch;
    int bestCompScore = 0;

    for (final entry in _compositionIndex.entries) {
      final comp = entry.key;
      
      // Check if composition appears in OCR text
      // Also split multi-salt combos like "Tramadol+Paracetamol"
      final salts = comp.split(RegExp(r'[+,/]')).map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
      bool compositionFound = false;
      
      if (salts.length > 1) {
        // Multi-salt: all salts must be present
        compositionFound = salts.every((salt) => query.contains(salt));
      } else if (salts.isNotEmpty) {
        compositionFound = query.contains(salts.first);
      }

      if (!compositionFound) continue;

      // Found composition match - now pick the best one by strength
      for (final idx in entry.value) {
        final med = _medicines[idx];
        int score = salts.fold(0, (sum, s) => sum + s.length); // Base score from composition match
        
        final medStrength = (med['Strength'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        final medDosage = (med['Dosage_Form'] ?? '').toString().toLowerCase();
        
        // Big bonus for strength match
        for (final ds in detectedStrengths) {
          if (medStrength.contains(ds) || ds.contains(medStrength.split('/').first)) {
            score += 100;
          }
        }
        
        // Small bonus for common dosage forms matching
        if (query.contains('tablet') && medDosage.contains('tablet')) score += 20;
        if (query.contains('capsule') && medDosage.contains('capsule')) score += 20;
        if (query.contains('syrup') && medDosage.contains('syrup')) score += 20;
        if (query.contains('drops') && medDosage.contains('drops')) score += 20;
        if (query.contains('suspension') && medDosage.contains('suspension')) score += 20;
        
        if (score > bestCompScore) {
          bestCompScore = score;
          bestCompMatch = med;
        }
      }
    }

    if (bestCompMatch != null) {
      return [bestCompMatch];
    }

    // Removal of fuzzy matching enforces strict exact name or composition match as requested.
    // Without Phase 3, if the explicit Brand Name or Composition isn't in the OCR text, it returns nothing.
    return [];
  }

  /// Search specifically by brand name.
  List<Map<String, dynamic>> searchByBrandName(String brandName) {
    if (!_loaded) return [];
    final query = brandName.toLowerCase().trim();
    final results = <Map<String, dynamic>>[];
    for (final entry in _brandIndex.entries) {
      if (entry.key.contains(query) || query.contains(entry.key)) {
        for (final idx in entry.value) {
          results.add(_medicines[idx]);
        }
      }
    }
    return results;
  }

  /// Search by composition / salt name.
  List<Map<String, dynamic>> searchByComposition(String composition) {
    if (!_loaded) return [];
    final query = composition.toLowerCase().trim();
    final results = <Map<String, dynamic>>[];
    for (final entry in _compositionIndex.entries) {
      if (entry.key.contains(query) || query.contains(entry.key)) {
        for (final idx in entry.value) {
          results.add(_medicines[idx]);
        }
      }
    }
    return results;
  }

  int get totalMedicines => _medicines.length;
}
