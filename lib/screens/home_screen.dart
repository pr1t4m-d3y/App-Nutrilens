import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/scan_history_provider.dart';
import '../providers/scan_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/nlp_chatbot_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = Provider.of<UserProfileProvider>(context);
    final displayName = profile.name.isNotEmpty ? profile.name : 'User';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getGreeting(), style: theme.textTheme.bodyMedium),
            Text(displayName, style: theme.textTheme.headlineLarge),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DateSelector(),
            const SizedBox(height: 32),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text('Last Scan Result', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: _HeroScanCard(),
            ),
            
            const SizedBox(height: 48),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Scans', style: theme.textTheme.titleLarge),
                  TextButton(
                    onPressed: () => context.go('/history'),
                    child: Text('See All', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _RecentScansList(),
            const SizedBox(height: 48),
            const NlpChatbotWidget(),
          ],
        ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = now.subtract(Duration(days: 6 - index));
          final isToday = index == 6;

          return Container(
            width: 60,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isToday ? theme.colorScheme.primary : (theme.cardTheme.color ?? theme.colorScheme.surface),
              borderRadius: BorderRadius.circular(24),
              border: isToday ? null : Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getWeekday(date.weekday),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isToday ? Colors.white.withOpacity(0.8) : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${date.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isToday ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getWeekday(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day - 1];
  }
}

class _HeroScanCard extends StatelessWidget {
  const _HeroScanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = Provider.of<ScanHistoryProvider>(context);
    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    final latest = history.latestScan;

    // Dynamic data from latest scan, or defaults
    final String title = latest?['productName'] ?? 'No scans yet';
    final double score = (latest?['healthScore'] as num?)?.toDouble() ?? 0.0;
    final bool hasData = latest != null;

    return GestureDetector(
      onTap: () {
        if (hasData) {
          final isMedicine = latest!['scanType'] == 'medicine';
          if (isMedicine) {
            scanProvider.viewFromHistory(latest!, type: ScanType.medicine);
            context.push('/medicine-results');
          } else {
            scanProvider.viewFromHistory(latest!, type: ScanType.food);
            context.push('/results');
          }
          context.push(isMedicine ? '/medicine-results' : '/results');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.onSurface.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: hasData
            ? Row(
                children: [
                  // Animated Score Ring
                  // Image / Ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: latest != null && latest['scanType'] == 'medicine'
                      ? Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF004D40), // Deep teal
                          ),
                          child: const Center(
                            child: Icon(Icons.medication_rounded, color: Color(0xFF00BFA5), size: 36),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 8,
                              color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: score / 10),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: 8,
                                  strokeCap: StrokeCap.round,
                                  color: _getScoreColor(theme, score),
                                );
                              },
                            ),
                            Center(
                              child: Text(
                                score.toStringAsFixed(1),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _getScoreColor(theme, score),
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              latest != null && latest['scanType'] == 'medicine'
                                ? Icons.health_and_safety_rounded
                                : score >= 7 ? Icons.check_circle_rounded : Icons.info_rounded,
                              color: latest != null && latest['scanType'] == 'medicine'
                                ? const Color(0xFF00BFA5)
                                : _getScoreColor(theme, score),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              latest != null && latest['scanType'] == 'medicine'
                                ? 'Medicine Lookup'
                                : score >= 7 ? 'Good Choice' : score >= 4 ? 'Fair' : 'Caution',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: theme.colorScheme.onSurfaceVariant, size: 32),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan your first label', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Tap the camera icon below to start',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }

  Color _getScoreColor(ThemeData theme, double s) {
    if (s < 4.0) return theme.colorScheme.error;
    if (s < 7.0) return Colors.orange;
    return theme.colorScheme.primary;
  }
}

class _RecentScansList extends StatelessWidget {
  const _RecentScansList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = Provider.of<ScanHistoryProvider>(context);
    final scans = history.scans.take(5).toList();

    if (scans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Text(
          'Your recent scans will appear here',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: scans.length,
        itemBuilder: (context, index) {
          final item = scans[index];
          final String title = item['productName'] ?? 'Unknown';
          final double score = (item['healthScore'] as num?)?.toDouble() ?? 5.0;
          final String timestamp = item['timestamp'] ?? '';
          final String timeAgo = _formatTimeAgo(timestamp);

          return GestureDetector(
            onTap: () {
              final scanProvider = Provider.of<ScanProvider>(context, listen: false);
              final isMedicine = item['scanType'] == 'medicine';
              if (isMedicine) {
                scanProvider.viewFromHistory(item, type: ScanType.medicine);
                context.push('/medicine-results');
              } else {
                scanProvider.viewFromHistory(item, type: ScanType.food);
                context.push('/results');
              }
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (item['scanType'] == 'medicine')
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF004D40), // Deep teal
                          ),
                          child: const Icon(Icons.medication_rounded, color: Color(0xFF00BFA5), size: 18),
                        )
                      else
                        Text(score.toStringAsFixed(1), 
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: _getColor(theme, score),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, 
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(timeAgo, style: theme.textTheme.labelSmall),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getColor(ThemeData theme, double s) {
    if (s < 4.0) return theme.colorScheme.error;
    if (s < 7.0) return Colors.orange;
    return theme.colorScheme.primary;
  }

  String _formatTimeAgo(String isoTimestamp) {
    if (isoTimestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoTimestamp);
      final diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}
