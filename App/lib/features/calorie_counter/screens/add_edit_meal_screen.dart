import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/food_models.dart';
import '../models/meal_log_model.dart';
import '../providers/calorie_providers.dart';
import '../services/meal_log_service.dart';
import '../services/nutrition_analytics_service.dart';
import '../widgets/calorie_progress_ring.dart';
import '../widgets/food_illustration.dart';
import 'food_search_screen.dart';

class _DraftMealItem {
  final FoodItem food;
  FoodServing serving;
  double servingCount;

  _DraftMealItem({
    required this.food,
    required this.serving,
    required this.servingCount,
  });

  CalculatedNutrition get calculated => NutritionCalculator.calculateForServing(
        per100g: food.nutritionPer100g,
        serving: serving,
        servingCount: servingCount,
      );
}

/// Screen 5: Add multiple foods to a meal, Duplicate a previous meal,
/// OR Edit an existing logged food entry (quantity, serving, meal category, delete).
class AddEditMealScreen extends ConsumerStatefulWidget {
  final MealCategory initialMealCategory;
  final FoodLog? existingLog;

  const AddEditMealScreen({
    super.key,
    this.initialMealCategory = MealCategory.lunch,
    this.existingLog,
  });

  @override
  ConsumerState<AddEditMealScreen> createState() => _AddEditMealScreenState();
}

class _AddEditMealScreenState extends ConsumerState<AddEditMealScreen> {
  late MealCategory _mealCategory;
  final List<_DraftMealItem> _draftItems = [];

  // Edit mode state
  FoodItem? _existingFood;
  String? _editServingId;
  double _editCount = 1.0;
  bool _saving = false;

  bool get isEditMode => widget.existingLog != null;

  @override
  void initState() {
    super.initState();
    _mealCategory = widget.existingLog?.mealCategory ?? widget.initialMealCategory;
    if (isEditMode) {
      _editServingId = widget.existingLog!.servingId;
      _editCount = widget.existingLog!.servingCount;
      _loadExistingFood();
    }
  }

  Future<void> _loadExistingFood() async {
    final userId = ref.read(nutritionUserIdProvider);
    final food = await ref
        .read(foodCatalogueServiceProvider)
        .getFoodById(widget.existingLog!.foodId, userId: userId);
    if (mounted) {
      setState(() => _existingFood = food);
    }
  }

