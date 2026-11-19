import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_token_service.dart';
import 'cloud_config.dart';

/// Thrown when the cloud cannot be used. Carries a short reason, never
/// response bodies or request content.
class CloudUnavailable implements Exception {
  final String reason;
  const CloudUnavailable(this.reason);

  @override
  String toString() => 'CloudUnavailable($reason)';
}

/// One passage returned by regulation search: verbatim text from a
/// published document, with where it comes from.
class RegulationHit {
  final String title;
  final String locator;
  final String snippet;
  const RegulationHit({required this.title, required this.locator, required this.snippet});
}

/// Client for the NutriLens backend. Sends only what the task needs: label
/// text plus coarse allergy / condition / avoid-list entries. Never the name,
/// age, weight, medicines or the photo (the photo is sent only by
/// [ocrFallback], which the user triggers explicitly).
class CloudClient {
  static const int _maxFlagItems = 20;
  static const int _maxFlagChars = 60;

  final http.Client _http;
  final AuthTokenService _auth;

  CloudClient({http.Client? httpClient, AuthTokenService? auth})
      : _http = httpClient ?? http.Client(),
        _auth = auth ?? AuthTokenService();

  Uri _uri(String path) {
    final base = CloudConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers({String contentType = 'application/json'}) async {
    final token = await _auth.idToken();
    if (token == null) throw const CloudUnavailable('not signed in');
    return {'Authorization': 'Bearer $token', 'Content-Type': contentType};
  }

  /// Trims a profile list to what the backend accepts.
  static List<String> flags(List<String> values) {
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .map((v) => v.length > _maxFlagChars ? v.substring(0, _maxFlagChars) : v)
        .take(_maxFlagItems)
        .toList();
  }

  static Map<String, dynamic> explainBody({
    required String labelText,
    required List<String> allergies,
    required List<String> conditions,
    required List<String> avoid,
  }) {
    return {
      'label_text': labelText,
      'profile': {
        'allergies': flags(allergies),
        'conditions': flags(conditions),
        'avoid': flags(avoid),
      },
    };
  }

  /// Returns the backend's JSON: `status` is `ok` or `no_source_found`.
  Future<Map<String, dynamic>> explain({
    required String labelText,
    required List<String> allergies,
    required List<String> conditions,
    required List<String> avoid,
  }) async {
    if (!CloudConfig.isConfigured) throw const CloudUnavailable('not configured');
    final response = await _http
        .post(
          _uri(CloudConfig.useAgents ? '/v1/analyze' : '/v1/explain'),
          headers: await _headers(),
          body: jsonEncode(explainBody(
            labelText: labelText,
            allergies: allergies,
            conditions: conditions,
            avoid: avoid,
          )),
        )
        .timeout(Duration(seconds: CloudConfig.useAgents ? 120 : 45))
        .catchError((_) => throw const CloudUnavailable('network'));
    if (response.statusCode != 200) {
      throw CloudUnavailable('status ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const CloudUnavailable('bad response');
    return decoded;
  }

  /// Searches the regulation corpus. Returns verbatim passages with their
  /// source; an empty list means no source was found.
  Future<List<RegulationHit>> search(String query) async {
    if (!CloudConfig.isConfigured) throw const CloudUnavailable('not configured');
    final response = await _http
        .post(
          _uri('/v1/search'),
          headers: await _headers(),
          body: jsonEncode({'query': query.trim()}),
        )
        .timeout(const Duration(seconds: 30))
        .catchError((_) => throw const CloudUnavailable('network'));
    if (response.statusCode != 200) {
      throw CloudUnavailable('status ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final results = decoded is Map<String, dynamic> ? decoded['results'] : null;
    if (results is! List) throw const CloudUnavailable('bad response');
    return results.whereType<Map>().map((r) {
      return RegulationHit(
        title: (r['title'] ?? '').toString(),
        locator: (r['locator'] ?? '').toString(),
        snippet: (r['snippet'] ?? '').toString(),
      );
    }).toList();
  }

  /// Cloud OCR for labels the on-device reader cannot read. Sends the image.
  Future<String> ocrFallback(Uint8List imageBytes) async {
    if (!CloudConfig.isConfigured) throw const CloudUnavailable('not configured');
    final response = await _http
        .post(
          _uri('/v1/ocr-fallback'),
          headers: await _headers(contentType: 'application/octet-stream'),
          body: imageBytes,
        )
        .timeout(const Duration(seconds: 45))
        .catchError((_) => throw const CloudUnavailable('network'));
    if (response.statusCode != 200) {
      throw CloudUnavailable('status ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final text = decoded is Map<String, dynamic> ? decoded['text'] : null;
    if (text is! String) throw const CloudUnavailable('bad response');
    return text;
  }

  /// Asks the backend to acknowledge a deletion request. Returns true when it did.
  Future<bool> deleteMyData() async {
    if (!CloudConfig.isConfigured) return false;
    try {
      final response = await _http
          .delete(_uri('/v1/me'), headers: await _headers())
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
