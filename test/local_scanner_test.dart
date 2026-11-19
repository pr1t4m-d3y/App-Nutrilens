import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/services/local_scanner.dart';

void main() {
  final scanner = LocalScanner();

  test('flags a listed allergy using its pattern library', () {
    final threats = scanner.scanForThreats(
      ocrText: 'Ingredients: Roasted Peanuts, salt',
      userAllergies: ['Peanuts'],
      userConditions: [],
    );
    expect(threats, ['peanut']);
  });

  test('flags an allergy that has no library by plain substring', () {
    final threats = scanner.scanForThreats(
      ocrText: 'sesame oil, water',
      userAllergies: ['Sesame'],
      userConditions: [],
    );
    expect(threats, ['sesame']);
  });

  test('flags hidden sugars for diabetes with a real label, not a template string', () {
    final threats = scanner.scanForThreats(
      ocrText: 'water, maltodextrin',
      userAllergies: [],
      userConditions: ['Type 2 Diabetes'],
    );
    expect(threats, ['maltodextrin (High Glycemic)']);
  });

  test('flags the user avoid list', () {
    final threats = scanner.scanForThreats(
      ocrText: 'Palm Oil, sugar',
      userAllergies: [],
      userConditions: [],
      userAvoidList: ['Palm Oil'],
    );
    expect(threats, ['palm oil']);
  });

  test('returns nothing when nothing matches', () {
    final threats = scanner.scanForThreats(
      ocrText: 'water, salt',
      userAllergies: ['Peanuts'],
      userConditions: ['Hypertension'],
      userAvoidList: ['Palm Oil'],
    );
    expect(threats, isEmpty);
  });

  test('ignores blank profile entries', () {
    final threats = scanner.scanForThreats(
      ocrText: 'water, salt',
      userAllergies: ['  ', ''],
      userConditions: [],
      userAvoidList: [' '],
    );
    expect(threats, isEmpty);
  });

  test('allergenGroups lists the pattern libraries without the sugar library', () {
    expect(LocalScanner.allergenGroups, [
      'tree nuts',
      'peanuts',
      'lactose',
      'gluten',
      'soy',
      'shellfish',
      'eggs',
    ]);
  });
}
