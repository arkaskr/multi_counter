import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/nutrition_goal_models.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';

/// Screen 9: Independent Monthly Goals Setup (respects actual calendar days including leap years).
class MonthlyGoalSetupScreen extends ConsumerStatefulWidget {
  final int? initialYear;
  final int? initialMonth;

  const MonthlyGoalSetupScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
  });

  @override
  ConsumerState<MonthlyGoalSetupScreen> createState() =>
      _MonthlyGoalSetupScreenState();
}

class _MonthlyGoalSetupScreenState
    extends ConsumerState<MonthlyGoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _year;
  late int _month;

  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fibreCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String get _yearMonth =>
      '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}';

  int get _calendarDays =>
      MonthlyNutritionGoal.daysInCalendarMonth(_year, _month);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = widget.initialYear ?? now.year;
    _month = widget.initialMonth ?? now.month;
    _loadMonthGoal();
  }

  @override
  void dispose() {
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fibreCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMonthGoal() async {
    setState(() => _loading = true);
    final userId = ref.read(nutritionUserIdProvider);
    final goal = await ref
        .read(nutritionGoalServiceProvider)
        .getMonthlyGoal(userId, _yearMonth);

    if (goal != null) {
      _calCtrl.text = goal.totalCalories.round().toString();
      _protCtrl.text = goal.protein?.round().toString() ?? '';
      _carbsCtrl.text = goal.carbs?.round().toString() ?? '';
      _fatCtrl.text = goal.fat?.round().toString() ?? '';
      _fibreCtrl.text = goal.fibre?.round().toString() ?? '';
      _daysCtrl.text = goal.targetDaysWithinGoal?.toString() ?? '';
    } else {
      final daily = ref.read(dailyDashboardProvider).value?.goal.calories ?? 2000;
      _calCtrl.text = (daily * _calendarDays).round().toString();
      _protCtrl.clear();
      _carbsCtrl.clear();
      _fatCtrl.clear();
      _fibreCtrl.clear();
      _daysCtrl.text = (_calendarDays - 4).clamp(1, _calendarDays).toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_year, _month + delta, 1);
    setState(() {
      _year = next.year;
      _month = next.month;
    });
    _loadMonthGoal();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final userId = ref.read(nutritionUserIdProvider);
      await ref.read(nutritionGoalServiceProvider).saveMonthlyGoal(
            userId: userId,
            yearMonth: _yearMonth,
            totalCalories: double.parse(_calCtrl.text),
            protein: double.tryParse(_protCtrl.text),
            carbs: double.tryParse(_carbsCtrl.text),
            fat: double.tryParse(_fatCtrl.text),
            fibre: double.tryParse(_fibreCtrl.text),
            targetDaysWithinGoal: int.tryParse(_daysCtrl.text),
          );
      ref.invalidate(nutritionAnalyticsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Independent monthly goal saved for $_yearMonth.'),
          backgroundColor: NutritionAccentPalette.softGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving monthly goal: $e')),
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
          'Monthly Goal Setup',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: theme.text),
                    onPressed: () => _shiftMonth(-1),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _yearMonth,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                        Text(
                          '$_calendarDays calendar days in this month',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: theme.text),
                    onPressed: () => _shiftMonth(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              NeumorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Monthly targets are independently editable and are never forced to daily × 30.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _calCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.text),
                        decoration: const InputDecoration(
                          labelText: 'Monthly Calorie Budget / Target (kcal) *',
                        ),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0) return 'Enter positive kcal';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _protCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: theme.text),
                              decoration: const InputDecoration(
                                  labelText: 'Protein (g, optional)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _carbsCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: theme.text),
                              decoration: const InputDecoration(
                                  labelText: 'Carbs (g, optional)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fatCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: theme.text),
                              decoration: const InputDecoration(
                                  labelText: 'Fat (g, optional)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _fibreCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: theme.text),
                              decoration: const InputDecoration(
                                  labelText: 'Fibre (g, optional)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _daysCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.text),
                        decoration: InputDecoration(
                          labelText:
                              'Target Days Within Goal (max $_calendarDays)',
                        ),
                      ),
                      const SizedBox(height: 18),
                      NeumorphicButton(
                        isEnabled: !_saving,
                        color: NutritionAccentPalette.warmOrange,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        onTap: _save,
                        child: Center(
                          child: Text(
                            _saving ? 'Saving...' : 'Save Monthly Goal',
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
}

