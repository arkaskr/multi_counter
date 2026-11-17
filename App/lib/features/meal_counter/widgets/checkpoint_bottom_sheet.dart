import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/constants/app_constants.dart';
import 'package:daily_counter/core/services/counter_service.dart';
import 'package:daily_counter/core/services/sync_service.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/utils/currency_utils.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import '../providers/home_providers.dart';
import '../providers/settings_providers.dart';

/// Modal bottom sheet for customizable billing checkpoint management.
///
/// Allows users to:
/// - Select any date (Today, Yesterday, Tomorrow, or Pick from Calendar).
/// - Choose between "Inclusive" (cycle begins on this date, meals on this date are counted)
///   and "Exclusive" (cycle begins the day after, meals on this date are marked settled).
/// - Preview the exact impact (meals & amount) in real-time before saving.
/// - Clear active checkpoints.
class CheckpointBottomSheet extends ConsumerStatefulWidget {
  const CheckpointBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckpointBottomSheet(),
    );
  }

  @override
  ConsumerState<CheckpointBottomSheet> createState() =>
      _CheckpointBottomSheetState();
}

class _CheckpointBottomSheetState extends ConsumerState<CheckpointBottomSheet> {
  late DateTime _selectedDate;
  late String _selectedMode; // 'inclusive' or 'exclusive'
  int _previewMeals = 0;
  double _previewAmount = 0.0;
  bool _isLoadingPreview = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider).value;
    final activeDateStr = settings?.checkpointDate;
    if (activeDateStr != null && activeDateStr.isNotEmpty) {
      _selectedDate = AppDateUtils.parseDate(activeDateStr);
      _selectedMode = settings?.checkpointMode ?? 'inclusive';
    } else {
      _selectedDate = DateTime.now();
      _selectedMode = 'inclusive';
    }

    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoadingPreview = true);
    final dateStr = AppDateUtils.formatDate(_selectedDate);
    final settings = ref.read(settingsNotifierProvider).value;
    final unitAmount = settings?.unitAmount ?? AppConstants.defaultUnitAmount;
    final service = ref.read(counterServiceProvider);

    final meals = await service.getCycleMealsCount(
      dateStr,
      checkpointMode: _selectedMode,
    );
    final amount = await service.getCycleTotalAmount(
      dateStr,
      unitAmount,
      checkpointMode: _selectedMode,
    );

    if (mounted) {
      setState(() {
        _previewMeals = meals;
        _previewAmount = amount;
        _isLoadingPreview = false;
      });
    }
  }

  void _setDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadPreview();
  }

  void _setMode(String mode) {
    setState(() {
      _selectedMode = mode;
    });
    _loadPreview();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        final theme = context.appTheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.accent,
              onPrimary: Colors.white,
              surface: theme.surface,
              onSurface: theme.text,
            ),
            dialogBackgroundColor: theme.background,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      _setDate(picked);
    }
  }

  Future<void> _saveCheckpoint() async {
    final dateStr = AppDateUtils.formatDate(_selectedDate);
    await ref
        .read(counterServiceProvider)
        .setCheckpoint(dateStr, mode: _selectedMode);
    _invalidateAll();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clearCheckpoint() async {
    await ref.read(counterServiceProvider).clearCheckpoint();
    _invalidateAll();
    if (mounted) Navigator.of(context).pop();
  }

  void _invalidateAll() {
    ref.invalidate(settingsNotifierProvider);
    ref.invalidate(cycleMealsCountProvider);
    ref.invalidate(cycleTotalAmountProvider);
    ref.read(syncServiceProvider).autoSync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settings = ref.watch(settingsNotifierProvider).value;
    final currencySymbol =
        settings?.currencySymbol ?? AppConstants.defaultCurrencySymbol;
    final activeCheckpoint = settings?.checkpointDate;
    final hasActiveCheckpoint =
        activeCheckpoint != null && activeCheckpoint.isNotEmpty;

    final today = DateTime.now();
    final todayStr = AppDateUtils.formatDate(today);
    final yesterdayStr = AppDateUtils.formatDate(
        today.subtract(const Duration(days: 1)));
    final tomorrowStr = AppDateUtils.formatDate(
        today.add(const Duration(days: 1)));
    final curSelectedStr = AppDateUtils.formatDate(_selectedDate);

    final displaySelectedDate =
        AppDateUtils.formatDisplayDate(curSelectedStr);

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: theme.secondaryText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Title & Subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BILLING CHECKPOINT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage Billing Cycle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.secondaryText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Active Checkpoint Info Badge (if active)
            if (hasActiveCheckpoint)
              NeumorphicContainer(
                borderRadius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_added_rounded,
                        color: theme.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active: ${AppDateUtils.formatDisplayDate(activeCheckpoint)} (${settings?.checkpointMode == 'exclusive' ? 'Start Day After' : 'Includes Date'})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cycle counts meals and total amount from this boundary.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // 1. DATE PRESETS & SELECTION
            Text(
              '1. SELECT CHECKPOINT DATE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 10),

            // Preset Buttons Row
            Row(
              children: [
                _buildPresetButton(
                  label: 'Today',
                  isSelected: curSelectedStr == todayStr,
                  onTap: () => _setDate(today),
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildPresetButton(
                  label: 'Yesterday',
                  isSelected: curSelectedStr == yesterdayStr,
                  onTap: () => _setDate(today.subtract(const Duration(days: 1))),
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildPresetButton(
                  label: 'Tomorrow',
                  isSelected: curSelectedStr == tomorrowStr,
                  onTap: () => _setDate(today.add(const Duration(days: 1))),
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildPresetButton(
                  label: 'Pick Date',
                  icon: Icons.calendar_month_rounded,
                  isSelected: curSelectedStr != todayStr &&
                      curSelectedStr != yesterdayStr &&
                      curSelectedStr != tomorrowStr,
                  onTap: _pickCustomDate,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selected Date Indicator
            GestureDetector(
              onTap: _pickCustomDate,
              child: NeumorphicContainer(
                borderRadius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_available_rounded,
                            color: theme.accent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          displaySelectedDate,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tap to change',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. SETTLEMENT MODE SELECTION
            Text(
              '2. HOW TO TREAT THIS DATE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 10),

            // Option 1: Inclusive (Start On This Date)
            _buildModeOption(
              modeKey: 'inclusive',
              title: 'Include this date in new cycle',
              badge: 'Recommended',
              subtitle:
                  'Meals logged on $displaySelectedDate count towards the new cycle (Cycle: ≥ $displaySelectedDate). Best if starting today or paid yesterday.',
              isSelected: _selectedMode == 'inclusive',
              onTap: () => _setMode('inclusive'),
              theme: theme,
            ),
            const SizedBox(height: 10),

            // Option 2: Exclusive (Start Day After This Date)
            _buildModeOption(
              modeKey: 'exclusive',
              title: 'Start cycle day after this date',
              badge: 'Settled Date',
              subtitle:
                  'Meals logged on $displaySelectedDate are marked settled in the previous bill (Cycle: > $displaySelectedDate). Best if paying at night.',
              isSelected: _selectedMode == 'exclusive',
              onTap: () => _setMode('exclusive'),
              theme: theme,
            ),

            const SizedBox(height: 18),

            // 3. LIVE IMPACT PREVIEW
            NeumorphicContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              color: theme.accent.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.insights_rounded,
                        color: theme.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CYCLE PREVIEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: theme.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (_isLoadingPreview)
                          Text(
                            'Calculating...',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.secondaryText,
                            ),
                          )
                        else
                          Text(
                            '$_previewMeals Meal${_previewMeals == 1 ? '' : 's'}  ·  ${CurrencyUtils.formatCurrency(_previewAmount, currencySymbol)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.text,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedMode == 'inclusive'
                              ? 'Starts on $displaySelectedDate (Includes all meals on this date)'
                              : 'Starts day after $displaySelectedDate (Meals on $displaySelectedDate are excluded)',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // 4. ACTION BUTTONS
            Row(
              children: [
                if (hasActiveCheckpoint) ...[
                  Expanded(
                    flex: 2,
                    child: NeumorphicButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onTap: _clearCheckpoint,
                      child: Center(
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent.shade200,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 3,
                  child: NeumorphicButton(
                    isProminent: true,
                    color: theme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onTap: _saveCheckpoint,
                    child: Center(
                      child: Text(
                        'Save Checkpoint',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required dynamic theme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.accent : theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.accent
                  : theme.secondaryText.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color: isSelected ? Colors.white : theme.secondaryText),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : theme.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String modeKey,
    required String title,
    required String badge,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required dynamic theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accent.withValues(alpha: 0.12)
              : theme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? theme.accent
                : theme.secondaryText.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? theme.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? theme.accent : theme.secondaryText,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? theme.accent : theme.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.accent.withValues(alpha: 0.2)
                              : theme.secondaryText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? theme.accent
                                : theme.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.secondaryText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
