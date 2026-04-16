import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class NutriNLUService {
  static final NutriNLUService _instance = NutriNLUService._internal();
  factory NutriNLUService() => _instance;
  NutriNLUService._internal();

  Interpreter? _interpreter;
  Map<String, int> _wordIndex = {};
  Map<int, String> _labelMap = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/nlp/chatbot_model.tflite');
      final wordIndexString = await rootBundle.loadString('assets/nlp/word_index.json');
      _wordIndex = Map<String, int>.from(json.decode(wordIndexString));
      
      final labelMapString = await rootBundle.loadString('assets/nlp/label_map.json');
      final tempLabelMap = Map<String, dynamic>.from(json.decode(labelMapString));
      _labelMap = tempLabelMap.map((key, value) => MapEntry(int.parse(key), value as String));
      _isInitialized = true;
    } catch (e) {
      throw Exception('Init error: $e');
    }
  }

  Future<String> predictIntent(String text) async {
    if (!_isInitialized || _interpreter == null) await initialize();
    
    final tokens = _tokenize(text);
    final paddedTokens = _padSequence(tokens, 20);
    
    dynamic input;
    final tensorType = _interpreter!.getInputTensor(0).type;
    
    if (tensorType == TensorType.float32) {
      input = [paddedTokens.map((e) => e.toDouble()).toList()];
    } else {
      input = [paddedTokens];
    }
    
    final labelCount = _labelMap.length;
    var output = List.filled(1 * labelCount, 0.0).reshape([1, labelCount]);
    
    try {
      _interpreter!.run(input, output);
    } catch (e) {
      return "unknown";
    }
    
    final outputRow = output[0] as List<double>;
    
    double maxVal = -1.0;
    int maxIdx = -1;
    for (int i = 0; i < outputRow.length; i++) {
      if (outputRow[i] > maxVal) {
        maxVal = outputRow[i];
        maxIdx = i;
      }
    }
    
    return _labelMap[maxIdx] ?? "unknown";
  }

  List<int> _tokenize(String text) {
    text = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    List<String> words = text.split(RegExp(r'\s+'));
    return words.map((w) => _wordIndex[w] ?? _wordIndex['<OOV>'] ?? 1).toList();
  }

  List<int> _padSequence(List<int> sequence, int maxLen) {
    if (sequence.length >= maxLen) {
      return sequence.sublist(sequence.length - maxLen);
    }
    List<int> padded = List.filled(maxLen - sequence.length, 0, growable: true);
    padded.addAll(sequence);
    return padded;
  }
}