  Future<void> _pickAndAddFood() async {
    final picked = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          initialMealCategory: _mealCategory,
          selectionOnly: true,
        ),
      ),
    );
    if (picked is Map && mounted) {
      final food = picked['food'] as FoodItem;
      final serving = picked['serving'] as FoodServing;
      final count = picked['servingCount'] as double;
      setState(() {
        _draftItems.add(_DraftMealItem(
          food: food,
          serving: serving,
          servingCount: count,
        ));
      });
    }
  }

  Future<void> _duplicateFromPreviousDay() async {
    final selectedDate = ref.read(selectedCalorieDateProvider);
    final yesterday =
        NutritionAnalyticsService.formatDate(selectedDate.subtract(const Duration(days: 1)));

    final chosen = await showDialog<({String date, MealCategory meal})>(
      context: context,
      builder: (ctx) => _DuplicateMealDialog(
        defaultFromDate: yesterday,
        defaultFromMeal: _mealCategory,
      ),
    );
    if (chosen == null) return;

    setState(() => _saving = true);
    try {
      final count = await ref.read(dailyDashboardProvider.notifier).duplicateMeal(
            fromDate: chosen.date,
            fromMeal: chosen.meal,
            toMeal: _mealCategory,
          );
      if (!mounted) return;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No items found for ${chosen.meal.label} on ${chosen.date}.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicated $count item(s) to ${_mealCategory.label}.'),
            backgroundColor: NutritionAccentPalette.softGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBatch() async {
    if (_draftItems.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(dailyDashboardProvider.notifier).logMultipleFoods(
            mealCategory: _mealCategory,
            items: _draftItems
                .map((d) => MealLogInput(
                      foodId: d.food.id,
                      servingId: d.serving.id,
                      servingCount: d.servingCount,
                    ))
                .toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging meal: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveEdit() async {
    final existing = widget.existingLog!;
    setState(() => _saving = true);
    try {
      await ref.read(dailyDashboardProvider.notifier).updateLogEntry(
            logId: existing.id,
            mealCategory: _mealCategory,
            servingId: _editServingId,
            servingCount: _editCount,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update entry: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEdit() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(dailyDashboardProvider.notifier)
          .deleteLogEntry(widget.existingLog!.id);
      if (!mounted) return;
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
          isEditMode ? 'Edit Logged Food' : 'Add Meal Items',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (isEditMode)
            IconButton(
              tooltip: 'Delete item',
              onPressed: _saving ? null : _deleteEdit,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: NutritionAccentPalette.fatCoral),
            ),
        ],
      ),
      body: SafeArea(
        child: isEditMode ? _buildEditBody(theme) : _buildAddBody(theme),
      ),
    );
  }

  Widget _buildAddBody(AppThemeData theme) {
    final totalCalories =
        _draftItems.fold(0.0, (s, e) => s + e.calculated.calories);
    final totalProtein =
        _draftItems.fold(0.0, (s, e) => s + e.calculated.protein);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NeumorphicContainer(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meal Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: MealCategory.values.map((c) {
                  final selected = c == _mealCategory;
                  return ChoiceChip(
                    label: Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : theme.text,
                      ),
                    ),
                    selected: selected,
                    selectedColor: NutritionAccentPalette.warmOrange,
                    backgroundColor: theme.surface,
                    onSelected: (_) => setState(() => _mealCategory = c),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: NeumorphicButton(
                onTap: _pickAndAddFood,
                padding: const EdgeInsets.symmetric(vertical: 13),
                color: NutritionAccentPalette.softGreen,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Add Food',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NeumorphicButton(
                onTap: _duplicateFromPreviousDay,
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, size: 17, color: theme.text),
                    const SizedBox(width: 6),
                    Text(
                      'Duplicate Meal',
                      style: TextStyle(
                          color: theme.text, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_draftItems.isEmpty)
          NeumorphicContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.restaurant_menu_rounded,
                    size: 40, color: theme.secondaryText),
                const SizedBox(height: 8),
                Text(
                  'Tap "Add Food" to build a multi-item meal or "Duplicate Meal" to copy from another day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
              ],
            ),
          )
        else ...[
          for (var i = 0; i < _draftItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeumorphicContainer(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    FoodIllustration(
                      illustrationId: _draftItems[i].food.illustrationId,
                      categoryId: _draftItems[i].food.categoryId,
                      size: 42,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _draftItems[i].food.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                            ),
                          ),
                          Text(
                            '${_draftItems[i].servingCount} × ${_draftItems[i].serving.label} • ${_draftItems[i].calculated.calories.round()} kcal',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: NutritionAccentPalette.fatCoral),
                      onPressed: () {
                        setState(() => _draftItems.removeAt(i));
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          NeumorphicContainer(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_draftItems.length} item(s) • Protein ${totalProtein.toStringAsFixed(1)} g',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.secondaryText,
                  ),
                ),
                Text(
                  '${totalCalories.round()} kcal',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: NutritionAccentPalette.warmOrange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          NeumorphicButton(
            isEnabled: !_saving,
            color: NutritionAccentPalette.warmOrange,
            padding: const EdgeInsets.symmetric(vertical: 15),
            onTap: _saveBatch,
            child: Center(
              child: Text(
                _saving
                    ? 'Logging...'
                    : 'Log All to ${_mealCategory.label}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditBody(AppThemeData theme) {
    final log = widget.existingLog!;
    final servings = _existingFood?.servings ??
        [
          FoodServing(
            id: log.servingId,
            foodId: log.foodId,
            label: log.servingLabelSnapshot,
            unitType: 'unit',
            gramsPerUnit: log.gramsPerUnit,
            isDefault: true,
            sortOrder: 0,
          )
        ];

    FoodServing currentServing = servings.first;
    for (final s in servings) {
      if (s.id == _editServingId) {
        currentServing = s;
        break;
      }
    }

    final previewCalories = _existingFood != null
        ? NutritionCalculator.calculateForServing(
            per100g: _existingFood!.nutritionPer100g,
            serving: currentServing,
            servingCount: _editCount,
          ).calories
        : log.calories *
            ((_editCount * log.gramsPerUnit) /
                (log.totalGrams > 0 ? log.totalGrams : 1));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NeumorphicContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              FoodIllustration(
                illustrationId: log.illustrationSnapshot,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.foodNameSnapshot,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                    Text(
                      'Logged at ${log.date}',
                      style: TextStyle(fontSize: 12, color: theme.secondaryText),
                    ),
                  ],
                ),
              ),
              Text(
                '${previewCalories.round()} kcal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NutritionAccentPalette.warmOrange,
                ),
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
              Text(
                'Serving Unit',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: theme.text),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: servings.map((s) {
                  final selected = s.id == _editServingId;
                  return ChoiceChip(
                    label: Text(
                      '${s.label} (${s.gramsPerUnit.round()}g)',
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : theme.text,
                      ),
                    ),
                    selected: selected,
                    selectedColor: NutritionAccentPalette.warmOrange,
                    backgroundColor: theme.surface,
                    onSelected: (_) => setState(() => _editServingId = s.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Quantity:',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: theme.text)),
                  const Spacer(),
                  NeumorphicButton(
                    onTap: () => setState(
                        () => _editCount = (_editCount - 0.5).clamp(0.25, 20.0)),
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.remove_rounded, color: theme.text),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      _editCount.toStringAsFixed(
                          _editCount == _editCount.roundToDouble() ? 0 : 1),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                  ),
                  NeumorphicButton(
                    onTap: () => setState(
                        () => _editCount = (_editCount + 0.5).clamp(0.25, 20.0)),
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.add_rounded, color: theme.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Meal Category',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: theme.text),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: MealCategory.values.map((c) {
                  final selected = c == _mealCategory;
                  return ChoiceChip(
                    label: Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : theme.text,
                      ),
                    ),
                    selected: selected,
                    selectedColor: NutritionAccentPalette.softGreen,
                    backgroundColor: theme.surface,
                    onSelected: (_) => setState(() => _mealCategory = c),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NeumorphicButton(
          isEnabled: !_saving,
          color: NutritionAccentPalette.warmOrange,
          padding: const EdgeInsets.symmetric(vertical: 15),
          onTap: _saveEdit,
          child: Center(
            child: Text(
              _saving ? 'Updating...' : 'Save Changes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DuplicateMealDialog extends StatefulWidget {
  final String defaultFromDate;
  final MealCategory defaultFromMeal;

  const _DuplicateMealDialog({
    required this.defaultFromDate,
    required this.defaultFromMeal,
  });

  @override
  State<_DuplicateMealDialog> createState() => _DuplicateMealDialogState();
}

class _DuplicateMealDialogState extends State<_DuplicateMealDialog> {
  late final TextEditingController _dateCtrl;
  late MealCategory _fromMeal;

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(text: widget.defaultFromDate);
    _fromMeal = widget.defaultFromMeal;
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return AlertDialog(
      backgroundColor: theme.surface,
      title: Text('Duplicate Previous Meal',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _dateCtrl,
            style: TextStyle(color: theme.text),
            decoration: const InputDecoration(
              labelText: 'Source Date (YYYY-MM-DD)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MealCategory>(
            initialValue: _fromMeal,
            dropdownColor: theme.surface,
            style: TextStyle(color: theme.text),
            decoration: const InputDecoration(labelText: 'Source Meal'),
            items: MealCategory.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _fromMeal = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: NutritionAccentPalette.warmOrange,
          ),
          onPressed: () => Navigator.of(context).pop(
            (date: _dateCtrl.text.trim(), meal: _fromMeal),
          ),
          child: const Text('Duplicate', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

