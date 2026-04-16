import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ApiFallbackEngine {
  /// Strict Text-Only Pipeline: G1 -> GR1 -> G2 -> G3 -> GR2
  Future<String> executeSmartScan(String prompt) async {
    List<String> errorLogs = [];
    final timeout = const Duration(seconds: 30); // bumped from 15s for real-world connections

    final keys = {
      'g1':  dotenv.env['GEMINI_KEY_1'] ?? '',
      'gr1': dotenv.env['GROQ_KEY_1']   ?? '',
      'g2':  dotenv.env['GEMINI_KEY_2'] ?? '',
      'g3':  dotenv.env['GEMINI_KEY_3'] ?? '',
      'gr2': dotenv.env['GROQ_KEY_2']   ?? '',
    };

    // Log which keys are populated so we can diagnose missing-key failures
    debugPrint('[API] Key status: '
      'G1=${keys['g1']!.isNotEmpty} GR1=${keys['gr1']!.isNotEmpty} '
      'G2=${keys['g2']!.isNotEmpty} G3=${keys['g3']!.isNotEmpty} '
      'GR2=${keys['gr2']!.isNotEmpty}');

    // Sequential Fallback Chain
    debugPrint('[API] Trying G1 (Gemini primary)...');
    try { return await _callGemini(prompt, keys['g1']!, timeout); } catch (e) { errorLogs.add("G1: $e"); debugPrint('[API] G1 failed: $e'); }
    debugPrint('[API] Trying GR1 (Groq primary)...');
    try { return await _callGroq(prompt, keys['gr1']!, timeout); } catch (e) { errorLogs.add("GR1: $e"); debugPrint('[API] GR1 failed: $e'); }
    debugPrint('[API] Trying G2 (Gemini key 2)...');
    try { return await _callGemini(prompt, keys['g2']!, timeout); } catch (e) { errorLogs.add("G2: $e"); debugPrint('[API] G2 failed: $e'); }
    debugPrint('[API] Trying G3 (Gemini key 3)...');
    try { return await _callGemini(prompt, keys['g3']!, timeout); } catch (e) { errorLogs.add("G3: $e"); debugPrint('[API] G3 failed: $e'); }
    debugPrint('[API] Trying GR2 (Groq backup)...');
    try { return await _callGroq(prompt, keys['gr2']!, timeout); } catch (e) { errorLogs.add("GR2: $e"); debugPrint('[API] GR2 failed: $e'); }

    final summary = errorLogs.join(' | ');
    debugPrint('[API] ALL NODES FAILED: $summary');
    throw Exception("All API nodes failed. Error Summary: $summary");
  }

  Future<String> _callGemini(String prompt, String apiKey, Duration timeout) async {
    if (apiKey.isEmpty) throw Exception("Key Missing");
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
          "temperature": 0.1,
          "responseMimeType": "application/json",
        }
      }),
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Gemini response can be in text or directly structured
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text == null || (text as String).trim().isEmpty) {
        throw Exception("Gemini returned empty text. Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");
      }
      return text;
    }
    throw Exception("Gemini ${response.statusCode}: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");
  }

  Future<String> _callGroq(String prompt, String apiKey, Duration timeout) async {
    if (apiKey.isEmpty) throw Exception("Key Missing");
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        "model": "llama-3.1-70b-versatile", // Stable text model for Groq
        "messages": [
          {"role": "system", "content": "You are NutriLens AI. Output valid JSON strictly."},
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.1,
        "response_format": {"type": "json_object"}, //
      }),
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    }
    throw Exception("Groq Status: ${response.statusCode}");
  }
}