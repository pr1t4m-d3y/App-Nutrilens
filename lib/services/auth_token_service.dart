import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'cloud_config.dart';

/// Gives each install a Firebase anonymous identity and returns its ID token
/// (a JWT) for the backend to verify. Returns null when cloud access is not
/// configured or sign-in fails, so callers fall back to on-device results.
class AuthTokenService {
  Future<String?> idToken() async {
    if (!CloudConfig.isConfigured) return null;
    try {
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      user ??= (await auth.signInAnonymously()).user;
      return await user?.getIdToken();
    } catch (e) {
      // Type only: exception text can include request details.
      debugPrint('[Auth] token unavailable: ${e.runtimeType}');
      return null;
    }
  }

  /// Deletes the anonymous Firebase identity. Returns true on success.
  Future<bool> deleteIdentity() async {
    if (!CloudConfig.firebaseConfigured) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true;
      await user.delete();
      return true;
    } catch (e) {
      debugPrint('[Auth] identity delete failed: ${e.runtimeType}');
      return false;
    }
  }
}
