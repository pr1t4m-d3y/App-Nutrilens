import 'dart:convert';
import 'api_fallback_engine.dart';

class SmartScanService {
  final ApiFallbackEngine _api;

  SmartScanService({ApiFallbackEngine? api}) : _api = api ?? ApiFallbackEngine();

  /// Initiates a text-only scan. Image processing happens on-device via OCR.
  Future<Map<String, dynamic>> initiateCloudScan({
    required String ocrText,
    required Map<String, dynamic> userMetadata,
  }) async {
    final prompt = _buildPrompt(ocrText, userMetadata);
    
    // Calls the resilient fallback engine
    final responseText = await _api.executeSmartScan(prompt);
    return _parseJsonResponse(responseText);
  }

  String _buildPrompt(String rawText, Map<String, dynamic> metadata) {
    final bmi = metadata['bmi'] ?? 'Not provided';
    final goals = (metadata['goals'] as List?)?.join(', ') ?? 'None specified';
    final conditions = (metadata['conditions'] as List?)?.join(', ') ?? 'None specified';
    final allergies = (metadata['allergies'] as List?)?.join(', ') ?? 'None';
    final medications = (metadata['medications'] as List?)?.join(', ') ?? 'None';
    final avoidList = (metadata['avoidList'] as List?)?.join(', ') ?? 'None';

    return '''
You are NutriLens AI, a Senior Food Scientist and FSSAI Regulatory Expert (2026 Standards).

## YOUR TASK
Analyze the provided OCR text from a product label. Identify ingredients, assess health impacts for THIS specific user, and return a structured JSON report.

## OCR TEXT (Use for analysis only)
---
${rawText.isNotEmpty ? rawText : "ERROR: No text provided."}
---

## USER HEALTH PROFILE
- BMI: $bmi
- Health Goals: $goals
- Chronic Conditions: $conditions
- Food Allergies: $allergies
- Current Medications: $medications
- Avoid List: $avoidList

## ANALYSIS RULES
1. FSSAI Descending Order Rule: The first ingredient is the highest quantity. Weigh its impact heavily on the final score.
2. Demystify Chemicals: Translate E-numbers or INS codes (e.g., "330") to common names (e.g., "Citric Acid").
3. Categorize `impact` as strictly "bad", "neutral", or "good".
4. STRICT POINT STRUCTURE FOR `details` ARRAY:
   - If BAD: Provide exactly 3 points (Banned/Restricted locations, Reported health hazards, Safety status).
   - If NEUTRAL: Provide exactly 3 points (Why neutral, Context/Source, What happens if consumed in excess).
   - If GOOD: Provide exactly 2 points (General health benefit, Specific benefit in this product context).
5. Calculate `healthScore` (1.0 to 10.0). High sugar, sodium, or banned additives at the top of the list drop the score heavily.
6. Check for marketing gimmicks. If packaging claims "Healthy" but contradicts ingredients, add a `marketingWarning`.

## REQUIRED OUTPUT FORMAT (Valid JSON ONLY)
{
  "productName": "Name from label",
  "healthScore": 5.0,
  "marketingWarning": "Warning text or null",
  "ingredients": [
    {
      "name": "Translated Ingredient Name",
      "impact": "bad", 
      "details": ["Point 1", "Point 2", "Point 3"]
    }
  ],
  "healthierSwap": { 
    "name": "Healthier Alternative",
    "reason": "Why it is better."
  }
}
''';
  }

  Map<String, dynamic> _parseJsonResponse(String response) {
    try {
      final start = response.indexOf('{');
      final end = response.lastIndexOf('}');
      if (start != -1 && end != -1) {
        final cleaned = response.substring(start, end + 1);
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }
      throw FormatException("No JSON block found.");
    } catch (e) {
      throw FormatException("Failed to parse AI response: $e");
    }
  }
}