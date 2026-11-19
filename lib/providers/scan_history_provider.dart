import 'package:flutter/material.dart';

class ScanHistoryProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _scans = [];

  List<Map<String, dynamic>> get scans => List.unmodifiable(_scans);
  
  Map<String, dynamic>? get latestScan => _scans.isNotEmpty ? _scans.first : null;

  void addScan(Map<String, dynamic> scanResult) {
    // Add timestamp
    final entry = Map<String, dynamic>.from(scanResult);
    entry['timestamp'] = DateTime.now().toIso8601String();
    
    // Insert at beginning (newest first)
    _scans.insert(0, entry);
    
    // Keep max 50 scans
    if (_scans.length > 50) {
      _scans.removeLast();
    }
    
    notifyListeners();
  }

  void clearHistory() {
    _scans.clear();
    notifyListeners();
  }
}
