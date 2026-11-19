import 'package:flutter/material.dart';

import '../services/consent_service.dart';

/// Asks the user whether cloud explanations may be requested, and records the
/// answer. Returns true if allowed.
Future<bool> askCloudConsent(BuildContext context, {ConsentService? service}) async {
  final consent = service ?? ConsentService();
  final allowed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Cloud explanations'),
      content: const SingleChildScrollView(
        child: Text(
          'NutriLens can ask a cloud service to explain flagged ingredients '
          'using published food regulations.\n\n'
          'Sent: the ingredient text from the label, the allergy, condition '
          'and avoid-list entries from your profile, and the text you type '
          'into Regulation search.\n\n'
          'Not sent: your name, age, weight, medicines or the photo (a photo '
          'is sent only if you choose cloud reading for one scan).\n\n'
          'Allergen, avoid-list and medicine checks always run on your phone '
          'and work without this. You can change your choice any time in '
          'Account > Privacy.\n\n'
          'Information only, not medical advice.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
      ],
    ),
  );
  final granted = allowed == true;
  await consent.write(granted ? CloudConsent.granted : CloudConsent.declined);
  return granted;
}

/// Returns true if cloud explanations may be requested now, asking the user
/// first when no choice has been recorded.
Future<bool> ensureCloudConsent(BuildContext context, {ConsentService? service}) async {
  final consent = service ?? ConsentService();
  switch (await consent.read()) {
    case CloudConsent.granted:
      return true;
    case CloudConsent.declined:
      return false;
    case CloudConsent.undecided:
      if (!context.mounted) return false;
      return askCloudConsent(context, service: consent);
  }
}

/// Plain-language summary of what the app stores and sends.
Future<void> showPrivacySummary(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('What is stored and sent'),
      content: const SingleChildScrollView(
        child: Text(
          'Stored on this phone: your health profile, encrypted with the '
          'device keystore. Scan history is kept in memory only and is cleared '
          'when the app closes.\n\n'
          'Sent to the cloud, only if you allow it: the ingredient text of a '
          'label, and the allergy, condition and avoid-list entries from your '
          'profile; the text you type into Regulation search; and a photo '
          'only when you choose cloud reading for that one scan.\n\n'
          'Never sent: your name, age, weight or medicines.\n\n'
          'The service is designed to keep no personal data. Its logs hold '
          'only a short hash of an anonymous id with counts and timings.\n\n'
          'Delete everything any time from Account > Settings > Delete all my data.',
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}
