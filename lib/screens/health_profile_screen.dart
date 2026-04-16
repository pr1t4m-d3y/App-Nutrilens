import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';

class HealthProfileScreen extends StatelessWidget {
  const HealthProfileScreen({super.key});

  // ─── Predefined options for each section ───
  static const _allergyOptions = [
    'Peanuts', 'Tree Nuts', 'Milk', 'Eggs', 'Wheat', 'Gluten',
    'Soy', 'Fish', 'Shellfish', 'Sesame', 'Mustard', 'Lactose',
  ];

  static const _conditionOptions = [
    'Diabetes Type 1', 'Diabetes Type 2', 'Hypertension', 'High Cholesterol',
    'PCOS', 'Thyroid Disorder', 'Celiac Disease', 'IBS', 'Kidney Disease', 'Anemia',
  ];

  static const _skinOptions = [
    'Paraben', 'SLS/SLES', 'Fragrance', 'Formaldehyde', 'Phthalates',
    'Mineral Oil', 'Silicones', 'Alcohol', 'Sulfates', 'Retinol',
  ];

  static const _goalOptions = [
    'Weight Loss', 'Weight Gain', 'Muscle Building', 'Heart Health',
    'Better Digestion', 'Clean Eating', 'Low Sugar', 'High Protein',
  ];

