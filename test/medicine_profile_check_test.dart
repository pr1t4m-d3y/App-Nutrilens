import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/services/medicine_profile_check.dart';

void main() {
  String? lookup(String entry) => entry == 'Dolo 650' ? 'Paracetamol' : null;

  test('flags the same active ingredient as a medicine on the list', () {
    final alerts = MedicineProfileCheck.check(
      scanned: {'Brand_Name': 'Crocin 500', 'Composition': 'Paracetamol'},
      userMedications: ['Dolo 650'],
      userAllergies: [],
      lookupComposition: lookup,
    );
    expect(alerts.length, 1);
    expect(alerts.first.kind, 'same_ingredient');
    expect(alerts.first.message, contains('paracetamol'));
    expect(alerts.first.message, contains('Dolo 650'));
  });

  test('flags the same product already on the list', () {
    final alerts = MedicineProfileCheck.check(
      scanned: {'Brand_Name': 'Dolo 650', 'Composition': 'Paracetamol'},
      userMedications: ['Dolo 650 tablet'],
      userAllergies: [],
    );
    expect(alerts.map((a) => a.kind), ['same_product']);
  });

  test('flags a composition that matches a listed allergy', () {
    final alerts = MedicineProfileCheck.check(
      scanned: {'Brand_Name': 'Mox 500', 'Composition': 'Amoxicillin'},
      userMedications: [],
      userAllergies: ['Amoxicillin'],
    );
    expect(alerts.map((a) => a.kind), ['allergy']);
  });

  test('does not infer allergy classes (documented limit)', () {
    final alerts = MedicineProfileCheck.check(
      scanned: {'Brand_Name': 'Mox 500', 'Composition': 'Amoxicillin'},
      userMedications: [],
      userAllergies: ['Penicillin'],
    );
    expect(alerts, isEmpty);
  });

  test('ignores generic salt words so unrelated medicines do not match', () {
    final alerts = MedicineProfileCheck.check(
      scanned: {'Brand_Name': 'Voveran', 'Composition': 'Diclofenac Sodium'},
      userMedications: ['Valparin'],
      userAllergies: [],
      lookupComposition: (_) => 'Valproate Sodium',
    );
    expect(alerts, isEmpty);
  });

  test('returns nothing for an empty profile', () {
    final alerts = MedicineProfileCheck.check(
      scanned: {'Brand_Name': 'Crocin 500', 'Composition': 'Paracetamol'},
      userMedications: [],
      userAllergies: [],
    );
    expect(alerts, isEmpty);
  });
}
