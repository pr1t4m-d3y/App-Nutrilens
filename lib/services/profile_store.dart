import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the health profile is kept on the device.
abstract class ProfileStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
  Future<void> wipe();
}

/// Stores the profile in the platform keystore (Android Keystore-backed
/// encrypted storage, iOS Keychain) as one JSON string.
class SecureProfileStorage implements ProfileStorage {
  static const _key = 'nutrilens.profile.v1';
  final FlutterSecureStorage _storage;

  SecureProfileStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('[Profile] read failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(data));
    } catch (e) {
      debugPrint('[Profile] write failed: ${e.runtimeType}');
    }
  }

  @override
  Future<void> wipe() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('[Profile] wipe failed: ${e.runtimeType}');
    }
  }
}
