import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';

class AvoidListScreen extends StatefulWidget {
  const AvoidListScreen({super.key});

  @override
  State<AvoidListScreen> createState() => _AvoidListScreenState();
}

class _AvoidListScreenState extends State<AvoidListScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('My Avoid List', style: theme.textTheme.titleLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Consumer<UserProfileProvider>(
        builder: (context, profile, _) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.error.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ingredients added here are flagged as harmful in every scan, regardless of your health profile.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: 24),

                // Text input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: false,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Type an ingredient to avoid...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onSubmitted: (val) => _add(context, profile, val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _add(context, profile, _controller.text),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ).animate().slideY(begin: 0.1).fadeIn(delay: 100.ms),

                const SizedBox(height: 24),

                // Avoid list count
                if (profile.manualAvoidList.isNotEmpty) ...[
                  Text(
                    '${profile.manualAvoidList.length} Ingredient${profile.manualAvoidList.length == 1 ? '' : 's'} to Avoid',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                ],

                // Chip grid
                Expanded(
                  child: profile.manualAvoidList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block_rounded, size: 56, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'No ingredients in your avoid list',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add ingredients above to always flag them in scans',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.manualAvoidList.asMap().entries.map((entry) {
                              final item = entry.value;
                              return Chip(
                                label: Text(item),
                                deleteIcon: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.error),
                                onDeleted: () => profile.removeAvoidIngredient(item),
                                backgroundColor: theme.colorScheme.error.withOpacity(0.08),
                                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.2)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ).animate().fadeIn(delay: Duration(milliseconds: 30 * entry.key));
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _add(BuildContext context, UserProfileProvider profile, String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      profile.addAvoidIngredient(trimmed);
      _controller.clear();
    }
  }
}
