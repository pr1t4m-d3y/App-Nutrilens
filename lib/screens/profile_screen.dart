import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/scan_history_provider.dart';
import '../providers/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Account', style: theme.textTheme.headlineLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () => _showSettingsSheet(context),
          )
        ],
      ),
      body: Consumer2<UserProfileProvider, ScanHistoryProvider>(
        builder: (context, profile, history, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120, top: 16),
            child: Column(
              children: [
                // User Header
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardTheme.color ?? Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name.isNotEmpty ? profile.name : 'Tap to set name',
                            style: theme.textTheme.titleLarge,
                          ),
                          Text('${history.scans.length} scans completed', style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          if (profile.bmi > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'BMI: ${profile.bmi.toStringAsFixed(1)}',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                              ),
                            ),
                        ],
                      ),
                    )
                  ],
                ).animate().slideX(begin: -0.1, end: 0).fadeIn(duration: 400.ms),

                const SizedBox(height: 48),

                // Bento Grid
                Row(
                  children: [
                    Expanded(
                      child: _BentoBlock(
                        title: 'Health Profile',
                        subtitle: '${profile.conditions.length} Conditions\n${profile.allergies.length} Allergies',
                        icon: Icons.monitor_heart_rounded,
                        color: theme.colorScheme.primary,
                        bgColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        onTap: () => context.push('/health-profile'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _BentoBlock(
                        title: 'Medicine',
                        subtitle: 'Reminders\n& Tracking',
                        icon: Icons.medication_liquid_rounded,
                        color: theme.colorScheme.primary,
                        bgColor: theme.colorScheme.primaryContainer.withOpacity(0.15),
                        onTap: () => context.push('/medicine-reminders'),
                      ),
                    ),
                  ],
                ).animate().slideY(begin: 0.1, end: 0, delay: 100.ms).fadeIn(delay: 100.ms),

                const SizedBox(height: 16),

                _BentoBlock(
                  title: 'My Avoid List',
                  subtitle: '${profile.manualAvoidList.length} Custom Ingredients',
                  icon: Icons.block_flipped,
                  color: theme.colorScheme.error,
                  bgColor: theme.colorScheme.errorContainer.withOpacity(0.1),
                  isFullWidth: true,
                  onTap: () => context.push('/avoid-list'),
                ).animate().slideY(begin: 0.1, end: 0, delay: 200.ms).fadeIn(delay: 200.ms),

                const SizedBox(height: 48),

                _ActionRow(icon: Icons.edit_rounded, label: 'Edit Name', onTap: () => _showEditNameDialog(context)),
                const SizedBox(height: 16),
                const _ActionRow(icon: Icons.help_outline_rounded, label: 'Help & Support'),
                const SizedBox(height: 16),
                const _ActionRow(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy'),

              ],
            ),
          );
        },
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final theme = Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48, height: 4,
                  decoration: BoxDecoration(color: theme.colorScheme.outlineVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(999)),
                ),
                const SizedBox(height: 24),
                Text('Settings', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 24),
                
                // Dark Mode Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Dark Mode', style: theme.textTheme.titleMedium)),
                      CupertinoSwitch(
                        value: themeProvider.isDarkMode,
                        activeTrackColor: theme.colorScheme.primary,
                        onChanged: (val) {
                          themeProvider.setDarkMode(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Add Family Member
                ListTile(
                  leading: Icon(Icons.group_add_rounded, color: theme.colorScheme.onSurface),
                  title: Text('Add Family Member', style: theme.textTheme.titleMedium),
                  trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddFamilyDialog(context);
                  },
                ),
                const SizedBox(height: 12),

                // Sign Out
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                  title: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Provider.of<AuthProvider>(context, listen: false).logout();
                    Provider.of<UserProfileProvider>(context, listen: false).clearAll();
                    Provider.of<ScanHistoryProvider>(context, listen: false).clearHistory();
                    context.go('/login');
                  },
                ),
                const SizedBox(height: 12),

                // Clear History
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                  title: Text('Clear Scan History', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w500)),
                  trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    Provider.of<ScanHistoryProvider>(ctx, listen: false).clearHistory();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scan history cleared')),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddFamilyDialog(BuildContext context) {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Add Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Mom, Dad',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationController,
              decoration: InputDecoration(
                labelText: 'Relation',
                hintText: 'e.g. Mother, Father, Spouse',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${nameController.text.trim()} added! (Family profiles coming soon)')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    final controller = TextEditingController(text: profile.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                profile.updateName(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _BentoBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isFullWidth;
  final VoidCallback onTap;

  const _BentoBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isFullWidth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isFullWidth ? 110 : 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: isFullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.cardTheme.color, shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color)),
                      Text(subtitle, style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.cardTheme.color, shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color)),
                    Text(subtitle, style: theme.textTheme.labelMedium),
                  ],
                )
              ],
            ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _ActionRow({required this.icon, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(icon, color: effectiveColor, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(label, style: theme.textTheme.titleMedium?.copyWith(color: effectiveColor))),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
