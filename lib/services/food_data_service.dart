import 'dart:convert';
import 'package:flutter/services.dart';

class FoodDataService {
  static final FoodDataService _instance = FoodDataService._internal();
  factory FoodDataService() => _instance;
  FoodDataService._internal();

  List<dynamic> _foodList = [];
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final jsonString = await rootBundle.loadString('assets/nlp/product.json');
      _foodList = json.decode(jsonString);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Init Food error: $e');
    }
  }

  Future<List<dynamic>> searchProductsByIntent(String query, String intentTag) async {
    if (!_isInitialized) await initialize();
    
    final lowerQuery = query.toLowerCase();
    final keywords = lowerQuery.replaceAll(RegExp(r'[^\w\s]'), '').split(' ');
    
    // Ignore intent-driving adjectives so we can isolate the target food noun (e.g., "biscuit")
    final ignoreWords = ['find', 'me', 'show', 'some', 'give', 'the', 'a', 'an', 'healthy', 'good', 'best', 'worst', 'sugar', 'free', 'high', 'low', 'protein', 'vegan', 'keto', 'calorie', 'gluten', 'friendly', 'kids', 'time', 'tea', 'budget'];
    final nouns = keywords.where((k) => k.length >= 3 && !ignoreWords.contains(k)).toList();

    final filteredProducts = _foodList.where((item) {
      final double score = (item['HealthRating'] as num?)?.toDouble() ?? (item['TotalScore'] as num?)?.toDouble() ?? 0.0;
      final List searchKey = (item['SearchKeywords'] as List?) ?? [];
      final String name = (item['ProductName'] ?? '').toLowerCase();
      final String category = (item['Category'] ?? '').toLowerCase();
      
      // Base text matching for product isolating
      bool textMatch = nouns.isEmpty; 
      if (nouns.isNotEmpty) {
        for(final noun in nouns) {
           if (name.contains(noun) || category.contains(noun) || searchKey.any((k) => k.toString().toLowerCase().contains(noun))) {
              textMatch = true;
              break;
           }
        }
      }

      // If intent is nonsense, just rely completely on text matching (e.g., query="biscuit" -> intent="goodbye")
      bool isNonsenseIntent = ['greetings', 'goodbye', 'fallback', 'unknown'].contains(intentTag);
      if (isNonsenseIntent) {
        return textMatch;
      }
      
      // Intent mapping
      bool intentMatch = false;
      switch (intentTag) {
        case 'filter_top_rated':
          intentMatch = score >= 7.0;
          break;
        case 'filter_worst':
          intentMatch = score <= 4.0;
          break;
        case 'filter_sugar_free':
          intentMatch = item['IsSugarFree'] == true;
          break;
        case 'filter_high_protein':
          intentMatch = item['IsHighProtein'] == true;
          break;
        case 'filter_palm_oil_free':
          final List badIngredients = (item['BadIngredients'] as List?) ?? [];
          final allBad = badIngredients.map((e) => e.toString().toLowerCase()).toList();
          intentMatch = !allBad.any((ingredient) => ingredient.contains('palm oil'));
          break;
        case 'filter_vegan':
          intentMatch = item['IsVegan'] == true;
          break;
        default:
          intentMatch = false;
      }
      
      return intentMatch && textMatch;
    }).toList();

    filteredProducts.sort((a, b) {
      final double scoreA = (a['HealthRating'] as num?)?.toDouble() ?? (a['TotalScore'] as num?)?.toDouble() ?? 0.0;
      final double scoreB = (b['HealthRating'] as num?)?.toDouble() ?? (b['TotalScore'] as num?)?.toDouble() ?? 0.0;
      
      if (intentTag == 'filter_worst') {
        return scoreA.compareTo(scoreB);
      }
      return scoreB.compareTo(scoreA);
    });

    return filteredProducts;
  }
}
