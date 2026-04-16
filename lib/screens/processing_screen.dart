import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/local_scanner.dart';
import '../services/smart_scan_service.dart';
import '../services/indian_weighted_scorer.dart';
import '../services/marketing_checker.dart';

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

    // ─── OCR SANITIZER ───────────────────────────────────────────────
    // Step 1: Extract only the ingredient section from the raw OCR dump
    final cleanOcr = _sanitizeOcrText(ocrText);
    debugPrint("[Pipeline] Sanitized OCR (${cleanOcr.length} chars): $cleanOcr");

    // If sanitized text is too short after cleaning, abort early
    if (cleanOcr.trim().length < 10) {
      scanProvider.setError(
        'Could not find an ingredient list on the label. Please point the camera at the ingredients section and try again.',
      );
      if (mounted) context.go('/home');
      return;
    }
    // ─────────────────────────────────────────────────────────────────

    final ingredientsList = _extractIngredients(cleanOcr);

    // ========= CLOUD-START PARALLELISM =========
    // Fire cloud request with SANITIZED text only — no packaging noise
    final smartScan = SmartScanService();
    final cloudFuture = smartScan.initiateCloudScan(
      ocrText: cleanOcr,
      userMetadata: userProvider.toMetadataMap(),
    );

    final localScanner = LocalScanner();
    final localThreats = localScanner.scanForThreats(
      ocrText: ocrText,
      userAllergies: userProvider.allergies,
      userConditions: userProvider.conditions,
    );

    final scorer = IndianWeightedScorer();
    final localScore = scorer.calculateFssaiScore(ingredientsList);

    final marketingChecker = MarketingChecker();
    final marketingWarning = marketingChecker.realityCheck(ocrText, ingredientsList);

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
    } else {
      if (mounted) {
        setState(() {
          _statusText = 'Cloud AI Analyzing...';
          _subText = 'Cross-referencing with health databases';
        });
      }
    }

    scanProvider.setCloudScanning();

    try {
      final cloudResults = await cloudFuture;
      
      if (cloudResults['marketingWarning'] == null && marketingWarning != null) {
        cloudResults['marketingWarning'] = marketingWarning;
      }
      
      scanProvider.completeScan(cloudResults);

      if (mounted) {
        setState(() {
          _statusText = 'Analysis Complete!';
          _subText = 'Preparing your results...';
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) context.go('/results');
    } catch (e) {
      debugPrint("Cloud scan failed: $e");

      // ⚠️ DIAGNOSTIC: Show exact error on screen even in release builds
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Error (share this): ${e.toString().substring(0, e.toString().length > 120 ? 120 : e.toString().length)}',
              style: const TextStyle(fontSize: 11),
            ),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      final localResults = {
        'productName': _guessProductName(ocrText),
        'healthScore': localScore,
        'marketingWarning': marketingWarning,
        'ingredients': ingredientsList.map((ing) {
          final isThreat = localThreats.any((t) => t.toLowerCase().contains(ing.toLowerCase()));
          return {
            'name': ing,
            'impact': isThreat ? 'bad' : 'neutral',
            'details': isThreat
              ? [
                  'Flagged by local scanner as potentially harmful.',
                  'Matches a known allergen or condition in your health profile.',
                  'Consult your doctor before consuming this product.',
                ]
              : [
                  'No immediate concerns detected by local scanner.',
                  'Did not match any flagged allergens or conditions.',
                  'Cloud AI was unavailable to provide a deeper analysis.',
                ],
          };
        }).toList(),
      };

      scanProvider.completeScan(localResults);

      if (mounted) {
        setState(() {
          _statusText = 'Local Analysis Ready';
          _subText = 'Cloud AI unavailable, showing local results';
        });
      }

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go('/results');
    }
  }

  // ─── OCR PRE-PROCESSING: Isolate and clean the ingredient list ───────
  String _sanitizeOcrText(String raw) {
    final lower = raw.toLowerCase();

    // 1. Find the start of the ingredients section
    final markers = [
      'ingredients:', 'ingredient:', 'ingredients list:',
      'contains:', 'composition:', 'ingr:',
    ];
    int startIdx = -1;
    for (final marker in markers) {
      final idx = lower.indexOf(marker);
      if (idx != -1) {
        startIdx = idx + marker.length;
        break;
      }
    }

    // If no marker found, use the full raw text but still filter noise
    final workingText = startIdx != -1 ? raw.substring(startIdx) : raw;

    // 2. Truncate at known end-of-ingredient markers
    final endMarkers = [
      'manufactured', 'packed by', 'packaging by', 'best before',
      'mrp', 'net weight', 'distributed', 'marketed by',
      'fssai', 'batch', 'mfg', 'expiry', 'customer care',
    ];
    String trimmed = workingText.toLowerCase();
    int endIdx = workingText.length;
    for (final end in endMarkers) {
      final idx = trimmed.indexOf(end);
      if (idx != -1 && idx < endIdx) endIdx = idx;
    }

    // 3. Filter out noise lines line by line
    final lines = workingText.substring(0, endIdx).split(RegExp(r'[\n\r]'));
    final cleaned = lines.where((line) {
      final t = line.trim();
      if (t.length < 2) return false;           // empty or 1-char junk
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(t)) return false; // timestamps like 03:52
      if (RegExp(r'^\d+\.?\d*\s*(g|mg|ml|kg|%)?\s*$').hasMatch(t)) return false; // lone numbers
      return true;
    }).join(', ');

    return cleaned.trim();
  }

  List<String> _extractIngredients(String cleanText) {
    return cleanText
        .split(RegExp(r'[,\n•·;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 1 && s.length < 60)
        .take(25)
        .toList();
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
