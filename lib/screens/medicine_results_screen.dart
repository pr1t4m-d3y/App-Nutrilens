import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../providers/scan_history_provider.dart';

class MedicineResultsScreen extends StatefulWidget {
  const MedicineResultsScreen({super.key});

  @override
  State<MedicineResultsScreen> createState() => _MedicineResultsScreenState();
}

class _MedicineResultsScreenState extends State<MedicineResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Save to history only for fresh scans, not when viewing from history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scan = Provider.of<ScanProvider>(context, listen: false);
      if (scan.results != null && !scan.isFromHistory) {
        final history = Provider.of<ScanHistoryProvider>(context, listen: false);
        history.addScan(scan.results!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scan = Provider.of<ScanProvider>(context);
    final results = scan.results;

    final List<dynamic> matches = results?['matches'] ?? [];
    final String ocrText = results?['ocrText'] ?? '';
    final int matchCount = results?['matchCount'] ?? 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text('Medicine Scan', style: theme.textTheme.titleLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120, top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            if (matchCount > 0) ...[
              _buildMatchHeader(theme, matches.first, matchCount),
              const SizedBox(height: 24),
              // Show each matched medicine with its generics
              ...matches.asMap().entries.map((entry) {
                final idx = entry.key;
                final med = Map<String, dynamic>.from(entry.value);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _MedicineMatchCard(medicine: med, index: idx),
                ).animate()
                 .slideY(begin: 0.1, end: 0, delay: Duration(milliseconds: 100 * idx))
                 .fadeIn(delay: Duration(milliseconds: 100 * idx));
              }),
            ] else ...[
              _buildNoMatchView(theme, ocrText),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader(ThemeData theme, Map<String, dynamic> firstMatch, int count) {
    const teal = Color(0xFF00BFA5);
    final brandName = firstMatch['Brand_Name'] ?? 'Unknown';
    final composition = firstMatch['Composition'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [teal.withOpacity(0.12), teal.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: teal.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication_rounded, color: teal, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brandName,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (composition.isNotEmpty)
                      Text(composition,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: teal, size: 18),
                const SizedBox(width: 6),
                Text('$count Generic Alternative${count > 1 ? 's' : ''} Found',
                  style: theme.textTheme.labelLarge?.copyWith(color: teal, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().scaleXY(begin: 0.95, end: 1.0, duration: 500.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Widget _buildNoMatchView(ThemeData theme, String ocrText) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.errorContainer.withOpacity(0.2),
            ),
            child: Icon(Icons.search_off_rounded, size: 56, color: theme.colorScheme.error.withOpacity(0.6)),
          ).animate().scaleXY(begin: 0.8, end: 1.0, duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text('No Generic Alternative Found',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'We could not find a matching medicine or salt composition in our database for the scanned text.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          // Show what was detected
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (theme.cardTheme.color ?? theme.colorScheme.surface),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_snippet_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('Detected Text', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ocrText.length > 300 ? '${ocrText.substring(0, 300)}...' : ocrText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/scan'),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Try Again'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

/// A card showing one matched medicine with up to 3 generic alternatives.
class _MedicineMatchCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final int index;

  const _MedicineMatchCard({required this.medicine, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const teal = Color(0xFF00BFA5);

    final String brandName = medicine['Brand_Name'] ?? '';
    final String composition = medicine['Composition'] ?? '';
    final String strength = medicine['Strength'] ?? '';
    final String dosageForm = medicine['Dosage_Form'] ?? '';
    final String category = medicine['Therapeutic_Category'] ?? '';
    final String subCategory = medicine['Sub_Category'] ?? '';
    final String manufacturer = medicine['Brand_Manufacturer'] ?? '';
    final double brandPrice = (medicine['Brand_Price_Per_Unit_INR'] as num?)?.toDouble() ?? 0;
    final double savingsPct = (medicine['Approx_Savings_Pct'] as num?)?.toDouble() ?? 0;
    final String prescriptionType = medicine['Prescription_Type'] ?? '';
    final String schedule = medicine['Schedule'] ?? '';
    final String? notes = medicine['Notes'];

    // Build generic alternatives list
    final generics = <Map<String, String>>[];
    for (int i = 1; i <= 3; i++) {
      final altName = medicine['Generic_Alt_$i'];
      final altMfr = medicine['Generic_Manufacturer_$i'];
      final altPrice = medicine['Generic_Price_${i}_INR'];
      if (altName != null && altName.toString().isNotEmpty) {
        generics.add({
          'name': altName.toString(),
          'manufacturer': altMfr?.toString() ?? '',
          'price': altPrice?.toString() ?? '',
        });
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Brand Info Header ───
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(brandName,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text('$composition • $strength • $dosageForm',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    // Brand price badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('₹${brandPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tags row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Tag(label: category, color: teal),
                    if (subCategory.isNotEmpty) _Tag(label: subCategory, color: theme.colorScheme.primary),
                    _Tag(label: manufacturer, color: theme.colorScheme.onSurfaceVariant),
                    if (prescriptionType.isNotEmpty) _Tag(
                      label: prescriptionType,
                      color: prescriptionType == 'OTC' ? const Color(0xFF43A047) : Colors.orange,
                    ),
                    if (schedule.isNotEmpty && schedule != prescriptionType)
                      _Tag(label: schedule, color: Colors.deepPurple),
                  ],
                ),
              ],
            ),
          ),

          // ─── Savings Banner ───
          if (savingsPct > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF43A047).withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, color: Color(0xFF43A047), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Save up to ${savingsPct.toStringAsFixed(0)}% with generic alternatives',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF43A047),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Generic Alternatives ───
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: teal, size: 20),
                    const SizedBox(width: 8),
                    Text('Generic Alternatives',
                      style: theme.textTheme.titleSmall?.copyWith(color: teal, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...generics.asMap().entries.map((entry) {
                  final g = entry.value;
                  final gPrice = double.tryParse(g['price'] ?? '') ?? 0;
                  final saving = brandPrice > 0 && gPrice > 0
                      ? ((brandPrice - gPrice) / brandPrice * 100)
                      : 0.0;
                  return _GenericAlternativeRow(
                    name: g['name']!,
                    manufacturer: g['manufacturer']!,
                    price: gPrice,
                    savingPercent: saving,
                    isLast: entry.key == generics.length - 1,
                  );
                }),
              ],
            ),
          ),

          // ─── Notes ───
          if (notes != null && notes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(notes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GenericAlternativeRow extends StatelessWidget {
  final String name;
  final String manufacturer;
  final double price;
  final double savingPercent;
  final bool isLast;

  const _GenericAlternativeRow({
    required this.name,
    required this.manufacturer,
    required this.price,
    required this.savingPercent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication_liquid_rounded,
                  color: Color(0xFF00BFA5), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(manufacturer,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF43A047),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (savingPercent > 0)
                    Text('${savingPercent.toStringAsFixed(0)}% cheaper',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF43A047),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
      ],
    );
  }
}
