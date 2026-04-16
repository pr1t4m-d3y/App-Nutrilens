import 'package:flutter/material.dart';

class ScanHistoryProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _scans = [];

  List<Map<String, dynamic>> get scans => List.unmodifiable(_scans);
  
  Map<String, dynamic>? get latestScan => _scans.isNotEmpty ? _scans.first : null;

  void addScan(Map<String, dynamic> scanResult) {
    // Add timestamp
    final entry = Map<String, dynamic>.from(scanResult);
    entry['timestamp'] = DateTime.now().toIso8601String();
    
    // Insert at beginning (newest first)
    _scans.insert(0, entry);
    
    // Keep max 50 scans
    if (_scans.length > 50) {
      _scans.removeLast();
    }
    
    notifyListeners();
  }

  void clearHistory() {
    _scans.clear();
    notifyListeners();
  }

  /// Load pre-built demo history for "User123"
  void loadDemoHistory() {
    _scans.clear();
    final now = DateTime.now();
    _scans.addAll([
      {
        'productName': 'Maggi 2-Minute Noodles',
        'healthScore': 3.5,
        'marketingWarning': 'Marketed as "quick healthy meal" but extremely high in sodium and refined flour.',
        'ingredients': [
          {'name': 'Refined Wheat Flour (Maida)', 'impact': 'harmful', 'reasoning': 'Highly processed flour stripped of nutrients. Raises blood sugar quickly and provides empty calories.'},
          {'name': 'Palm Oil', 'impact': 'harmful', 'reasoning': 'High in saturated fats, contributes to elevated LDL cholesterol. Concerning for your Mild Hypertension.'},
          {'name': 'MSG (Monosodium Glutamate)', 'impact': 'harmful', 'reasoning': 'Flavor enhancer linked to headaches in sensitive individuals. Can mask poor ingredient quality.'},
          {'name': 'Sodium', 'impact': 'harmful', 'reasoning': 'Very high sodium content (~860mg per serving). Particularly concerning given your Mild Hypertension.'},
          {'name': 'Turmeric', 'impact': 'good', 'reasoning': 'Natural spice with anti-inflammatory properties.'},
        ],
        'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'productName': 'Amul Taaza Milk',
        'healthScore': 8.2,
        'marketingWarning': null,
        'ingredients': [
          {'name': 'Toned Milk', 'impact': 'good', 'reasoning': 'Good source of calcium and protein with moderate fat content.'},
          {'name': 'Vitamin A', 'impact': 'good', 'reasoning': 'Essential vitamin fortification, supports eye health and immunity.'},
          {'name': 'Vitamin D', 'impact': 'good', 'reasoning': 'Critical for calcium absorption and bone health.'},
        ],
        'timestamp': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'productName': 'Bournvita Health Drink',
        'healthScore': 4.8,
        'marketingWarning': 'Claims to be a "health drink" but primary ingredient is sugar.',
        'ingredients': [
          {'name': 'Sugar', 'impact': 'harmful', 'reasoning': 'First ingredient listed meaning highest quantity. Contributes to weight gain, undermining your Weight Management goal.'},
          {'name': 'Cocoa Solids', 'impact': 'good', 'reasoning': 'Contains antioxidants and natural flavonoids.'},
          {'name': 'Malt Extract', 'impact': 'neutral', 'reasoning': 'Provides B vitamins and some minerals.'},
          {'name': 'Artificial Color', 'impact': 'harmful', 'reasoning': 'Synthetic coloring agents with no nutritional value. May trigger sensitivity reactions.'},
        ],
        'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'productName': 'Parle-G Biscuits',
        'healthScore': 4.0,
        'marketingWarning': null,
        'ingredients': [
          {'name': 'Wheat Flour', 'impact': 'neutral', 'reasoning': 'Whole wheat provides fiber and essential nutrients.'},
          {'name': 'Sugar', 'impact': 'harmful', 'reasoning': 'Second ingredient, high proportion. Not ideal for Weight Management.'},
          {'name': 'Edible Vegetable Oil (Palm)', 'impact': 'harmful', 'reasoning': 'Palm oil is high in saturated fat. In your custom avoid list.'},
          {'name': 'Invert Syrup', 'impact': 'harmful', 'reasoning': 'Additional sugar source adding to overall sugar load.'},
          {'name': 'Milk Solids', 'impact': 'good', 'reasoning': 'Provides some calcium and protein.'},
        ],
        'timestamp': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ]);
    notifyListeners();
  }
}
