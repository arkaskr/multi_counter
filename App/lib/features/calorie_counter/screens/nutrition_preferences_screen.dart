import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/food_models.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';
import 'food_search_screen.dart';

/// Screen 10: User Nutrition Preferences (Diet, Allergies, Excluded Foods, Timings, Objective).
class NutritionPreferencesScreen extends ConsumerStatefulWidget {
  const NutritionPreferencesScreen({super.key});

  @override
  ConsumerState<NutritionPreferencesScreen> createState() =>
      _NutritionPreferencesScreenState();
}

class _NutritionPreferencesScreenState
    extends ConsumerState<NutritionPreferencesScreen> {
  static const List<String> _commonAllergens = [
    'dairy',
    'gluten',
    'wheat',
    'nuts',
    'peanuts',
    'soy',
    'egg',
    'fish',
    'sesame',
  ];

  String _diet = 'vegetarian';
  String _objective = 'maintain_weight';
  String _activity = 'moderate';
  Set<String> _allergies = {};
  List<String> _excludedIds = [];
  Map<String, String> _timings = {
    'breakfast': '08:00',
    'morning_snack': '11:00',
    'lunch': '13:30',
    'evening_snack': '17:00',
    'dinner': '20:30',
  };
  final _allergyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final userId = ref.read(nutritionUserIdProvider);
    final prefs =
        await ref.read(nutritionGoalServiceProvider).getPreferences(userId);
    if (!mounted) return;
    setState(() {
      _diet = prefs.dietaryPreference;
      _objective = prefs.fitnessObjective;
      _activity = prefs.activityLevel;
      _allergies = prefs.allergies.map((e) => e.toLowerCase()).toSet();
      _excludedIds = List<String>.from(prefs.excludedFoodIds);
      _timings = Map<String, String>.from(prefs.preferredMealTimings);
    });
  }

  @override
  void dispose() {
    _allergyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addExcludedFood() async {
    final picked = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => const FoodSearchScreen(selectionOnly: true),
      ),
    );
    if (picked is Map && mounted) {
      final food = picked['food'] as FoodItem;
      if (!_excludedIds.contains(food.id)) {
        setState(() => _excludedIds.add(food.id));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = ref.read(nutritionUserIdProvider);
      final current =
          await ref.read(nutritionGoalServiceProvider).getPreferences(userId);
      final updated = current.copyWith(
        dietaryPreference: _diet,
        fitnessObjective: _objective,
        activityLevel: _activity,
        allergies: _allergies.toList()..sort(),
        excludedFoodIds: _excludedIds,
        preferredMealTimings: _timings,
      );
      await ref.read(dailyDashboardProvider.notifier).savePreferences(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nutrition preferences updated.'),
          backgroundColor: NutritionAccentPalette.softGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Nutrition Preferences',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dietary Preference',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: theme.text)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      ('vegetarian', 'Vegetarian'),
                      ('eggetarian', 'Eggetarian'),
                      ('non_vegetarian', 'Non-Vegetarian'),
                      ('vegan', 'Vegan'),
                    ].map((opt) {
                      final selected = _diet == opt.$1;
                      return ChoiceChip(
                        label: Text(
                          opt.$2,
                          style: TextStyle(
                            color: selected ? Colors.white : theme.text,
                            fontSize: 12,
                          ),
                        ),
                        selected: selected,
                        selectedColor: NutritionAccentPalette.softGreen,
                        backgroundColor: theme.surface,
                        onSelected: (_) => setState(() => _diet = opt.$1),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Fitness Objective',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: theme.text)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _objective,
                    dropdownColor: theme.surface,
                    style: TextStyle(color: theme.text),
                    items: const [
                      DropdownMenuItem(
                          value: 'maintain_weight',
                          child: Text('Maintain Weight')),
                      DropdownMenuItem(
                          value: 'lose_weight', child: Text('Lose Weight')),
                      DropdownMenuItem(
                          value: 'gain_weight', child: Text('Gain Weight')),
                      DropdownMenuItem(
                          value: 'improve_nutrition',
                          child: Text('Improve General Nutrition')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _objective = v);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Allergies & Intolerances',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: theme.text)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: {
                      ..._commonAllergens,
                      ..._allergies,
                    }.map((allergen) {
                      final selected = _allergies.contains(allergen);
                      return FilterChip(
                        label: Text(allergen,
                            style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : theme.text)),
                        selected: selected,
                        selectedColor: NutritionAccentPalette.fatCoral,
                        backgroundColor: theme.surface,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _allergies.add(allergen);
                            } else {
                              _allergies.remove(allergen);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _allergyCtrl,
                          style: TextStyle(color: theme.text),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Add custom allergen...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NeumorphicButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        onTap: () {
                          final val = _allergyCtrl.text.trim().toLowerCase();
                          if (val.isNotEmpty) {
                            setState(() => _allergies.add(val));
                            _allergyCtrl.clear();
                          }
                        },
                        child: Text('Add',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: theme.text)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Excluded Foods',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: theme.text)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addExcludedFood,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Exclude Food'),
                      ),
                    ],
                  ),
                  if (_excludedIds.isEmpty)
                    Text('No specific foods excluded.',
                        style: TextStyle(
                            fontSize: 12, color: theme.secondaryText))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _excludedIds.map((fid) {
                        return Chip(
                          label: Text(fid,
                              style: TextStyle(fontSize: 11, color: theme.text)),
                          onDeleted: () =>
                              setState(() => _excludedIds.remove(fid)),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preferred Meal Timings',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: theme.text)),
                  const SizedBox(height: 8),
                  ...const [
                    ('breakfast', 'Breakfast'),
                    ('morning_snack', 'Morning Snack'),
                    ('lunch', 'Lunch'),
                    ('evening_snack', 'Evening Snack'),
                    ('dinner', 'Dinner'),
                  ].map((entry) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.$2, style: TextStyle(color: theme.text)),
                      trailing: TextButton(
                        onPressed: () async {
                          final parts = (_timings[entry.$1] ?? '09:00').split(':');
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.tryParse(parts[0]) ?? 9,
                              minute: int.tryParse(parts[1]) ?? 0,
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _timings[entry.$1] =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                        child: Text(
                          _timings[entry.$1] ?? '09:00',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NutritionAccentPalette.warmOrange,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),

            NeumorphicButton(
              isEnabled: !_saving,
              color: NutritionAccentPalette.warmOrange,
              padding: const EdgeInsets.symmetric(vertical: 15),
              onTap: _save,
              child: Center(
                child: Text(
                  _saving ? 'Saving...' : 'Save Preferences',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
