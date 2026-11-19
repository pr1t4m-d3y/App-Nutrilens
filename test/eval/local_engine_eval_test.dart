// Evaluation runner for the on-device engine. It is not a pass/fail test of
// behaviour: it measures the ingredient parser and the allergen pattern
// libraries against human-reviewed ground truth in evals/labels/ and writes
// raw counts to evals/results/raw/local_engine.json. evals/report.py turns
// those counts into RESULTS.md. With no labels it measures nothing and says so.
//
// Run from the project root:  flutter test test/eval

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/services/ingredient_parser.dart';
import 'package:nutrilens/services/local_scanner.dart';

String _norm(String s) => s.toLowerCase().trim();

void main() {
  test('measure on-device engine against reviewed labels', () {
    final dir = Directory('evals/labels');
    final files = dir.existsSync()
        ? (dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];

    if (files.isEmpty) {
      markTestSkipped('No labels in evals/labels. See evals/LABEL_CHECKLIST.md.');
      return;
    }

    final scanner = LocalScanner();
    final groups = LocalScanner.allergenGroups;

    var unreviewed = 0;
    var labelCount = 0;
    var parserTp = 0, parserFp = 0, parserFn = 0, parserExact = 0;
    final counts = {for (final g in groups) g: {'tp': 0, 'fp': 0, 'fn': 0, 'tn': 0}};
    final falseNegatives = <Map<String, String>>[];
    final falsePositives = <Map<String, String>>[];

    for (final file in files) {
      final label = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final reviewer = (label['reviewed_by'] ?? '').toString().trim();
      if (reviewer.isEmpty) {
        unreviewed++;
        continue;
      }
      labelCount++;
      final id = (label['id'] ?? file.uri.pathSegments.last).toString();
      final text = (label['ingredients_text'] ?? '').toString();

      // Ingredient parsing, given perfect text.
      final truth = (label['ingredients'] as List).map((e) => _norm(e.toString())).toList();
      final predicted = IngredientParser.extract(IngredientParser.sanitize(text)).map(_norm).toList();
      final truthSet = truth.toSet();
      final predictedSet = predicted.toSet();
      parserTp += truthSet.intersection(predictedSet).length;
      parserFp += predictedSet.difference(truthSet).length;
      parserFn += truthSet.difference(predictedSet).length;
      if (truth.length == predicted.length &&
          List.generate(truth.length, (i) => truth[i] == predicted[i]).every((x) => x)) {
        parserExact++;
      }

      // Allergen detection, one group at a time.
      final present = (label['allergen_groups'] as List).map((e) => e.toString()).toSet();
      for (final group in groups) {
        final threats = scanner.scanForThreats(
          ocrText: text,
          userAllergies: [group],
          userConditions: const [],
        );
        final detected = threats.isNotEmpty;
        final actual = present.contains(group);
        final c = counts[group]!;
        if (detected && actual) {
          c['tp'] = c['tp']! + 1;
        } else if (detected && !actual) {
          c['fp'] = c['fp']! + 1;
          falsePositives.add({'id': id, 'group': group, 'matched': threats.join(', ')});
        } else if (!detected && actual) {
          c['fn'] = c['fn']! + 1;
          falseNegatives.add({'id': id, 'group': group});
        } else {
          c['tn'] = c['tn']! + 1;
        }
      }
    }

    final out = {
      'n_labels': labelCount,
      'n_unreviewed_skipped': unreviewed,
      'parser': {
        'tp': parserTp,
        'fp': parserFp,
        'fn': parserFn,
        'labels_exact_match': parserExact,
      },
      'groups': counts,
      'false_negatives': falseNegatives,
      'false_positives': falsePositives,
    };

    final outFile = File('evals/results/raw/local_engine.json');
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  });
}
