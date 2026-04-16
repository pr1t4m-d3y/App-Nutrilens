import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  String _currentUserId = '';
  String get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentUserId.isNotEmpty;

  /// Returns true if the user is the demo user with pre-built history
  bool get isDemoUser => _currentUserId == 'User123';

  /// Returns true if the user is the admin/new user with no data
  bool get isNewUser => _currentUserId == 'Admin123';

  void login(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  void logout() {
    _currentUserId = '';
    notifyListeners();
  }
}
