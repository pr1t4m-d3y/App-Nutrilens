import 'package:flutter/material.dart';

class UserProfileProvider extends ChangeNotifier {
  String userId = '';
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

  /// Load pre-built demo data for "User123"
  void loadDemoData() {
    userId = 'User123';
    name = 'User123';
    bmi = 24.2;
    heightCm = 175;
    weightKg = 74;
    age = 28;
    goals = ['Weight Management', 'Heart Health'];
    conditions = ['Mild Hypertension'];
    allergies = ['Peanuts', 'Shellfish'];
    skinSensitivities = ['Paraben', 'SLS'];
    medications = ['Amlodipine 5mg'];
    manualAvoidList = ['Palm Oil', 'High Fructose Corn Syrup'];
    notifyListeners();
  }

  /// Reset everything for a brand new user
  void clearAll() {
    userId = '';
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
    notifyListeners();
  }
}
