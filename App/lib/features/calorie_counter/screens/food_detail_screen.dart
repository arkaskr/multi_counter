import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/food_models.dart';
import '../models/meal_log_model.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';
import '../widgets/food_illustration.dart';

/// Screen 4: Food Details & Serving Selection.
///
/// If [selectionOnly] is true, pops back with `{food, serving, servingCount}`
/// instead of logging directly (used by Multi-Food Add Meal & AI Replace Food).
class FoodDetailScreen extends ConsumerStatefulWidget {
  final FoodItem food;
  final MealCategory initialMealCategory;
  final bool selectionOnly;

  const FoodDetailScreen({
    super.key,
    required this.food,
    this.initialMealCategory = MealCategory.lunch,
    this.selectionOnly = false,
  });

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  late FoodServing _selectedServing;
  double _servingCount = 1.0;
  late MealCategory _mealCategory;
  late bool _isFavorite;
  bool _isSaving = false;
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _selectedServing = widget.food.defaultServing;
    _mealCategory = widget.initialMealCategory;
    _isFavorite = widget.food.isFavorite;
    _qtyController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _setCount(double count) {
    final safe = count.clamp(0.25, 20.0);
    setState(() {
      _servingCount = safe;
      _qtyController.text =
          safe == safe.roundToDouble() ? safe.toInt().toString() : safe.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    });
  }

  Future<void> _toggleFav() async {
    final userId = ref.read(nutritionUserIdProvider);
    final nowFav = await ref
        .read(foodCatalogueServiceProvider)
        .toggleFavorite(userId, widget.food.id);
    if (mounted) {
      setState(() => _isFavorite = nowFav);
    }
  }

  Future<void> _submit() async {
    if (!widget.food.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unverified foods cannot be logged until approved.'),
        ),
      );
      return;
    }
    if (widget.selectionOnly) {
      Navigator.of(context).pop({
        'food': widget.food,
        'serving': _selectedServing,
        'servingCount': _servingCount,
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(dailyDashboardProvider.notifier).logFood(
            mealCategory: _mealCategory,
            foodId: widget.food.id,
            servingId: _selectedServing.id,
            servingCount: _servingCount,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${widget.food.name} to ${_mealCategory.label}'),
          backgroundColor: NutritionAccentPalette.softGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log food: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final calc = NutritionCalculator.calculateForServing(
      per100g: widget.food.nutritionPer100g,
      serving: _selectedServing,
      servingCount: _servingCount,
    );

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
          'Food Details',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Remove favorite' : 'Favorite food',
            onPressed: _toggleFav,
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? NutritionAccentPalette.fatCoral : theme.secondaryText,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card with 2D illustration & preparation variant
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FoodIllustration(
                    illustrationId: widget.food.illustrationId,
                    categoryId: widget.food.categoryId,
                    size: 68,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.food.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                        if (widget.food.preparationState.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.food.preparationState,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _badge(
                              widget.food.isVerified
                                  ? 'Verified Data'
                                  : 'Unverified',
                              widget.food.isVerified
                                  ? NutritionAccentPalette.softGreen
                                  : NutritionAccentPalette.fatCoral,
                            ),
                            if (!widget.food.isComplete)
                              _badge(
                                'Partial Micronutrients',
                                NutritionAccentPalette.carbsAmber,
                              ),
                            for (final tag in widget.food.dietaryTags)
                              _badge(tag.toUpperCase(), theme.accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Serving selector
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Serving & Quantity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.food.servings.map((serving) {
                      final selected = serving.id == _selectedServing.id;
                      return ChoiceChip(
                        label: Text(
                          '${serving.label} (${serving.gramsPerUnit.round()}g)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : theme.text,
                          ),
                        ),
                        selected: selected,
                        selectedColor: NutritionAccentPalette.warmOrange,
                        backgroundColor: theme.surface,
                        onSelected: (_) {
                          setState(() => _selectedServing = serving);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Quantity:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                      const Spacer(),
                      _stepperBtn(Icons.remove_rounded,
                          () => _setCount(_servingCount - 0.5)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 68,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.text,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            if (parsed != null && parsed > 0 && parsed <= 50) {
                              setState(() => _servingCount = parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _stepperBtn(Icons.add_rounded,
                          () => _setCount(_servingCount + 0.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total weight: ${calc.totalGrams.toStringAsFixed(0)} g',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.secondaryText,
                    ),
                  ),
                  if (!widget.selectionOnly) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Meal Category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: MealCategory.values.map((cat) {
                        final selected = cat == _mealCategory;
                        return ChoiceChip(
                          label: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : theme.text,
                            ),
                          ),
                          selected: selected,
                          selectedColor: NutritionAccentPalette.softGreen,
                          backgroundColor: theme.surface,
                          onSelected: (_) => setState(() => _mealCategory = cat),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Live Nutrient Breakdown
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Calculated Nutrition',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                        ),
                      ),
                      Text(
                        '${calc.calories.round()} kcal',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: NutritionAccentPalette.warmOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _macroTile(
                          theme,
                          'Protein',
                          '${calc.protein.toStringAsFixed(1)} g',
                          NutritionAccentPalette.proteinBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _macroTile(
                          theme,
                          'Carbs',
                          '${calc.carbs.toStringAsFixed(1)} g',
                          NutritionAccentPalette.carbsAmber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _macroTile(
                          theme,
                          'Fat',
                          '${calc.fat.toStringAsFixed(1)} g',
                          NutritionAccentPalette.fatCoral,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _macroTile(
                          theme,
                          'Fibre',
                          '${calc.fibre.toStringAsFixed(1)} g',
                          NutritionAccentPalette.fibreTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  _microRow(theme, 'Sugar', calc.sugar, 'g'),
                  _microRow(theme, 'Saturated Fat', calc.saturatedFat, 'g'),
                  _microRow(theme, 'Sodium', calc.sodiumMg, 'mg'),
                  _microRow(theme, 'Potassium', calc.potassiumMg, 'mg'),
                  _microRow(theme, 'Calcium', calc.calciumMg, 'mg'),
                  _microRow(theme, 'Iron', calc.ironMg, 'mg'),
                  _microRow(theme, 'Vitamin C', calc.vitaminCMg, 'mg'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Data source & accuracy citation
            NeumorphicContainer(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source & Verification',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.food.sourceName}\n${widget.food.sourceReference}',
                    style: TextStyle(fontSize: 12, color: theme.secondaryText),
                  ),
                  if (widget.food.verificationNotes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.food.verificationNotes,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                  if (widget.food.allergenTags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Allergens: ${widget.food.allergenTags.join(', ')}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: NutritionAccentPalette.fatCoral,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            NeumorphicButton(
              isEnabled: !_isSaving && widget.food.isVerified,
              color: NutritionAccentPalette.warmOrange,
              onTap: _submit,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _isSaving
                      ? 'Saving...'
                      : (widget.selectionOnly
                          ? 'Select Food (${calc.calories.round()} kcal)'
                          : 'Log to ${_mealCategory.label} (${calc.calories.round()} kcal)'),
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return NeumorphicButton(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      borderRadius: 10,
      child: Icon(icon, size: 18, color: context.appTheme.text),
    );
  }

  Widget _macroTile(
      AppThemeData theme, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _microRow(
      AppThemeData theme, String label, double? value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: theme.secondaryText)),
          Text(
            value == null ? 'Not reported' : '${value.toStringAsFixed(1)} $unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: value == null ? theme.secondaryText : theme.text,
            ),
          ),
        ],
      ),
    );
  }
}

