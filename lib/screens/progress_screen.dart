import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_calorie_chart.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  double? _calculatedBmi;
  String _bmiVerdict = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = Provider.of<UserProfileProvider>(context, listen: false);
      _heightController.text = profile.heightCm > 0 ? profile.heightCm.toStringAsFixed(0) : '';
      _weightController.text = profile.weightKg > 0 ? profile.weightKg.toStringAsFixed(1) : '';
      _ageController.text = profile.age > 0 ? profile.age.toString() : '';
      if (profile.bmi > 0) {
        setState(() {
          _calculatedBmi = profile.bmi;
          _bmiVerdict = _getVerdict(profile.bmi);
        });
      }
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _calculateBmi() async {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final age = int.tryParse(_ageController.text.trim());

    if (height == null || weight == null || height <= 0 || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid height and weight')),
      );
      return;
    }

    final heightM = height / 100;
    final bmi = weight / (heightM * heightM);

    setState(() {
      _calculatedBmi = bmi;
      _bmiVerdict = _getVerdict(bmi);
    });

    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    profile.updatePhysical(heightCm: height, weightKg: weight, age: age ?? 0);
    profile.updateBmi(bmi);

    try {
      await Haptics.vibrate(HapticsType.medium);
    } catch (_) {}
  }

  String _getVerdict(double bmi) {
    if (bmi < 16) return '⚠️ Severely Underweight — Please consult a doctor';
    if (bmi < 18.5) return '🍽️ Underweight — Try to eat more nutritious meals';
    if (bmi < 25) return '💪 Fit & Healthy — Keep up the great work!';
    if (bmi < 30) return '⚡ Overweight — Time to get moving!';
    if (bmi < 35) return '🔥 Obese — Consider a structured diet plan';
    return '🚨 Severely Obese — Please consult a healthcare provider';
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25) return AppColors.primary;
    if (bmi < 30) return Colors.orange;
    return const Color(0xFFA73B21);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Your Progress', style: theme.textTheme.headlineLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCards(theme),
            const SizedBox(height: 32),
            
            Text('Caloric Intake', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))
              .animate().fade().slideX(begin: -0.1),
            const SizedBox(height: 16),
            _buildProgressChart(theme),
            
            const SizedBox(height: 32),
            Text('BMI Calculator', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))
              .animate().fade().slideX(begin: -0.1),
            const SizedBox(height: 16),
            _buildBmiCalculator(theme),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(ThemeData theme) {
    final profile = Provider.of<UserProfileProvider>(context);
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            theme,
            'Current Weight',
            profile.weightKg > 0 ? '${profile.weightKg.toStringAsFixed(1)} kg' : '-- kg',
            Icons.monitor_weight_outlined,
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            theme,
            'Age',
            profile.age > 0 ? '${profile.age} yrs' : '-- yrs',
            Icons.cake_outlined,
            Colors.orange,
          ),
        ),
      ],
    ).animate().fade(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildCard(ThemeData theme, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildProgressChart(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.onSurface.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
        ],
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: SizedBox(
          height: 150,
          child: AnimatedCalorieChart(
            dataPoints: Provider.of<UserProfileProvider>(context).userId == 'Admin123'
                ? [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
                : [2100.0, 2250.0, 1950.0, 2400.0, 2050.0, 2200.0, 1800.0],
            lineColor: AppColors.primary,
            gradientColor: AppColors.primaryContainer,
          ),
        ),
      ),
    ).animate().fade().scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack);
  }

  Widget _buildBmiCalculator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.onSurface.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input fields row 1
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Height (cm)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Input fields row 2
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age (years)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: const SizedBox()), // Empty space to keep age field same width
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _calculateBmi,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Calculate BMI'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          // Result with Gauge
          if (_calculatedBmi != null) ...[
            const SizedBox(height: 24),
            
            // Your BMI card with gauge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your BMI', style: theme.textTheme.titleMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getBmiColor(_calculatedBmi!).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _getBmiColor(_calculatedBmi!).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getBmiCategory(_calculatedBmi!),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _getBmiColor(_calculatedBmi!),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Score
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _calculatedBmi!.toStringAsFixed(1),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: _getBmiColor(_calculatedBmi!),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('kg/m²', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ============ BMI GAUGE ============
                  _BmiGauge(bmi: _calculatedBmi!),
                  
                  const SizedBox(height: 20),

                  // Verdict
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getBmiColor(_calculatedBmi!).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _getBmiColor(_calculatedBmi!).withOpacity(0.2)),
                    ),
                    child: Text(
                      _bmiVerdict,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).scaleXY(begin: 0.95, end: 1.0),
          ],
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }
}

/// BMI Gauge widget — horizontal bar with gradient from blue→green→orange→red
/// and a pointer/thumb showing the user's BMI position
class _BmiGauge extends StatelessWidget {
  final double bmi;
  const _BmiGauge({required this.bmi});

  @override
  Widget build(BuildContext context) {
    // BMI range: 15 to 40 for visualization
    const double minBmi = 15.0;
    const double maxBmi = 40.0;
    final double clampedBmi = bmi.clamp(minBmi, maxBmi);
    final double fraction = (clampedBmi - minBmi) / (maxBmi - minBmi);

    return Column(
      children: [
        // Gauge bar with pointer
        SizedBox(
          height: 40,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pointerX = fraction * constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // The gradient bar
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF42A5F5), // Underweight - blue
                            Color(0xFF66BB6A), // Healthy - green
                            Color(0xFFFFA726), // Overweight - orange
                            Color(0xFFEF5350), // Obese - red
                          ],
                          stops: [0.0, 0.35, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Pointer triangle + circle
                  Positioned(
                    left: pointerX - 8,
                    top: 0,
                    child: Column(
                      children: [
                        // Triangle pointer
                        CustomPaint(
                          size: const Size(16, 10),
                          painter: _TrianglePainter(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        // Vertical line
                        Container(
                          width: 3,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Category labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('UNDERWEIGHT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
            Text('HEALTHY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
            Text('OVERWEIGHT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
            Text('OBESE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
          ],
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
