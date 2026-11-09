import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/constants/app_constants.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/utils/currency_utils.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import 'package:daily_counter/shared/components/neumorphic_icon_button.dart';
import 'package:daily_counter/shared/components/neumorphic_input.dart';
import 'package:daily_counter/shared/models/daily_record.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import '../providers/history_providers.dart';
import '../providers/home_providers.dart';
import '../providers/settings_providers.dart';

class DailyEditScreen extends ConsumerStatefulWidget {
  final String date;

  const DailyEditScreen({
    super.key,
    required this.date,
  });

  @override
  ConsumerState<DailyEditScreen> createState() => _DailyEditScreenState();
}

class _DailyEditScreenState extends ConsumerState<DailyEditScreen> {
  late String _currentDate;
  DailyRecord? _record;
  bool _isLoading = true;
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _overrideController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
    _loadRecord();
  }

  @override
  void dispose() {
    _countController.dispose();
    _overrideController.dispose();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    try {
      final service = ref.read(counterServiceProvider);
      final record = await service.getRecord(_currentDate);
      if (mounted) {
        setState(() {
          _record = record;
          _isLoading = false;
          _countController.text = record.count.toString();
          _overrideController.text =
              record.amountOverride != null ? CurrencyUtils.formatNumber(record.amountOverride!) : '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _record = DailyRecord.empty(_currentDate);
          _isLoading = false;
        });
      }
    }
  }

  void _invalidateAllProviders() {
    ref.invalidate(todayRecordProvider);
    ref.invalidate(homeWeeklySummaryProvider);
    ref.invalidate(historyWeeklySummaryProvider);
    ref.invalidate(cycleMealsCountProvider);
    ref.invalidate(cycleTotalAmountProvider);
    ref.read(syncServiceProvider).autoSync();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final currentParsed = AppDateUtils.parseDate(_currentDate);
    final theme = context.appTheme;

    final picked = await showDatePicker(
      context: context,
      initialDate: currentParsed.isAfter(now) ? now : currentParsed,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: theme.accent,
              onPrimary: Colors.white,
              surface: theme.surface,
              onSurface: theme.text,
            ),
            dialogBackgroundColor: theme.surface,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final newDateStr = AppDateUtils.formatDate(picked);
      if (newDateStr != _currentDate) {
        setState(() {
          _currentDate = newDateStr;
          _isLoading = true;
        });
        await _loadRecord();
      }
    }
  }

  Future<void> _increment(int limit) async {
    if (_record == null || _record!.count >= limit) return;
    final service = ref.read(counterServiceProvider);
    final res = await service.setCount(_currentDate, _record!.count + 1, limit);
    if (res.success && mounted) {
      setState(() {
        _record = res.record;
        _countController.text = res.record.count.toString();
      });
      _invalidateAllProviders();
    }
  }

  Future<void> _decrement(int limit) async {
    if (_record == null || _record!.count <= 0) return;
    final service = ref.read(counterServiceProvider);
    final res = await service.setCount(_currentDate, _record!.count - 1, limit);
    if (res.success && mounted) {
      setState(() {
        _record = res.record;
        _countController.text = res.record.count.toString();
      });
      _invalidateAllProviders();
    }
  }

  Future<void> _applyDirectCount(int limit) async {
    final input = int.tryParse(_countController.text.trim());
    if (input == null) return;

    if (input < 0 || input > limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Count must be between 0 and $limit'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _countController.text = _record?.count.toString() ?? '0';
      return;
    }

    final service = ref.read(counterServiceProvider);
    final res = await service.setCount(_currentDate, input, limit);
    if (res.success && mounted) {
      setState(() {
        _record = res.record;
      });
      _invalidateAllProviders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Count updated successfully')),
      );
    }
  }

  Future<void> _applyAmountOverride() async {
    final text = _overrideController.text.trim();
    final double? overrideValue = text.isEmpty ? null : double.tryParse(text);

    if (text.isNotEmpty && (overrideValue == null || overrideValue < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid non-negative amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final service = ref.read(counterServiceProvider);
    final updated = await service.setAmountOverride(_currentDate, overrideValue);
    if (mounted) {
      setState(() {
        _record = updated;
      });
      _invalidateAllProviders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(overrideValue != null
              ? 'Custom amount override applied!'
              : 'Amount override cleared!'),
        ),
      );
    }
  }

  Future<void> _confirmResetDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = ctx.appTheme;
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Reset Day?',
            style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will reset the count to 0 and remove any custom amount override for ${AppDateUtils.formatDisplayDate(_currentDate)}.',
            style: TextStyle(color: theme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: theme.secondaryText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final service = ref.read(counterServiceProvider);
      await service.resetDay(_currentDate);
      await _loadRecord();
      _invalidateAllProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day reset successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final settings = settingsAsync.value;
    final dailyLimit = settings?.dailyLimit ?? 2;
    final unitAmount = settings?.unitAmount ?? AppConstants.defaultUnitAmount;
    final currencySymbol = settings?.currencySymbol ?? '₹';

    if (_isLoading || _record == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: CircularProgressIndicator(color: theme.accent),
        ),
      );
    }

    final currentAmount = _record!.calculateAmount(unitAmount);
    final hasOverride = _record!.amountOverride != null;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  NeumorphicIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                  Text(
                    'Daily Record',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                    ),
                  ),
                  NeumorphicIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Reset Day',
                    iconColor: Colors.redAccent,
                    onTap: _confirmResetDay,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Date Header Card (Tappable to pick any date)
              GestureDetector(
                onTap: _pickDate,
                child: NeumorphicContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: theme.accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppDateUtils.getDayOfWeekFull(_currentDate),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppDateUtils.formatDisplayDate(_currentDate),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      NeumorphicIconButton(
                        icon: Icons.edit_calendar_rounded,
                        size: 40,
                        iconSize: 20,
                        tooltip: 'Change Date',
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Counter Controls Section
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'DAILY COUNTER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -1 / Count / +1 Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NeumorphicIconButton(
                          icon: Icons.remove_rounded,
                          size: 54,
                          iconSize: 26,
                          isEnabled: _record!.count > 0,
                          onTap: () => _decrement(dailyLimit),
                        ),
                        const SizedBox(width: 24),
                        Column(
                          children: [
                            Text(
                              '${_record!.count}',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: theme.text,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'MAX: $dailyLimit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        NeumorphicIconButton(
                          icon: Icons.add_rounded,
                          size: 54,
                          iconSize: 26,
                          isEnabled: _record!.count < dailyLimit,
                          onTap: () => _increment(dailyLimit),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Direct input row
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicInput(
                            controller: _countController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            hintText: 'Enter count (0 - $dailyLimit)',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: () => _applyDirectCount(dailyLimit),
                          child: const Text('Set'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount Section
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DAILY AMOUNT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: theme.secondaryText,
                          ),
                        ),
                        if (hasOverride)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'OVERRIDE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      CurrencyUtils.formatCurrency(currentAmount, currencySymbol),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: theme.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasOverride
                          ? 'Standard: ${_record!.count} × ${CurrencyUtils.formatCurrency(unitAmount, currencySymbol)} = ${CurrencyUtils.formatCurrency((_record!.count * unitAmount).toDouble(), currencySymbol)}'
                          : 'Calculation: ${_record!.count} × ${CurrencyUtils.formatCurrency(unitAmount, currencySymbol)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Custom Amount Override Input
                    Text(
                      'Custom Amount Override',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicInput(
                            controller: _overrideController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixText: '$currencySymbol ',
                            hintText: 'e.g. 60',
                          ),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: _applyAmountOverride,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                    if (hasOverride) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            _overrideController.clear();
                            _applyAmountOverride();
                          },
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.redAccent),
                          label: const Text(
                            'Clear Custom Override',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