  static const _medicationOptions = [
    'Metformin', 'Amlodipine', 'Aspirin', 'Atorvastatin', 'Levothyroxine',
    'Insulin', 'Omeprazole', 'Lisinopril',
  ];

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
        title: Text('Health Profile', style: theme.textTheme.titleLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Consumer<UserProfileProvider>(
        builder: (context, profile, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120, top: 16),
            child: Column(
              children: [
                Text(
                  'Your profile is used by NutriLens AI to personalize food scanning results.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                _ChipSection(
                  title: 'Food Allergies & Intolerances',
                  icon: Icons.no_food_rounded,
                  presetOptions: _allergyOptions,
                  selectedItems: profile.allergies,
                  onToggle: (item, selected) {
                    if (selected) {
                      profile.allergies.add(item);
                    } else {
                      profile.allergies.remove(item);
                    }
                    profile.notifyListeners();
                  },
                  onAddCustom: (val) {
                    if (!profile.allergies.contains(val)) {
                      profile.allergies.add(val);
                      profile.notifyListeners();
                    }
                  },
                ).animate().slideX(begin: 0.1, end: 0).fadeIn(),
                const SizedBox(height: 20),
                
                _ChipSection(
                  title: 'Skin & Cosmetic Sensitivities',
                  icon: Icons.spa_rounded,
                  presetOptions: _skinOptions,
                  selectedItems: profile.skinSensitivities,
                  onToggle: (item, selected) {
                    if (selected) {
                      profile.skinSensitivities.add(item);
                    } else {
                      profile.skinSensitivities.remove(item);
                    }
                    profile.notifyListeners();
                  },
                  onAddCustom: (val) {
                    if (!profile.skinSensitivities.contains(val)) {
                      profile.skinSensitivities.add(val);
                      profile.notifyListeners();
                    }
                  },
                ).animate().slideX(begin: 0.1, end: 0, delay: 100.ms).fadeIn(delay: 100.ms),
                const SizedBox(height: 20),
                
                _ChipSection(
                  title: 'Health & Nutrition Conditions',
                  icon: Icons.monitor_heart_rounded,
                  presetOptions: _conditionOptions,
                  selectedItems: profile.conditions,
                  onToggle: (item, selected) {
                    if (selected) {
                      profile.conditions.add(item);
                    } else {
                      profile.conditions.remove(item);
                    }
                    profile.notifyListeners();
                  },
                  onAddCustom: (val) {
                    if (!profile.conditions.contains(val)) {
                      profile.conditions.add(val);
                      profile.notifyListeners();
                    }
                  },
                ).animate().slideX(begin: 0.1, end: 0, delay: 200.ms).fadeIn(delay: 200.ms),
                const SizedBox(height: 20),

                _ChipSection(
                  title: 'Health Goals',
                  icon: Icons.flag_rounded,
                  presetOptions: _goalOptions,
                  selectedItems: profile.goals,
                  onToggle: (item, selected) {
                    if (selected) {
                      profile.goals.add(item);
                    } else {
                      profile.goals.remove(item);
                    }
                    profile.notifyListeners();
                  },
                  onAddCustom: (val) {
                    if (!profile.goals.contains(val)) {
                      profile.goals.add(val);
                      profile.notifyListeners();
                    }
                  },
                ).animate().slideX(begin: 0.1, end: 0, delay: 300.ms).fadeIn(delay: 300.ms),
                const SizedBox(height: 20),

                _ChipSection(
                  title: 'Current Medications',
                  icon: Icons.medication_rounded,
                  presetOptions: _medicationOptions,
                  selectedItems: profile.medications,
                  onToggle: (item, selected) {
                    if (selected) {
                      profile.medications.add(item);
                    } else {
                      profile.medications.remove(item);
                    }
                    profile.notifyListeners();
                  },
                  onAddCustom: (val) {
                    if (!profile.medications.contains(val)) {
                      profile.medications.add(val);
                      profile.notifyListeners();
                    }
                  },
                ).animate().slideX(begin: 0.1, end: 0, delay: 400.ms).fadeIn(delay: 400.ms),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}


// ─── Chip-based Section with Presets + Custom Add ───
class _ChipSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> presetOptions;
  final List<String> selectedItems;
  final Function(String item, bool selected) onToggle;
  final Function(String) onAddCustom;

  const _ChipSection({
    required this.title,
    required this.icon,
    required this.presetOptions,
    required this.selectedItems,
    required this.onToggle,
    required this.onAddCustom,
  });

  @override
  State<_ChipSection> createState() => _ChipSectionState();
}

class _ChipSectionState extends State<_ChipSection> {
  bool _isExpanded = false;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = widget.selectedItems.length;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isExpanded
              ? theme.colorScheme.primaryContainer.withOpacity(0.15)
              : (theme.cardTheme.color ?? theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isExpanded
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.colorScheme.outlineVariant.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${widget.title} ($selectedCount)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _isExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: _isExpanded ? null : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preset chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // All preset options
                          ...widget.presetOptions.map((option) {
                            final isSelected = widget.selectedItems.contains(option);
                            return FilterChip(
                              label: Text(option),
                              selected: isSelected,
                              onSelected: (selected) {
                                widget.onToggle(option, selected);
                              },
                              selectedColor: theme.colorScheme.primaryContainer,
                              checkmarkColor: theme.colorScheme.primary,
                              backgroundColor: theme.colorScheme.surface,
                              side: BorderSide(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(0.3)
                                    : theme.colorScheme.outlineVariant.withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            );
                          }),
                          // Custom items not in presets
                          ...widget.selectedItems
                              .where((item) => !widget.presetOptions.contains(item))
                              .map((item) {
                            return FilterChip(
                              label: Text(item),
                              selected: true,
                              onSelected: (selected) {
                                widget.onToggle(item, false);
                              },
                              selectedColor: theme.colorScheme.primaryContainer,
                              checkmarkColor: theme.colorScheme.primary,
                              deleteIcon: Icon(Icons.close, size: 16, color: theme.colorScheme.primary),
                              onDeleted: () => widget.onToggle(item, false),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Custom text input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customController,
                              decoration: InputDecoration(
                                hintText: 'Add custom...',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              style: theme.textTheme.bodyMedium,
                              onSubmitted: _addCustom,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _addCustom(_customController.text),
                            icon: Icon(Icons.add_circle_rounded, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustom(String value) {
    if (value.trim().isNotEmpty) {
      widget.onAddCustom(value.trim());
      _customController.clear();
    }
  }
}


// ─── Custom Avoid List (Free text only) ───
class _AvoidListSection extends StatefulWidget {
  final List<String> items;
  final Function(String) onAdd;
  final Function(String) onRemove;

  const _AvoidListSection({
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_AvoidListSection> createState() => _AvoidListSectionState();
}

class _AvoidListSectionState extends State<_AvoidListSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_rounded, color: theme.colorScheme.error, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Custom Avoid List',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add specific ingredients you want to avoid (e.g., "Palm Oil", "Wheat")',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Tags
          if (widget.items.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.items.map((item) {
                return Chip(
                  label: Text(item),
                  deleteIcon: Icon(Icons.close, size: 16, color: theme.colorScheme.error),
                  onDeleted: () => widget.onRemove(item),
                  backgroundColor: theme.colorScheme.error.withOpacity(0.08),
                  side: BorderSide(color: theme.colorScheme.error.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Text input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type ingredient to avoid...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  style: theme.textTheme.bodyMedium,
                  onSubmitted: _add,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _add(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _add(String value) {
    if (value.trim().isNotEmpty) {
      widget.onAdd(value.trim());
      _controller.clear();
    }
  }
}
