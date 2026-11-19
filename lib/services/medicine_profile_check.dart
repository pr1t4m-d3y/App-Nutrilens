/// One on-device finding about a scanned medicine.
class MedicineAlert {
  /// `allergy`, `same_product` or `same_ingredient`.
  final String kind;
  final String message;
  const MedicineAlert(this.kind, this.message);

  Map<String, String> toMap() => {'kind': kind, 'message': message};
}

/// Resolves a medicine entry from the user's list (for example "Dolo 650") to
/// its active ingredient(s), or null if unknown.
typedef CompositionLookup = String? Function(String medicationEntry);

/// Offline checks of a scanned medicine against the user's own profile.
///
/// It only compares names and active ingredients. It does not know drug
/// interactions or allergy classes (an "amoxicillin" scan is not matched to a
/// "penicillin" allergy), so a missing alert never means a medicine is safe.
class MedicineProfileCheck {
  static const _minTokenLength = 4;

  // Words common to many compositions. Matching on them would create false alerts.
  static const _ignored = {
    'sodium', 'potassium', 'calcium', 'magnesium', 'hydrochloride', 'sulfate',
    'sulphate', 'maleate', 'tartrate', 'besylate', 'mesylate', 'phosphate',
    'acetate', 'citrate', 'succinate', 'fumarate', 'proxetil', 'tablet',
    'tablets', 'capsule', 'capsules', 'syrup', 'with', 'plus',
  };

  static String _norm(Object? value) => (value ?? '').toString().toLowerCase().trim();

  static Set<String> _tokens(String text) {
    return text
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= _minTokenLength && !_ignored.contains(t))
        .toSet();
  }

  static List<MedicineAlert> check({
    required Map<String, dynamic> scanned,
    required List<String> userMedications,
    required List<String> userAllergies,
    CompositionLookup? lookupComposition,
  }) {
    final brand = _norm(scanned['Brand_Name']);
    final composition = _norm(scanned['Composition']);
    final scannedTokens = _tokens(composition);
    final alerts = <MedicineAlert>[];

    for (final allergy in userAllergies) {
      final a = _norm(allergy);
      if (a.length < 3) continue;
      if (composition.contains(a) || brand.contains(a)) {
        alerts.add(MedicineAlert(
          'allergy',
          'This medicine matches an allergy on your profile: $allergy.',
        ));
      }
    }

    for (final entry in userMedications) {
      final m = _norm(entry);
      if (m.isEmpty) continue;

      if (brand.length >= _minTokenLength && m.contains(brand)) {
        alerts.add(MedicineAlert(
          'same_product',
          'This is the same product as "$entry", which is already on your medicine list.',
        ));
        continue;
      }

      final entryTokens = {
        ..._tokens(m),
        ..._tokens(_norm(lookupComposition?.call(entry))),
      };
      final shared = scannedTokens.where(entryTokens.contains).toList()..sort();
      if (shared.isNotEmpty) {
        alerts.add(MedicineAlert(
          'same_ingredient',
          'Contains ${shared.join(', ')}, which is also in "$entry" on your list. '
              'Check with your pharmacist or doctor before taking both.',
        ));
      }
    }
    return alerts;
  }
}
