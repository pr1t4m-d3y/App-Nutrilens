import 'package:firebase_core/firebase_core.dart';

/// Build-time configuration, supplied with `--dart-define-from-file=app_config.json`
/// (see `app_config.example.json`).
///
/// None of these values is a secret. The Firebase API key identifies the
/// project and is restricted in the Google Cloud console, and the API URL is
/// public. Model API keys do not exist in the app at all: model calls go
/// through the backend, which authenticates the request with a Firebase ID token.
class CloudConfig {
  static const String apiBaseUrl = String.fromEnvironment('NUTRILENS_API_URL');
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  /// True when cloud explanations can be requested. When false the app runs
  /// entirely on-device.
  static bool get isConfigured => apiBaseUrl.isNotEmpty && firebaseConfigured;

  static FirebaseOptions get firebaseOptions => const FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseSenderId,
        projectId: firebaseProjectId,
      );
}
