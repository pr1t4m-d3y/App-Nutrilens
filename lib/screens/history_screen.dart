import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/scan_history_provider.dart';
import '../providers/scan_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Scan History', style: theme.textTheme.headlineLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Consumer<ScanHistoryProvider>(
        builder: (context, history, _) {
          if (history.scans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No scans yet',
                    style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan a food label to see results here',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
            itemCount: history.scans.length,
            itemBuilder: (context, index) {
              final scan = history.scans[index];
              final String name = scan['productName'] ?? 'Unknown Product';
              final double score = (scan['healthScore'] as num?)?.toDouble() ?? 5.0;
              final String timestamp = scan['timestamp'] ?? '';
              final String timeAgo = _formatTimeAgo(timestamp);

              return GestureDetector(
                onTap: () {
                  final scanProvider = Provider.of<ScanProvider>(context, listen: false);
                  final isMedicine = scan['scanType'] == 'medicine';
                  scanProvider.viewFromHistory(scan, type: isMedicine ? ScanType.medicine : ScanType.food);
                  context.push(isMedicine ? '/medicine-results' : '/results');
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scan['scanType'] == 'medicine'
                              ? const Color(0xFF00BFA5).withOpacity(0.1)
                              : _getScoreColor(theme, score).withOpacity(0.1),
                        ),
                        child: Center(
                          child: scan['scanType'] == 'medicine'
                              ? const Icon(Icons.medication_rounded, color: Color(0xFF00BFA5), size: 24)
                              : Text(
                                  score.toStringAsFixed(1),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _getScoreColor(theme, score),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(timeAgo, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ).animate().slideX(begin: 0.05, end: 0, delay: Duration(milliseconds: 50 * index)).fadeIn(delay: Duration(milliseconds: 50 * index));
            },
          );
        },
      ),
    );
  }

  Color _getScoreColor(ThemeData theme, double s) {
    if (s < 4.0) return theme.colorScheme.error;
    if (s < 7.0) return Colors.orange;
    return const Color(0xFF43A047); // Green
  }

  String _formatTimeAgo(String isoTimestamp) {
    if (isoTimestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoTimestamp);
      final diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (_) {
      return '';
    }
  }
}
