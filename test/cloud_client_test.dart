import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/services/cloud_client.dart';

void main() {
  test('request body carries only label text and three profile lists', () {
    final body = CloudClient.explainBody(
      labelText: 'Ingredients: sugar',
      allergies: [' Peanuts '],
      conditions: ['Diabetes'],
      avoid: ['Palm Oil'],
    );
    expect(body.keys.toList(), ['label_text', 'profile']);
    final profile = body['profile'] as Map<String, dynamic>;
    expect(profile.keys.toList(), ['allergies', 'conditions', 'avoid']);
    expect(profile['allergies'], ['Peanuts']);
  });

  test('request body never contains name, age, weight or medicines', () {
    final encoded = jsonEncode(CloudClient.explainBody(
      labelText: 'Ingredients: sugar',
      allergies: ['Peanuts'],
      conditions: [],
      avoid: [],
    ));
    for (final field in ['name', 'age', 'weight', 'bmi', 'medications']) {
      expect(encoded.contains('"$field"'), isFalse, reason: field);
    }
  });

  test('flags trims blanks, caps item length and count', () {
    final result = CloudClient.flags(['  ', 'a' * 100, ...List.generate(30, (i) => 'x$i')]);
    expect(result.length, 20);
    expect(result.first.length, 60);
  });

  test('without build configuration the client refuses instead of calling out', () async {
    final client = CloudClient();
    expect(
      () => client.explain(labelText: 'Ingredients: sugar', allergies: [], conditions: [], avoid: []),
      throwsA(isA<CloudUnavailable>()),
    );
    expect(await client.deleteMyData(), isFalse);
  });
}
