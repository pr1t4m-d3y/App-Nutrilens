import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum CloudConsent { undecided, granted, declined }

/// Remembers whether the user allowed cloud explanations. The on-device
/// checks never depend on this.
class ConsentService {
  static const _key = 'nutrilens.cloud_consent.v1';
  final FlutterSecureStorage _storage;

  ConsentService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<CloudConsent> read() async {
    try {
      switch (await _storage.read(key: _key)) {
        case 'granted':
          return CloudConsent.granted;
        case 'declined':
          return CloudConsent.declined;
        default:
          return CloudConsent.undecided;
      }
    } catch (e) {
      debugPrint('[Consent] read failed: ${e.runtimeType}');
      return CloudConsent.undecided;
    }
  }

  Future<void> write(CloudConsent value) async {
    try {
      if (value == CloudConsent.undecided) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: value.name);
      }
    } catch (e) {
      debugPrint('[Consent] write failed: ${e.runtimeType}');
    }
  }

  Future<void> clear() => write(CloudConsent.undecided);
}
