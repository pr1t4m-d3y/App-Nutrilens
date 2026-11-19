import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/services/additive_table.dart';

final _json = jsonEncode([
  {
    'e_number': 'E999',
    'name': 'Test additive',
    'synonyms': ['testadd'],
    'category': 'test category',
    'allergen_tags': ['sulphites'],
    'limits_note': 'test note',
    'citation': 'Test Regulation, Annex II',
  },
  {
    'e_number': 'E998a',
    'name': 'Other additive',
    'synonyms': [],
    'category': 'test category',
    'allergen_tags': [],
    'limits_note': 'test note',
    'citation': 'Test Regulation, Annex III',
  },
]);

void main() {
  final table = AdditiveTable.fromJsonString(_json);

  test('finds an additive by E-number', () {
    final found = table.scan('Ingredients: water, preservative (E999)');
    expect(found.map((f) => f.entry.eNumber), ['E999']);
  });

  test('finds an additive by INS code with a space and lower case', () {
    final found = table.scan('ingredients: water, ins 999');
    expect(found.map((f) => f.entry.eNumber), ['E999']);
  });

  test('keeps the sub-letter in the code', () {
    expect(table.scan('contains E998a').map((f) => f.entry.eNumber), ['E998a']);
    expect(table.scan('contains E998').isEmpty, isTrue);
  });

  test('finds an additive by name or synonym as a whole word', () {
    expect(table.scan('water, Test Additive, salt').map((f) => f.entry.eNumber), ['E999']);
    expect(table.scan('water, testadd').map((f) => f.entry.eNumber), ['E999']);
    expect(table.scan('water, testaddition').isEmpty, isTrue);
  });

  test('returns one finding per additive', () {
    expect(table.scan('E999, INS 999, test additive').length, 1);
  });

  test('matches allergen tags against the user allergies', () {
    final found = table.scan('E999 and E998a');
    final matches = AdditiveTable.allergenMatches(found, ['Sulphites']);
    expect(matches.map((f) => f.entry.eNumber), ['E999']);
    expect(AdditiveTable.allergenMatches(found, ['Peanuts']), isEmpty);
  });

  test('an empty table never finds anything', () {
    expect(const AdditiveTable([]).scan('E999'), isEmpty);
  });

  test('a malformed asset yields an empty table', () {
    expect(AdditiveTable.fromJsonString('{"not": "a list"}').entries, isEmpty);
  });

  test('the citation is carried through for display', () {
    expect(table.scan('E999').first.entry.citation, 'Test Regulation, Annex II');
  });
}
