import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

class MedicineReminderScreen extends StatefulWidget {
  const MedicineReminderScreen({super.key});

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  // Mock data for existing reminders
  final List<Map<String, dynamic>> _reminders = [
    {
      'name': 'Vitamin C',
      'startDate': DateTime.now().subtract(const Duration(days: 5)),
      'endDate': DateTime.now().add(const Duration(days: 25)),
      'timings': ['Morning'],
      'times': {'Morning': const TimeOfDay(hour: 8, minute: 30)},
      'frequency': 0, // 0: Daily
      'notes': 'Take with food',
      'active': true,
      'ids': [1001],
    },
    {
      'name': 'Aspirin',
      'startDate': DateTime.now(),
      'endDate': DateTime.now().add(const Duration(days: 10)),
      'timings': ['Evening', 'Night'],
      'times': {
        'Evening': const TimeOfDay(hour: 18, minute: 0),
        'Night': const TimeOfDay(hour: 22, minute: 0)
      },
      'frequency': 1, // 1: Alternate
      'notes': '',
      'active': false,
      'ids': [1002, 1003],
    },
  ];

  void _deleteReminder(int index) {
    setState(() {
      _reminders.removeAt(index);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder deleted')),
      );
    }
  }

  void _showAddMedicineModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMedicineModal(
        onSave: (data) {
          setState(() {
            _reminders.add(data);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF004D40); // Deep green
    final accentColor = const Color(0xFF00BFA5); // Teal

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Medicine Reminders', style: theme.textTheme.titleLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _reminders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication_liquid_rounded, size: 80, color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text('No Reminders', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Add your first medicine reminder below.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 100, left: 24, right: 24),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
                final String name = reminder['name'];
                final List<String> timings = List<String>.from(reminder['timings'] ?? []);
                final Map<String, TimeOfDay> times = Map<String, TimeOfDay>.from(reminder['times'] ?? {});
                
                // Build a nice sub string of times
                final timeStrings = timings.map((t) => times[t]?.format(context) ?? '').join(', ');

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: reminder['active'] 
                                      ? accentColor.withOpacity(0.15)
                                      : theme.colorScheme.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.medication_rounded, 
                                  color: reminder['active'] ? primaryColor : theme.colorScheme.onSurfaceVariant,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, 
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(timeStrings, 
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  Switch(
                                    value: reminder['active'] as bool,
                                    activeColor: primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        reminder['active'] = val;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 20),
                                    onPressed: () => _deleteReminder(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMedicineModal,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _AddMedicineModal extends StatefulWidget {
  final Function(Map<String, dynamic> data) onSave;
  
  const _AddMedicineModal({required this.onSave});

  @override
  State<_AddMedicineModal> createState() => _AddMedicineModalState();
}

class _AddMedicineModalState extends State<_AddMedicineModal> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  
  final Set<String> _selectedTimings = {'Morning'};
  
  final Map<String, TimeOfDay> _specificTimes = {
    'Morning': const TimeOfDay(hour: 8, minute: 0),
    'Afternoon': const TimeOfDay(hour: 13, minute: 0),
    'Evening': const TimeOfDay(hour: 18, minute: 0),
    'Night': const TimeOfDay(hour: 21, minute: 0),
  };
  
  int _frequencyIndex = 0; // 0: Daily, 1: Alternate, 2: Custom

  final Color _primaryGreen = const Color(0xFF3B5B41); // Deep muted green matching reference
  final Color _lightBg = const Color(0xFFF2F4F3);

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final notes = _notesController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medicine name')),
      );
      return;
    }

    if (_selectedTimings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one timing (e.g. Morning)')),
      );
      return;
    }

    widget.onSave({
      'name': name,
      'startDate': _startDate,
      'endDate': _endDate,
      'timings': _selectedTimings.toList(),
      'times': Map<String, TimeOfDay>.from(_specificTimes),
      'frequency': _frequencyIndex,
      'notes': notes,
      'active': true,
      'ids': [],
    });
    
    Navigator.pop(context);
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: _primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate.subtract(const Duration(days: 30));
          }
        }
      });
    }
  }

  Future<void> _pickTime(String timing) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _specificTimes[timing]!,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: _primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _specificTimes[timing] = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add Medicine formatting closely mirrors reference image
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final dateFormat = DateFormat('MMM dd,\nyyyy');
    
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                const Text('Add Medicine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MEDICINE NAME
                  _buildSectionLabel('MEDICINE NAME'),
                  Container(
                    decoration: BoxDecoration(color: _lightBg, borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        hintText: 'e.g. Omega 3 Fish Oil',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 16),
                      ),
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // DURATION
                  _buildSectionLabel('DURATION'),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickDate(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: _lightBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('START DATE', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(dateFormat.format(_startDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                Icon(Icons.calendar_today_rounded, color: _primaryGreen, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickDate(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _primaryGreen.withOpacity(0.3), width: 1.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('END DATE', style: TextStyle(fontSize: 10, color: _primaryGreen, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(dateFormat.format(_endDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                Icon(Icons.calendar_today_rounded, color: _primaryGreen, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // TIMING
                  _buildSectionLabel('TIMING'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildTimingChip('Morning', Icons.wb_sunny_rounded),
                      _buildTimingChip('Afternoon', Icons.wb_twilight_rounded),
                      _buildTimingChip('Evening', Icons.brightness_6_rounded),
                      _buildTimingChip('Night', Icons.nightlight_round),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // SPECIFIC TIME
                  if (_selectedTimings.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionLabel('SPECIFIC TIME'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC5E1A5).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_selectedTimings.length} DOSES SET',
                            style: TextStyle(color: _primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: _lightBg, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: _selectedTimings.map((timing) {
                          return ListTile(
                            title: Text(timing, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_specificTimes[timing]!.format(context), 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                              ),
                            ),
                            onTap: () => _pickTime(timing),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // FREQUENCY
                  _buildSectionLabel('FREQUENCY'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _lightBg, borderRadius: BorderRadius.circular(24)),
                    child: CupertinoSlidingSegmentedControl<int>(
                      backgroundColor: Colors.transparent,
                      thumbColor: Colors.white,
                      groupValue: _frequencyIndex,
                      children: const {
                        0: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Daily', style: TextStyle(fontWeight: FontWeight.w500))),
                        1: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Alternate', style: TextStyle(fontWeight: FontWeight.w500))),
                        2: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Custom', style: TextStyle(fontWeight: FontWeight.w500))),
                      },
                      onValueChanged: (val) {
                        if (val != null) setState(() => _frequencyIndex = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // NOTES
                  _buildSectionLabel('NOTES'),
                  Container(
                    decoration: BoxDecoration(color: _lightBg, borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        hintText: 'Take after breakfast with a full glass of water...',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
          ),
          
          // Save Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 60),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 22),
                    SizedBox(width: 8),
                    Text('Save Medicine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 0.5)),
    );
  }

  Widget _buildTimingChip(String label, IconData icon) {
    final isSelected = _selectedTimings.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTimings.remove(label);
          } else {
            _selectedTimings.add(label);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : _lightBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(width: 8),
            Text(label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
