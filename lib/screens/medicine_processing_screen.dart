import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../services/medicine_db_service.dart';

class MedicineProcessingScreen extends StatefulWidget {
  const MedicineProcessingScreen({super.key});

  @override
  State<MedicineProcessingScreen> createState() => _MedicineProcessingScreenState();
}

class _MedicineProcessingScreenState extends State<MedicineProcessingScreen> {
  String _statusText = 'Scanning Medicine...';
  String _subText = 'Reading text from package';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processMedicine());
  }

  Future<void> _processMedicine() async {
    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    final ocrText = scanProvider.ocrText;

    if (ocrText.isEmpty) {
      scanProvider.setError('No text captured from camera');
      if (mounted) context.go('/home');
      return;
    }

    // Step 1: Load medicine database
    if (mounted) {
      setState(() {
        _statusText = 'Loading Medicine Database...';
        _subText = 'Preparing ${MedicineDbService().totalMedicines > 0 ? MedicineDbService().totalMedicines : 370}+ medicines';
      });
    }

    final dbService = MedicineDbService();
    await dbService.loadDatabase();

    await Future.delayed(const Duration(milliseconds: 400));

    // Step 2: Search
    if (mounted) {
      setState(() {
        _statusText = 'Searching Generics...';
        _subText = 'Matching brand names & salt compositions';
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));

    final matches = dbService.searchByOcrText(ocrText);

    // Step 3: Build results
    if (mounted) {
      setState(() {
        _statusText = matches.isNotEmpty
            ? '${matches.length} Match${matches.length > 1 ? 'es' : ''} Found!'
            : 'Search Complete';
        _subText = matches.isNotEmpty
            ? 'Preparing your generic alternatives...'
            : 'Preparing results...';
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Build the result map
    final result = <String, dynamic>{
      'scanType': 'medicine',
      'ocrText': ocrText,
      'matches': matches,
      'matchCount': matches.length,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (matches.isNotEmpty) {
      final first = matches.first;
      result['productName'] = first['Brand_Name'] ?? 'Unknown Medicine';
      result['composition'] = first['Composition'] ?? '';
      result['healthScore'] = 0.0; // Not applicable for medicine
    } else {
      result['productName'] = _guessProductName(ocrText);
      result['composition'] = '';
      result['healthScore'] = 0.0;
    }

    scanProvider.completeScan(result);

    if (mounted) context.go('/medicine-results');
  }

  String _guessProductName(String ocrText) {
    final lines = ocrText.split('\n').where((l) => l.trim().length > 3).toList();
    if (lines.isNotEmpty) {
      final first = lines.first.trim();
      return first.length > 40 ? '${first.substring(0, 40)}...' : first;
    }
    return 'Scanned Medicine';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _MedicinePulseAnimation(),
            const SizedBox(height: 48),
            Text(
              _statusText,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ).animate(key: ValueKey(_statusText)).fadeIn().slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              _subText,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ).animate(key: ValueKey(_subText)).fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _MedicinePulseAnimation extends StatelessWidget {
  const _MedicinePulseAnimation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const teal = Color(0xFF00BFA5);
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: teal.withOpacity(0.3), blurRadius: 32, spreadRadius: 8),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1200.ms, curve: Curves.easeInOut),

          // Inner circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [teal, teal.withOpacity(0.6)],
              ),
            ),
            child: const Icon(Icons.medication_rounded, color: Colors.white, size: 36),
          ),

          // Orbiting dot 1
          Positioned(
            top: 10,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: teal.withOpacity(0.5)),
            ),
          ).animate(onPlay: (c) => c.repeat())
           .rotate(duration: 2.seconds, curve: Curves.linear, alignment: const Alignment(0, 2.5)),

          // Orbiting dot 2
          Positioned(
            bottom: 10,
            right: 20,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: teal.withOpacity(0.7)),
            ),
          ).animate(onPlay: (c) => c.repeat())
           .rotate(duration: 1500.ms, curve: Curves.linear, alignment: const Alignment(-1.5, -1)),
        ],
      ),
    );
  }
}
