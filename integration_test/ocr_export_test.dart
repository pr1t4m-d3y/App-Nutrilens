// Runs Google ML Kit text recognition, on a real device, over the label images
// used by the evals, and writes the recognised text to a JSON file that
// evals/report.py compares with the ground truth.
//
// 1. Push the labels to the app's external files directory:
//      adb push evals/labels /sdcard/Android/data/com.example.nutrilens/files/labels
// 2. Run on the connected device:
//      flutter test integration_test/ocr_export_test.dart -d <device id>
// 3. Pull the result:
//      adb pull /sdcard/Android/data/com.example.nutrilens/files/mlkit_ocr.json evals/results/raw/mlkit_ocr.json
//
// Each image `<id>.jpg` is matched to `<id>.json` by file name. `text` is the
// ingredient section after the app's own sanitiser, which is what the later
// pipeline stages receive; `raw` is the full recognised text.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nutrilens/services/ingredient_parser.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export ML Kit OCR text for the eval label images', (tester) async {
    final base = await getExternalStorageDirectory();
    expect(base, isNotNull, reason: 'external storage directory is not available on this device');

    final labels = Directory('${base!.path}/labels');
    expect(labels.existsSync(), isTrue, reason: 'push evals/labels to ${labels.path} first');

    final imagePattern = RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false);
    final files = labels
        .listSync()
        .whereType<File>()
        .where((f) => imagePattern.hasMatch(f.path))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'no images found in ${labels.path}');

    final recognizer = TextRecognizer();
    final out = <Map<String, String>>[];
    for (final file in files) {
      final recognised = await recognizer.processImage(InputImage.fromFilePath(file.path));
      final name = file.uri.pathSegments.last;
      out.add({
        'id': name.replaceAll(RegExp(r'\.[^.]+$'), ''),
        'raw': recognised.text,
        'text': IngredientParser.sanitize(recognised.text),
      });
    }
    await recognizer.close();

    File('${base.path}/mlkit_ocr.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  });
}
