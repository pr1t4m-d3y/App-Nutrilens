/// Pure-Dart helpers that turn raw OCR text into an ingredient list.
/// They have no Flutter dependencies so they can be unit tested and used by
/// the evaluation harness.
class IngredientParser {
  static const _startMarkers = [
    'ingredients:', 'ingredient:', 'ingredients list:',
    'contains:', 'composition:', 'ingr:',
  ];

  static const _endMarkers = [
    'manufactured', 'packed by', 'packaging by', 'best before',
    'mrp', 'net weight', 'distributed', 'marketed by',
    'fssai', 'batch', 'mfg', 'expiry', 'customer care',
  ];

  /// Isolates the ingredient section from a raw OCR dump and drops noise lines.
  static String sanitize(String raw) {
    final lower = raw.toLowerCase();

    // 1. Find the start of the ingredients section.
    int startIdx = -1;
    for (final marker in _startMarkers) {
      final idx = lower.indexOf(marker);
      if (idx != -1) {
        startIdx = idx + marker.length;
        break;
      }
    }

    // If no marker is found, use the full text but still filter noise.
    final workingText = startIdx != -1 ? raw.substring(startIdx) : raw;

    // 2. Truncate at known end-of-ingredient markers.
    final trimmed = workingText.toLowerCase();
    int endIdx = workingText.length;
    for (final end in _endMarkers) {
      final idx = trimmed.indexOf(end);
      if (idx != -1 && idx < endIdx) endIdx = idx;
    }

    // 3. Filter out noise lines.
    final lines = workingText.substring(0, endIdx).split(RegExp(r'[\n\r]'));
    final cleaned = lines.where((line) {
      final t = line.trim();
      if (t.length < 2) return false; // empty or 1-char junk
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(t)) return false; // timestamps like 03:52
      if (RegExp(r'^\d+\.?\d*\s*(g|mg|ml|kg|%)?\s*$').hasMatch(t)) return false; // lone numbers
      return true;
    }).join(', ');

    return cleaned.trim();
  }

  /// Splits sanitised text into at most 25 ingredient names.
  static List<String> extract(String cleanText) {
    return cleanText
        .split(RegExp(r'[,\n•·;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 1 && s.length < 60)
        .take(25)
        .toList();
  }
}
