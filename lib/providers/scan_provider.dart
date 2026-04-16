import 'package:flutter/material.dart';

enum ScanState { idle, scanningLocal, scanningCloud, complete, error }
enum ScanType { food, medicine }

class ScanProvider extends ChangeNotifier {
  ScanState _state = ScanState.idle;
  ScanState get state => _state;

  ScanType _scanType = ScanType.food;
  ScanType get scanType => _scanType;

  String _ocrText = '';
  String get ocrText => _ocrText;

  String? _imagePath;
  String? get imagePath => _imagePath;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isEmergencyMatch = false;
  bool get isEmergencyMatch => _isEmergencyMatch;

  bool _isFromHistory = false;
  bool get isFromHistory => _isFromHistory;

  List<String> _localThreats = [];
  List<String> get localThreats => _localThreats;

  Map<String, dynamic>? _results;
  Map<String, dynamic>? get results => _results;

  // Called after capture — stores both OCR text AND the image path
  void startScan(String ocrText, {String? imagePath, ScanType type = ScanType.food}) {
    _ocrText = ocrText;
    _imagePath = imagePath;
    _scanType = type;
    _state = ScanState.scanningLocal;
    _isEmergencyMatch = false;
    _isFromHistory = false;
    _localThreats = [];
    _errorMessage = null;
    _results = null;
    notifyListeners();
  }

  void setLocalThreats(List<String> threats) {
    _localThreats = threats;
    _isEmergencyMatch = threats.isNotEmpty;
    notifyListeners();
  }

  void setCloudScanning() {
    _state = ScanState.scanningCloud;
    notifyListeners();
  }

  void completeScan(Map<String, dynamic> data) {
    _results = data;
    _state = ScanState.complete;
    notifyListeners();
  }

  /// Load a past scan result for viewing (no history duplication).
  void viewFromHistory(Map<String, dynamic> data, {ScanType type = ScanType.food}) {
    _results = data;
    _scanType = type;
    _state = ScanState.complete;
    _isFromHistory = true;
    _isEmergencyMatch = false;
    _localThreats = [];
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    _state = ScanState.error;
    notifyListeners();
  }

  void reset() {
    _state = ScanState.idle;
    _ocrText = '';
    _imagePath = null;
    _scanType = ScanType.food;
    _isEmergencyMatch = false;
    _isFromHistory = false;
    _localThreats = [];
    _errorMessage = null;
    _results = null;
    notifyListeners();
  }
}
