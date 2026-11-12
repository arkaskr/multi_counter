import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/nutrition_goal_models.dart';
import '../providers/calorie_providers.dart';
import '../services/nutrition_analytics_service.dart';
import '../widgets/calorie_progress_ring.dart';

/// Screen 8: Daily Goal Setup + Optional Guided BMR/TDEE Estimator with disclaimer.
class DailyGoalSetupScreen extends ConsumerStatefulWidget {
  const DailyGoalSetupScreen({super.key});

  @override
  ConsumerState<DailyGoalSetupScreen> createState() =>
      _DailyGoalSetupScreenState();
}

class _DailyGoalSetupScreenState extends ConsumerState<DailyGoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fibreCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();

  // Optional Guided Calculator fields
  bool _showGuided = false;
  final _ageCtrl = TextEditingController(text: '26');
  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '68');
  String _sex = 'male';
  String _activity = 'moderate';
  String _objective = 'maintain_weight';
  String _sourceMode = 'manual';
  bool _saving = false;
  String? _guidedNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _populateInitial());
  }

  void _populateInitial() {
    final state = ref.read(dailyDashboardProvider).value;
    if (state == null) return;
    final g = state.goal;
    final p = state.preferences;
    _calCtrl.text = g.calories.round().toString();
    _protCtrl.text = g.protein.round().toString();
    _carbsCtrl.text = g.carbs.round().toString();
    _fatCtrl.text = g.fat.round().toString();
    _fibreCtrl.text = g.fibre.round().toString();
    _waterCtrl.text = (g.hydrationMl ?? 2500).toString();
    _sourceMode = g.sourceMode;

    if (p.age != null) _ageCtrl.text = p.age.toString();
    if (p.heightCm != null) _heightCtrl.text = p.heightCm!.round().toString();
    if (p.weightKg != null) _weightCtrl.text = p.weightKg!.round().toString();
    if (p.sex != null) _sex = p.sex!;
    _activity = p.activityLevel;
    _objective = p.fitnessObjective;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fibreCtrl.dispose();
    _waterCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _runGuidedEstimate() {
    final age = int.tryParse(_ageCtrl.text) ?? 26;
    final h = double.tryParse(_heightCtrl.text) ?? 170;
    final w = double.tryParse(_weightCtrl.text) ?? 68;
    final estimate = NutritionGoalCalculator.suggestTargets(
      age: age,
      sex: _sex,
      heightCm: h,
      weightKg: w,
      activityLevel: _activity,
      fitnessObjective: _objective,
    );
    setState(() {
      _calCtrl.text = estimate.calories.round().toString();
      _protCtrl.text = estimate.protein.round().toString();
      _carbsCtrl.text = estimate.carbs.round().toString();
      _fatCtrl.text = estimate.fat.round().toString();
      _fibreCtrl.text = estimate.fibre.round().toString();
      _waterCtrl.text = estimate.hydrationMl.toString();
      _sourceMode = 'guided';
      _guidedNote =
          'Estimated TDEE ~${estimate.estimatedTdee.round()} kcal.${estimate.safetyFloorApplied ? ' Minimum safe calorie floor applied.' : ''} You can freely customize these numbers.';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final today = NutritionAnalyticsService.formatDate(DateTime.now());
      await ref.read(dailyDashboardProvider.notifier).saveDailyGoal(
            effectiveFromDate: today,
            calories: double.parse(_calCtrl.text),
            protein: double.parse(_protCtrl.text),
            carbs: double.parse(_carbsCtrl.text),
            fat: double.parse(_fatCtrl.text),
            fibre: double.parse(_fibreCtrl.text),
            hydrationMl: int.tryParse(_waterCtrl.text),
            sourceMode: _sourceMode,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily nutrition goals saved (previous history preserved).'),
          backgroundColor: NutritionAccentPalette.softGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid target: $e')),
      );
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
          'Daily Goals Setup',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Guided estimator toggle
            NeumorphicButton(
              onTap: () => setState(() => _showGuided = !_showGuided),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.calculate_rounded,
                      color: NutritionAccentPalette.warmOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Guided Goal Estimator (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                  ),
                  Icon(
                    _showGuided
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: theme.secondaryText,
                  ),
                ],
              ),
            ),

            if (_showGuided) ...[
              const SizedBox(height: 12),
              NeumorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: NutritionAccentPalette.carbsAmber
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        NutritionGoalCalculator.nonMedicalDisclaimer,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.text),
                            decoration: const InputDecoration(labelText: 'Age'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _sex,
                            dropdownColor: theme.surface,
                            style: TextStyle(color: theme.text),
                            decoration: const InputDecoration(labelText: 'Sex'),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(
                                  value: 'female', child: Text('Female')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Other')),
                            ],
                            onChanged: (v) => setState(() => _sex = v ?? 'male'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.text),
                            decoration:
                                const InputDecoration(labelText: 'Height (cm)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _weightCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.text),
                            decoration:
                                const InputDecoration(labelText: 'Weight (kg)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _activity,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.text),
                      decoration:
                          const InputDecoration(labelText: 'Activity Level'),
                      items: const [
                        DropdownMenuItem(
                            value: 'sedentary', child: Text('Sedentary')),
                        DropdownMenuItem(
                            value: 'light', child: Text('Lightly Active')),
                        DropdownMenuItem(
                            value: 'moderate', child: Text('Moderately Active')),
                        DropdownMenuItem(
                            value: 'active', child: Text('Very Active')),
                        DropdownMenuItem(
                            value: 'very_active', child: Text('Athlete')),
                      ],
                      onChanged: (v) =>
                          setState(() => _activity = v ?? 'moderate'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _objective,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.text),
                      decoration:
                          const InputDecoration(labelText: 'Fitness Objective'),
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
                      onChanged: (v) =>
                          setState(() => _objective = v ?? 'maintain_weight'),
                    ),
                    const SizedBox(height: 14),
                    NeumorphicButton(
                      color: NutritionAccentPalette.softGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onTap: _runGuidedEstimate,
                      child: const Center(
                        child: Text(
                          'Calculate Suggested Targets',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (_guidedNote != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _guidedNote!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Editable Daily Targets',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _numField(theme, _calCtrl, 'Daily Calories (kcal)', 800, 10000),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _numField(theme, _protCtrl, 'Protein (g)', 20, 500)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _numField(theme, _carbsCtrl, 'Carbs (g)', 20, 900)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _numField(theme, _fatCtrl, 'Fat (g)', 15, 400)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _numField(theme, _fibreCtrl, 'Fibre (g)', 5, 150)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _numField(
                        theme, _waterCtrl, 'Hydration Target (ml, optional)', 0, 10000,
                        requiredField: false),
                    const SizedBox(height: 10),
                    Text(
                      'Updating targets takes effect from today onward without altering historical records.',
                      style: TextStyle(fontSize: 11, color: theme.secondaryText),
                    ),
                    const SizedBox(height: 16),
                    NeumorphicButton(
                      isEnabled: !_saving,
                      color: NutritionAccentPalette.warmOrange,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      onTap: _save,
                      child: Center(
                        child: Text(
                          _saving ? 'Saving...' : 'Save Daily Goals',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(
    AppThemeData theme,
    TextEditingController ctrl,
    String label,
    double min,
    double max, {
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: TextStyle(color: theme.text),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (!requiredField && (v == null || v.trim().isEmpty)) return null;
        final val = double.tryParse(v ?? '');
        if (val == null || val < min || val > max) {
          return '$min–$max';
        }
        return null;
      },
    );
  }
}

