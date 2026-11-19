import '../providers/scan_history_provider.dart';
import '../providers/user_profile_provider.dart';
import 'auth_token_service.dart';
import 'cloud_client.dart';
import 'consent_service.dart';

/// What a delete-everything request achieved, so the UI can say so accurately.
class DeletionResult {
  final bool serverAcknowledged;
  final bool identityDeleted;
  const DeletionResult({required this.serverAcknowledged, required this.identityDeleted});
}

/// Removes the user's data: the stored profile, scan history, consent choice,
/// the anonymous cloud identity, and asks the backend to acknowledge deletion.
/// Local data is always deleted, even when the network calls fail.
class PrivacyService {
  final CloudClient _cloud;
  final AuthTokenService _auth;
  final ConsentService _consent;

  PrivacyService({CloudClient? cloud, AuthTokenService? auth, ConsentService? consent})
      : _cloud = cloud ?? CloudClient(),
        _auth = auth ?? AuthTokenService(),
        _consent = consent ?? ConsentService();

  Future<DeletionResult> deleteEverything({
    required UserProfileProvider profile,
    required ScanHistoryProvider history,
  }) async {
    // Server first: it needs the identity that is deleted next.
    final acknowledged = await _cloud.deleteMyData();
    final identityDeleted = await _auth.deleteIdentity();

    await profile.deleteEverything();
    history.clearHistory();
    await _consent.clear();

    return DeletionResult(serverAcknowledged: acknowledged, identityDeleted: identityDeleted);
  }
}
