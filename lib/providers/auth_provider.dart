import 'package:flutter/material.dart';

/// Whether the app has been entered. There are no accounts: the profile is
/// stored on the device, and the cloud API uses an anonymous Firebase identity.
class AuthProvider extends ChangeNotifier {
  String _currentUserId = '';
  String get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentUserId.isNotEmpty;

  void login(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  void logout() {
    _currentUserId = '';
    notifyListeners();
  }
}
