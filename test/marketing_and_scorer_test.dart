import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/services/indian_weighted_scorer.dart';
import 'package:nutrilens/services/marketing_checker.dart';

void main() {
  group('MarketingChecker', () {
    final checker = MarketingChecker();

    test('reports a claim that the ingredients contradict, with real values', () {
      final warning = checker.realityCheck('No Added Sugar', ['Water', 'Maltodextrin']);
      expect(warning, 'Marketing says "no added sugar", but contains maltodextrin.');
    });

    test('returns null when the claim holds or nothing is claimed', () {
      expect(checker.realityCheck('Tasty snack', ['Water', 'Salt']), isNull);
      expect(checker.realityCheck('No Added Sugar', ['Water', 'Salt']), isNull);
      expect(checker.realityCheck('', ['Water']), isNull);
      expect(checker.realityCheck('No Added Sugar', []), isNull);
    });
  });

  group('IndianWeightedScorer', () {
    final scorer = IndianWeightedScorer();

    test('empty list scores 10', () {
      expect(scorer.calculateFssaiScore([]), 10.0);
    });

    test('no harmful ingredients scores 10', () {
      expect(scorer.calculateFssaiScore(['Water', 'Salt']), 10.0);
    });

    test('a harmful first ingredient is penalised 3x', () {
      // sugar weight 2.0, position multiplier 3.0 -> 10 - 6 = 4
      expect(scorer.calculateFssaiScore(['Sugar', 'Water', 'Salt']), closeTo(4.0, 1e-9));
    });

    test('a harmful last ingredient is penalised 1x', () {
      // palm oil weight 1.8 at index 5 of 6 (bottom half, multiplier 1.0) -> 8.2
      final score = scorer.calculateFssaiScore(['A', 'B', 'C', 'D', 'E', 'Palm Oil']);
      expect(score, closeTo(8.2, 1e-9));
    });

    test('the score never drops below 1', () {
      final score = scorer.calculateFssaiScore(['Sugar', 'Corn Syrup', 'Hydrogenated Fat']);
      expect(score, 1.0);
    });
  });
}
