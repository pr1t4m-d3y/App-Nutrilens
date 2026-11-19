import 'dart:async';

import 'package:flutter/material.dart';

import '../services/profile_store.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider({ProfileStorage? storage}) : _storage = storage ?? SecureProfileStorage();

  final ProfileStorage _storage;

  // Changes are saved only after [attachStorage] ran. Signing out clears
  // memory and stops saving, but leaves the stored profile alone.
  bool _persistEnabled = false;
  bool _restoring = false;

  String name = '';
  double bmi = 0;
  double heightCm = 0;
  double weightKg = 0;
  int age = 0;

  List<String> goals = [];
  List<String> conditions = [];
  List<String> allergies = [];
  List<String> skinSensitivities = [];
  List<String> medications = [];
  List<String> manualAvoidList = [];

  /// Restores the stored profile (if any) and saves every later change to
  /// encrypted device storage.
  Future<void> attachStorage() async {
    _restoring = true;
    try {
      final data = await _storage.read();
      if (data != null) _applyMap(data);
    } finally {
      _restoring = false;
    }
    _persistEnabled = true;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_persistEnabled && !_restoring) {
      unawaited(_storage.write(toStorageMap()));
    }
  }

  void updateBmi(double newBmi) {
    bmi = newBmi;
    notifyListeners();
  }

  void updatePhysical({required double heightCm, required double weightKg, required int age}) {
    this.heightCm = heightCm;
    this.weightKg = weightKg;
    if (age > 0) this.age = age;
    notifyListeners();
  }

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }

  void addAvoidIngredient(String ingredient) {
    if (!manualAvoidList.contains(ingredient)) {
      manualAvoidList.add(ingredient);
      notifyListeners();
    }
  }

  void removeAvoidIngredient(String ingredient) {
    if (manualAvoidList.remove(ingredient)) {
      notifyListeners();
    }
  }

  bool get isProfileComplete => name.isNotEmpty && heightCm > 0 && weightKg > 0;

  /// Everything the profile holds, for the on-device checks. The cloud request
  /// sends only allergies, conditions and the avoid list (see `CloudClient`).
  Map<String, dynamic> toMetadataMap() {
    return {
      'bmi': bmi,
      'goals': goals,
      'conditions': conditions,
      'allergies': allergies,
      'skinSensitivities': skinSensitivities,
      'medications': medications,
      'avoidList': manualAvoidList,
    };
  }

  Map<String, dynamic> toStorageMap() => {
        'name': name,
        'bmi': bmi,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'age': age,
        'goals': goals,
        'conditions': conditions,
        'allergies': allergies,
        'skinSensitivities': skinSensitivities,
        'medications': medications,
        'manualAvoidList': manualAvoidList,
      };

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : <String>[];

  static double _number(Object? value) => value is num ? value.toDouble() : 0;

  void _applyMap(Map<String, dynamic> m) {
    name = m['name'] is String ? m['name'] as String : '';
    bmi = _number(m['bmi']);
    heightCm = _number(m['heightCm']);
    weightKg = _number(m['weightKg']);
    age = _number(m['age']).toInt();
    goals = _strings(m['goals']);
    conditions = _strings(m['conditions']);
    allergies = _strings(m['allergies']);
    skinSensitivities = _strings(m['skinSensitivities']);
    medications = _strings(m['medications']);
    manualAvoidList = _strings(m['manualAvoidList']);
  }

  void _reset() {
    name = '';
    bmi = 0;
    heightCm = 0;
    weightKg = 0;
    age = 0;
    goals = [];
    conditions = [];
    allergies = [];
    skinSensitivities = [];
    medications = [];
    manualAvoidList = [];
  }

  /// Clears the in-memory profile (sign out). The stored profile is kept so
  /// the next sign-in restores it; use [deleteEverything] to remove it.
  void clearAll() {
    _persistEnabled = false;
    _reset();
    notifyListeners();
  }

  /// Clears memory and deletes the stored profile from the device.
  Future<void> deleteEverything() async {
    _persistEnabled = false;
    _reset();
    await _storage.wipe();
    notifyListeners();
  }
}
