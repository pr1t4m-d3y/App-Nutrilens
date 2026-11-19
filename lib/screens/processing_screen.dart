import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/cloud_client.dart';
import '../services/cloud_config.dart';
import '../services/indian_weighted_scorer.dart';
import '../services/ingredient_parser.dart';
import '../services/local_scanner.dart';
import '../services/marketing_checker.dart';
import '../widgets/cloud_consent_dialog.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  String _statusText = 'Analyzing Ingredients...';
  String _subText = 'Running local safety checks';
  bool _isEmergency = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _executeScanPipeline());
  }

  Future<void> _executeScanPipeline() async {
    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final ocrText = scanProvider.ocrText;

    if (ocrText.isEmpty) {
      scanProvider.setError('No text captured from camera. Please point at a food label and try again.');
      if (mounted) context.go('/home');
      return;
    }

    // Basic sanity check: must have enough characters to be a real food label
    if (ocrText.trim().length < 20) {
      scanProvider.setError('Not enough text detected. Please scan a clear food ingredient label.');
      if (mounted) context.go('/home');
      return;
    }

    // Isolate the ingredient section from the raw OCR dump.
    final cleanOcr = IngredientParser.sanitize(ocrText);
    debugPrint('[Pipeline] Sanitized OCR length: ${cleanOcr.length} chars');

    if (cleanOcr.trim().length < 10) {
      scanProvider.setError(
        'Could not find an ingredient list on the label. Please point the camera at the ingredients section and try again.',
      );
      if (mounted) context.go('/home');
      return;
    }

    final ingredientsList = IngredientParser.extract(cleanOcr);

    // ========= ON-DEVICE CHECKS (no network) =========
    final localThreats = LocalScanner().scanForThreats(
      ocrText: ocrText,
      userAllergies: userProvider.allergies,
      userConditions: userProvider.conditions,
      userAvoidList: userProvider.manualAvoidList,
    );
    final localScore = IndianWeightedScorer().calculateFssaiScore(ingredientsList);
    final marketingWarning = MarketingChecker().realityCheck(ocrText, ingredientsList);

    if (localThreats.isNotEmpty) {
      scanProvider.setLocalThreats(localThreats);
      if (mounted) {
        setState(() {
          _isEmergency = true;
          _statusText = 'Allergen Alert!';
          _subText = '${localThreats.length} potential concern(s) detected';
        });
      }
      try {
        await Haptics.vibrate(HapticsType.heavy);
        await Future.delayed(const Duration(milliseconds: 200));
        await Haptics.vibrate(HapticsType.heavy);
      } catch (_) {}
    }

    final localIngredients = _localIngredients(ingredientsList, localThreats);
    final productName = _guessProductName(ocrText);

    // ========= CLOUD EXPLANATION (optional, needs consent) =========
    if (!CloudConfig.isConfigured) {
      await _finishLocal(
        scanProvider, productName, localScore, marketingWarning, localIngredients,
        'Cloud explanations are not set up. Showing on-device results.',
      );
      return;
    }

    final allowed = mounted ? await ensureCloudConsent(context) : false;
    if (!allowed) {
      await _finishLocal(
        scanProvider, productName, localScore, marketingWarning, localIngredients,
        'Cloud explanations are off. Showing on-device results.',
      );
      return;
    }

    if (mounted && !_isEmergency) {
      setState(() {
        _statusText = 'Checking regulations...';
        _subText = 'Looking for sources for each flagged ingredient';
      });
    }
    scanProvider.setCloudScanning();

    try {
      final cloud = await CloudClient().explain(
        labelText: cleanOcr,
        allergies: userProvider.allergies,
        conditions: userProvider.conditions,
        avoid: userProvider.manualAvoidList,
      );

      if (cloud['status'] != 'ok') {
        await _finishLocal(
          scanProvider, productName, localScore, marketingWarning, localIngredients,
          'No regulation source found for this label. Showing on-device results.',
        );
        return;
      }

      final cloudIngredients = (cloud['ingredients'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      scanProvider.completeScan({
        'productName': productName,
        // The score comes from the deterministic on-device scorer, not the model.
        'healthScore': localScore,
        'marketingWarning': marketingWarning,
        'ingredients': _merge(cloudIngredients, localIngredients),
        'sources': cloud['sources'] ?? [],
      });

      if (mounted) {
        setState(() {
          _statusText = 'Analysis Complete!';
          _subText = 'Preparing your results...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) context.go('/results');
    } catch (e) {
      // Any failure (network, bad response, server error) falls back to the
      // on-device results. Log the type only.
      debugPrint('[Pipeline] cloud failed: ${e.runtimeType}');
      await _finishLocal(
        scanProvider, productName, localScore, marketingWarning, localIngredients,
        'Cloud explanation unavailable. Showing on-device results.',
      );
    }
  }

  /// Shows results from the on-device checks only.
  Future<void> _finishLocal(
    ScanProvider scanProvider,
    String productName,
    double score,
    String? marketingWarning,
    List<Map<String, dynamic>> ingredients,
    String message,
  ) async {
    scanProvider.completeScan({
      'productName': productName,
      'healthScore': score,
      'marketingWarning': marketingWarning,
      'ingredients': ingredients,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _statusText = 'Local Analysis Ready';
        _subText = message;
      });
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) context.go('/results');
  }

  /// True if one of the on-device threat words appears in the ingredient.
  bool _isThreat(String ingredient, List<String> threats) {
    final lower = ingredient.toLowerCase();
    return threats.any((t) => lower.contains(t.split(' (').first.toLowerCase()));
  }

  List<Map<String, dynamic>> _localIngredients(List<String> names, List<String> threats) {
    return names.map((ing) {
      final flagged = _isThreat(ing, threats);
      return <String, dynamic>{
        'name': ing,
        'impact': flagged ? 'bad' : 'neutral',
        'details': flagged
            ? [
                'Flagged by the on-device check.',
                'Matches an allergy, condition rule or avoid-list entry on your profile.',
                'Consult your doctor before consuming this product.',
              ]
            : [
                'Not flagged by the on-device checks.',
                'These checks cover your allergies, avoid list and condition rules only.',
              ],
      };
    }).toList();
  }

  /// Cloud entries (each with a citation) first, then on-device entries for
  /// ingredients the cloud did not cover.
  List<Map<String, dynamic>> _merge(
    List<Map<String, dynamic>> cloud,
    List<Map<String, dynamic>> local,
  ) {
    final covered = cloud.map((c) => (c['name'] ?? '').toString().toLowerCase()).toList();
    bool isCovered(String name) {
      final n = name.toLowerCase();
      return covered.any((c) => c.isNotEmpty && (n.contains(c) || c.contains(n)));
    }

    return [
      ...cloud,
      ...local.where((l) => !isCovered((l['name'] ?? '').toString())),
    ];
  }

  String _guessProductName(String ocrText) {
    // Skip lines that look like junk (timestamps, codes, very short)
    final noisePattern = RegExp(r'^(\d{1,2}:\d{2}|\d+g|packaging|sig|mfg|mrp)', caseSensitive: false);
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length > 4 && !noisePattern.hasMatch(l))
        .toList();
    if (lines.isNotEmpty) {
      final first = lines.first;
      return first.length > 40 ? '${first.substring(0, 40)}...' : first;
    }
    return 'Scanned Product';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main Content (always visible)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _DropletAnimation(),
                const SizedBox(height: 48),
                Text(
                  _statusText,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ).animate(
                  key: ValueKey(_statusText),
                ).fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  _subText,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ).animate(key: ValueKey(_subText)).fadeIn(delay: 200.ms),
              ],
            ),
          ),

          // Emergency Mode Banner (overlay on top)
          if (_isEmergency)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.error.withOpacity(0.9),
                      theme.colorScheme.error.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Text(
                      '⚠️ Allergen Match Found!',
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DropletAnimation extends StatelessWidget {
  const _DropletAnimation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primaryContainer,
                  blurRadius: 32,
                  spreadRadius: 8,
                )
              ],
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1200.ms, curve: Curves.easeInOut),

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
              ),
            ),
          ),

          Positioned(
            top: 10,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer,
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .rotate(duration: 2.seconds, curve: Curves.linear, alignment: const Alignment(0, 2.5)),

          Positioned(
            bottom: 10,
            right: 20,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .rotate(duration: 1500.ms, curve: Curves.linear, alignment: const Alignment(-1.5, -1)),
        ],
      ),
    );
  }
}
