import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/services/ingredient_parser.dart';

void main() {
  group('IngredientParser.sanitize', () {
    test('keeps the text after the ingredients marker and stops at an end marker', () {
      final out = IngredientParser.sanitize('Ingredients: Sugar, Salt\nManufactured by Example Foods');
      expect(out, 'Sugar, Salt');
    });

    test('joins separate lines with commas', () {
      expect(IngredientParser.sanitize('Ingredients: Sugar\nPalm Oil\nSalt'), 'Sugar, Palm Oil, Salt');
    });

    test('drops timestamps and lone quantities', () {
      expect(IngredientParser.sanitize('Ingredients: Sugar\n03:52\n250 g\nSalt'), 'Sugar, Salt');
    });

    test('uses the whole text when there is no marker', () {
      expect(IngredientParser.sanitize('Sugar\nSalt'), 'Sugar, Salt');
    });
  });

  group('IngredientParser.extract', () {
    test('splits on commas, semicolons and bullets', () {
      expect(
        IngredientParser.extract('Sugar, Palm Oil; Salt • Water'),
        ['Sugar', 'Palm Oil', 'Salt', 'Water'],
      );
    });

    test('drops one-character and very long items', () {
      final long = 'x' * 60;
      expect(IngredientParser.extract('a, Sugar, $long'), ['Sugar']);
    });

    test('keeps at most 25 items', () {
      final many = List.generate(30, (i) => 'item$i').join(', ');
      expect(IngredientParser.extract(many).length, 25);
    });
  });
}
