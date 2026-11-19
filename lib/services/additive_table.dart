import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One additive from the structured table, with the regulation citation that
/// supports it. The table is exported from `data/additives.csv`, the same
/// file the cloud service loads, so phone and cloud agree.
class AdditiveEntry {
  final String eNumber;
  final String name;
  final List<String> synonyms;
  final String category;
  final List<String> allergenTags;
  final String limitsNote;
  final String citation;

  const AdditiveEntry({
    required this.eNumber,
    required this.name,
    required this.synonyms,
    required this.category,
    required this.allergenTags,
    required this.limitsNote,
    required this.citation,
  });

  factory AdditiveEntry.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => v is List ? v.whereType<String>().toList() : <String>[];
    return AdditiveEntry(
      eNumber: (json['e_number'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      synonyms: strings(json['synonyms']),
      category: (json['category'] ?? '').toString(),
      allergenTags: strings(json['allergen_tags']),
      limitsNote: (json['limits_note'] ?? '').toString(),
      citation: (json['citation'] ?? '').toString(),
    );
  }
}

/// An additive found in label text, with the text that matched.
class AdditiveFinding {
  final AdditiveEntry entry;
  final String matchedText;
  const AdditiveFinding(this.entry, this.matchedText);
}

/// Offline additive lookup against the exported table.
class AdditiveTable {
  static const assetPath = 'assets/additives/additives.json';

  // Same pattern as the backend: "E211" and "INS 211" both normalise to "E211".
  static final RegExp _code = RegExp(r'\b(?:E|INS)[\s-]?(\d{3,4})([a-i]?)\b', caseSensitive: false);
  static const int _minNameLength = 4;

  final List<AdditiveEntry> entries;
  const AdditiveTable(this.entries);

  factory AdditiveTable.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const AdditiveTable([]);
    return AdditiveTable(
      decoded.whereType<Map>().map((m) => AdditiveEntry.fromJson(Map<String, dynamic>.from(m))).toList(),
    );
  }

  /// Loads the exported asset. If it has not been exported yet the table is
  /// empty and no additive finding is ever produced.
  static Future<AdditiveTable> loadAsset() async {
    try {
      return AdditiveTable.fromJsonString(await rootBundle.loadString(assetPath));
    } catch (e) {
      debugPrint('[Additives] table not loaded: ${e.runtimeType}');
      return const AdditiveTable([]);
    }
  }

  static String normaliseCode(String digits, String letter) => 'E$digits${letter.toLowerCase()}';

  /// Additives mentioned in [labelText], by E-number or INS code first, then
  /// by name or synonym as a whole word. One finding per additive.
  List<AdditiveFinding> scan(String labelText) {
    if (entries.isEmpty) return const [];
    final lower = labelText.toLowerCase();

    final codes = <String>{
      for (final m in _code.allMatches(labelText)) normaliseCode(m.group(1)!, m.group(2) ?? ''),
    };
    final findings = <AdditiveFinding>[];
    for (final entry in entries) {
      if (codes.contains(entry.eNumber)) {
        findings.add(AdditiveFinding(entry, entry.eNumber));
        continue;
      }
      for (final name in [entry.name, ...entry.synonyms]) {
        final n = name.toLowerCase().trim();
        if (n.length < _minNameLength) continue;
        if (RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(lower)) {
          findings.add(AdditiveFinding(entry, name));
          break;
        }
      }
    }
    return findings;
  }

  /// Findings whose allergen tags match one of the user's allergies.
  static List<AdditiveFinding> allergenMatches(
    List<AdditiveFinding> findings,
    List<String> userAllergies,
  ) {
    final allergies = userAllergies.map((a) => a.toLowerCase().trim()).where((a) => a.isNotEmpty).toSet();
    return findings
        .where((f) => f.entry.allergenTags.any((t) => allergies.contains(t.toLowerCase().trim())))
        .toList();
  }
}
