import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../providers/scan_history_provider.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Save to history when results are shown
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

    // Fallback if no results
    final String productName = results?['productName'] ?? 'Unknown Product';
    final double healthScore = (results?['healthScore'] as num?)?.toDouble() ?? 5.0;
    final String? marketingWarning = results?['marketingWarning'];
    final List<dynamic> ingredients = results?['ingredients'] ?? [];

    // Split into good, neutral, and bad. Handle legacy `isHarmful` boolean for old mock data.
    final badIngredients = ingredients.where((i) {
      if (i['impact'] != null) return i['impact'] == 'harmful' || i['impact'] == 'bad';
      return i['isHarmful'] == true;
    }).toList();
    
    final neutralIngredients = ingredients.where((i) {
      if (i['impact'] != null) return i['impact'] == 'neutral';
      return false; // Legacy mock data didn't have neutral
    }).toList();

    final goodIngredients = ingredients.where((i) {
      if (i['impact'] != null) return i['impact'] == 'good';
      return i['isHarmful'] != true && i['impact'] != 'neutral';
    }).toList();

    final Map<String, dynamic>? healthierSwap = results?['healthierSwap'];


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
        title: Text('Scan Results', style: theme.textTheme.titleLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120, top: 16),
        child: Column(
          children: [
            // Marketing Reality Check Banner
            if (marketingWarning != null && marketingWarning.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        marketingWarning,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade900),
                      ),
                    )
                  ],
                ),
              ).animate().slideY(begin: -0.2, end: 0).fadeIn(),

            if (marketingWarning != null) const SizedBox(height: 32),
            
            // Score visualization
            _ScoreRing(score: healthScore).animate().scaleXY(begin: 0.8, end: 1.0, duration: 600.ms, curve: Curves.easeOutBack),
            
            const SizedBox(height: 16),
            Text(productName, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            if (badIngredients.isNotEmpty)
              Text('Contains ${badIngredients.length} concern(s) for your profile', 
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              )
            else
              Text('Looks good for your profile!', 
                style: theme.textTheme.labelLarge?.copyWith(color: const Color(0xFF43A047)),
                textAlign: TextAlign.center,
              ),
            
            const SizedBox(height: 32),

            // ─── Ingredients to Watch (Bad) Card ───
            if (badIngredients.isNotEmpty)
              _IngredientGroupCard(
                title: 'Ingredients to Watch',
                icon: Icons.warning_rounded,
                iconColor: theme.colorScheme.error,
                borderColor: theme.colorScheme.error.withOpacity(0.3),
                bgColor: theme.colorScheme.error.withOpacity(0.05),
                ingredients: badIngredients,
                statusColor: theme.colorScheme.error,
              ).animate().slideX(begin: 0.1, end: 0).fadeIn(),

            if (badIngredients.isNotEmpty && (neutralIngredients.isNotEmpty || goodIngredients.isNotEmpty))
              const SizedBox(height: 16),

            // ─── Neutral Ingredients Card ───
            if (neutralIngredients.isNotEmpty)
              _IngredientGroupCard(
                title: 'Neutral Ingredients',
                icon: Icons.info_outline_rounded,
                iconColor: theme.colorScheme.onSurfaceVariant,
                borderColor: theme.colorScheme.outlineVariant.withOpacity(0.5),
                bgColor: theme.colorScheme.surfaceVariant?.withOpacity(0.3) ?? theme.colorScheme.surfaceTint.withOpacity(0.05),
                ingredients: neutralIngredients,
                statusColor: theme.colorScheme.onSurfaceVariant,
              ).animate().slideX(begin: 0.1, end: 0, delay: 100.ms).fadeIn(delay: 100.ms),

            if (neutralIngredients.isNotEmpty && goodIngredients.isNotEmpty)
              const SizedBox(height: 16),

            // ─── Good Ingredients Card ───
            if (goodIngredients.isNotEmpty)
              _IngredientGroupCard(
                title: 'Good Ingredients',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF43A047),
                borderColor: const Color(0xFF43A047).withOpacity(0.3),
                bgColor: const Color(0xFF43A047).withOpacity(0.05),
                ingredients: goodIngredients,
                statusColor: const Color(0xFF43A047),
              ).animate().slideX(begin: 0.1, end: 0, delay: 200.ms).fadeIn(delay: 200.ms),

            if (ingredients.isEmpty) ...[
              const SizedBox(height: 48),
              Icon(Icons.check_circle_outline_rounded, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('No ingredient data available', style: theme.textTheme.bodyLarge),
            ],

            // Local threats section (if any)
            if (scan.localThreats.isNotEmpty) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Local Safety Alerts', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
              ),
              const SizedBox(height: 12),
              ...scan.localThreats.map((threat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_rounded, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(threat, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              )),
            ],

            // ─── Healthier Swap Block ───
            if (healthierSwap != null && healthierSwap.isNotEmpty && healthScore < 7.0) ...[
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00BFA5).withOpacity(0.2), const Color(0xFF00BFA5).withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF00BFA5).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BFA5).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.swap_calls_rounded, color: Color(0xFF00BFA5), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Healthier Swap',
                          style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF00BFA5), fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      healthierSwap['name'] ?? 'Healthier Alternative',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      healthierSwap['reason'] ?? 'This option is better suited for your health constraints.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 0.1, end: 0, delay: 300.ms).fadeIn(delay: 300.ms),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Grouped Ingredient Card ───
class _IngredientGroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color bgColor;
  final List<dynamic> ingredients;
  final Color statusColor;

  const _IngredientGroupCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.bgColor,
    required this.ingredients,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(color: iconColor, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${ingredients.length}',
                  style: theme.textTheme.labelMedium?.copyWith(color: iconColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Ingredient items
          ...ingredients.asMap().entries.map((entry) {
            final item = Map<String, dynamic>.from(entry.value);
            final String name = item['name'] ?? 'Unknown';
            // Support new `details` array format from AI, with legacy `note`/`reasoning` fallback
            final List<String> details = item['details'] != null
                ? List<String>.from(item['details'])
                : (item['note'] ?? item['reasoning'] ?? '').toString().isNotEmpty
                    ? [(item['note'] ?? item['reasoning']).toString()]
                    : [];
            return _IngredientListItem(
              name: name,
              details: details,
              statusColor: statusColor,
              isLast: entry.key == ingredients.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _IngredientListItem extends StatefulWidget {
  final String name;
  final List<String> details;
  final Color statusColor;
  final bool isLast;

  const _IngredientListItem({
    required this.name,
    required this.details,
    required this.statusColor,
    required this.isLast,
  });

  @override
  State<_IngredientListItem> createState() => _IngredientListItemState();
}

class _IngredientListItemState extends State<_IngredientListItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = widget.statusColor;

    final bool hasDetails = widget.details.isNotEmpty;

    return GestureDetector(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                ),
                if (hasDetails)
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          // Expandable bullet-point details
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: _expanded ? null : 0,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.details.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: theme.textTheme.bodySmall?.copyWith(
                          color: dotColor,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        )),
                        Expanded(
                          child: Text(
                            point,
                            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
          if (!widget.isLast)
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
        ],
      ),
    );
  }
}


class _ScoreRing extends StatelessWidget {
  final double score;
  const _ScoreRing({required this.score});

  Color _getScoreColor(BuildContext context, double s) {
    if (s < 4.0) return Theme.of(context).colorScheme.error;
    if (s < 7.0) return Colors.orange;
    return const Color(0xFF43A047); // Green shade for healthy
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 16,
            color: theme.colorScheme.outlineVariant.withOpacity(0.2),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: score / 10),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 16,
                strokeCap: StrokeCap.round,
                color: _getScoreColor(context, score),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: _getScoreColor(context, score),
                    height: 1.0,
                  ),
                ),
                Text(
                  '/ 10',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
