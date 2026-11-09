import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/config/app_config.dart';
import 'package:daily_counter/core/constants/app_constants.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/theme/theme_presets.dart';
import 'package:daily_counter/core/theme/theme_provider.dart';
import 'package:daily_counter/core/utils/currency_utils.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import 'package:daily_counter/shared/components/neumorphic_input.dart';
import 'package:daily_counter/shared/components/neumorphic_theme_card.dart';
import 'package:daily_counter/shared/models/daily_record.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/auth/screens/login_screen.dart';
import '../providers/home_providers.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _unitAmountController = TextEditingController();
  final TextEditingController _customLimitController = TextEditingController();
  final TextEditingController _currencySymbolController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = AppConfig.apiBaseUrl;
  }

  @override
  void dispose() {
    _unitAmountController.dispose();
    _customLimitController.dispose();
    _currencySymbolController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  void _showConflictDialog(List<DailyRecord> conflicts, int newLimit) {
    final theme = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Daily Limit Conflict',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cannot set daily limit to $newLimit because ${conflicts.length} historical record(s) have counts higher than $newLimit:',
              style: TextStyle(color: theme.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conflicts.length,
                itemBuilder: (c, i) {
                  final rec = conflicts[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• ${AppDateUtils.formatShortDate(rec.date)}: count ${rec.count}',
                      style: TextStyle(color: theme.text, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please lower or reset the count for those days before setting the limit to $newLimit.',
              style: TextStyle(color: Colors.amber[800], fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _trySetDailyLimit(int newLimit) async {
    final service = ref.read(settingsServiceProvider);
    final conflicts = await service.checkDailyLimitConflicts(newLimit);
    if (conflicts.isNotEmpty && mounted) {
      _showConflictDialog(conflicts, newLimit);
      return;
    }

    await ref.read(settingsNotifierProvider.notifier).updateDailyLimit(newLimit);
    ref.invalidate(todayRecordProvider);
    ref.invalidate(homeWeeklySummaryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily limit updated to $newLimit')),
      );
    }
  }

  Future<void> _updateUnitAmount() async {
    final val = double.tryParse(_unitAmountController.text.trim());
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive unit amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await ref.read(settingsNotifierProvider.notifier).updateUnitAmount(val);
    _unitAmountController.clear();
    ref.invalidate(todayRecordProvider);
    ref.invalidate(homeWeeklySummaryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unit amount updated to $val')),
      );
    }
  }

  Future<void> _confirmResetToday() async {
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Today?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to reset today\'s count to 0?', style: TextStyle(color: theme.secondaryText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final todayStr = AppDateUtils.getTodayDateString();
      final counterService = ref.read(counterServiceProvider);
      await counterService.resetDay(todayStr);
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today has been reset')),
        );
      }
    }
  }

  Future<void> _confirmResetWeek() async {
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Current Week?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to reset all counts and amounts for the current week to 0?', style: TextStyle(color: theme.secondaryText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset Week', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final settings = ref.read(settingsNotifierProvider).value;
      final weekStart = settings?.weekStart ?? 'monday';
      final weekDates = AppDateUtils.getWeekDates(DateTime.now(), weekStart);
      final counterService = ref.read(counterServiceProvider);
      await counterService.resetWeek(weekDates);
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current week has been reset')),
        );
      }
    }
  }

  Future<void> _confirmResetAllData() async {
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset All Data?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete all daily counts and history records. Your preferences and themes will be preserved.',
          style: TextStyle(color: theme.secondaryText),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete Everything', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final counterService = ref.read(counterServiceProvider);
      await counterService.resetAllData();
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final settings = settingsAsync.value;

    final unitAmount = settings?.unitAmount ?? AppConstants.defaultUnitAmount;
    final dailyLimit = settings?.dailyLimit ?? 2;
    final weekStart = settings?.weekStart ?? 'monday';
    final currencySymbol = settings?.currencySymbol ?? '₹';
    final selectedThemeId = theme.id;

    const limitPresets = [1, 2, 3, 4, 5, 10];
    const currencyPresets = ['₹', '\$', '€', '£', '¥'];

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: theme.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: ACCOUNT & MONGODB CLOUD SYNC
              _buildAccountAndSyncSection(context, ref, theme),
              const SizedBox(height: 24),

              // SECTION A: COUNTER SETTINGS
              _buildSectionHeader('COUNTER SETTINGS'),
              const SizedBox(height: 12),
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit Amount',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Current: ${CurrencyUtils.formatCurrency(unitAmount, currencySymbol)}',
                              style: TextStyle(fontSize: 13, color: theme.secondaryText),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicInput(
                            controller: _unitAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixText: '$currencySymbol ',
                            hintText: 'New amount (e.g. 50)',
                          ),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: _updateUnitAmount,
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),

                    // Daily Maximum
                    Text(
                      'Daily Maximum Limit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Maximum allowed increments per day (current: $dailyLimit)',
                      style: TextStyle(fontSize: 13, color: theme.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    // Limit Presets Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: limitPresets.map((limit) {
                        final isSelected = limit == dailyLimit;
                        return NeumorphicButton(
                          width: 48,
                          height: 44,
                          padding: EdgeInsets.zero,
                          color: isSelected ? theme.accent : null,
                          isProminent: isSelected,
                          onTap: () => _trySetDailyLimit(limit),
                          child: Text(
                            '$limit',
                            style: TextStyle(
                              color: isSelected ? Colors.white : theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Custom Limit Input
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicInput(
                            controller: _customLimitController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            hintText: 'Custom limit',
                          ),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: () {
                            final val = int.tryParse(_customLimitController.text.trim());
                            if (val != null && val > 0) {
                              _trySetDailyLimit(val);
                              _customLimitController.clear();
                            }
                          },
                          child: const Text('Set'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),

                    // Week Starts On
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Week Starts On',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              weekStart == 'monday' ? 'Monday - Sunday' : 'Sunday - Saturday',
                              style: TextStyle(fontSize: 13, color: theme.secondaryText),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            NeumorphicButton(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              isProminent: weekStart == 'monday',
                              onTap: () async {
                                await ref.read(settingsNotifierProvider.notifier).updateWeekStart('monday');
                                ref.invalidate(homeWeeklySummaryProvider);
                              },
                              child: const Text('Mon'),
                            ),
                            const SizedBox(width: 8),
                            NeumorphicButton(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              isProminent: weekStart == 'sunday',
                              onTap: () async {
                                await ref.read(settingsNotifierProvider.notifier).updateWeekStart('sunday');
                                ref.invalidate(homeWeeklySummaryProvider);
                              },
                              child: const Text('Sun'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),

                    // Currency Symbol
                    Text(
                      'Currency Symbol',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: currencyPresets.map((sym) {
                        final isSelected = sym == currencySymbol;
                        return NeumorphicButton(
                          width: 44,
                          height: 40,
                          padding: EdgeInsets.zero,
                          isProminent: isSelected,
                          onTap: () => ref.read(settingsNotifierProvider.notifier).updateCurrencySymbol(sym),
                          child: Text(
                            sym,
                            style: TextStyle(
                              color: isSelected ? Colors.white : theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // SECTION B: THEME CUSTOMIZATION
              _buildSectionHeader('THEME PRESETS (6 THEMES)'),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ThemePresets.allThemes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final palette = ThemePresets.allThemes[index];
                  final isSelected = palette.id == selectedThemeId;

                  return NeumorphicThemeCard(
                    palette: palette,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(themeProvider.notifier).setTheme(palette.id);
                    },
                  );
                },
              ),
              const SizedBox(height: 28),

              // SECTION C: DATA MANAGEMENT
              _buildSectionHeader('DATA MANAGEMENT'),
              const SizedBox(height: 12),
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDestructiveActionRow(
                      title: 'Billing Checkpoint',
                      subtitle: (settings?.checkpointDate != null && settings!.checkpointDate!.isNotEmpty)
                          ? 'Active checkpoint: ${AppDateUtils.formatDisplayDate(settings.checkpointDate!)}'
                          : 'Widget counts meals/amount starting after checkpoint',
                      buttonLabel: (settings?.checkpointDate != null && settings!.checkpointDate!.isNotEmpty)
                          ? 'Clear'
                          : 'Set Today',
                      onPressed: () async {
                        if (settings?.checkpointDate != null && settings!.checkpointDate!.isNotEmpty) {
                          await ref.read(counterServiceProvider).clearCheckpoint();
                        } else {
                          final today = AppDateUtils.getTodayDateString();
                          await ref.read(counterServiceProvider).setCheckpoint(today);
                        }
                        ref.invalidate(settingsNotifierProvider);
                        ref.invalidate(cycleMealsCountProvider);
                        ref.invalidate(cycleTotalAmountProvider);
                        ref.read(syncServiceProvider).autoSync();
                      },
                    ),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    _buildDestructiveActionRow(
                      title: 'Reset Today',
                      subtitle: 'Reset today\'s count to zero',
                      buttonLabel: 'Reset',
                      onPressed: _confirmResetToday,
                    ),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    _buildDestructiveActionRow(
                      title: 'Reset Current Week',
                      subtitle: 'Clear all records in the active week',
                      buttonLabel: 'Reset',
                      onPressed: _confirmResetWeek,
                    ),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    _buildDestructiveActionRow(
                      title: 'Reset All Data',
                      subtitle: 'Delete all records (settings preserved)',
                      buttonLabel: 'Delete All',
                      isHighRisk: true,
                      onPressed: _confirmResetAllData,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // SECTION D: ABOUT & PRIVACY
              _buildSectionHeader('ABOUT & PRIVACY'),
              const SizedBox(height: 12),
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.shield_outlined, color: theme.accent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppConstants.appName} v${AppConstants.appVersion}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                            Text(
                              'Offline SQLite • No Cloud Tracking',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'All your daily counts, amount calculations, and preferences are stored exclusively on your device in a shared local SQLite database. No internet permission, accounts, or analytics SDKs are used.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = context.appTheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: theme.secondaryText,
      ),
    );
  }

  Widget _buildDestructiveActionRow({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    bool isHighRisk = false,
  }) {
    final theme = context.appTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isHighRisk ? Colors.redAccent : theme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          NeumorphicButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: onPressed,
            child: Text(
              buttonLabel,
              style: TextStyle(
                color: isHighRisk ? Colors.redAccent : theme.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountAndSyncSection(BuildContext context, WidgetRef ref, dynamic theme) {
    final authState = ref.watch(authStateProvider);
    final syncState = ref.watch(syncStatusProvider);
    final user = authState.user;
    final isLoggedIn = authState.isLoggedIn && user != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ACCOUNT & CLOUD SYNC (MONGODB)'),
        const SizedBox(height: 12),
        NeumorphicContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoggedIn) ...[
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.accent, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: theme.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: TextStyle(fontSize: 13, color: theme.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          const Text('Cloud Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        syncState.isSyncing
                            ? Icons.sync_rounded
                            : (syncState.lastSuccess == false ? Icons.cloud_off_rounded : Icons.cloud_done_rounded),
                        size: 20,
                        color: syncState.lastSuccess == false ? Colors.amber[800] : theme.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              syncState.isSyncing
                                  ? 'Syncing with MongoDB...'
                                  : (syncState.lastMessage ?? (syncState.lastSyncedAt != null ? 'Synced with MongoDB' : 'Ready to sync')),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.text),
                            ),
                            if (syncState.lastSyncedAt != null && !syncState.isSyncing) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Last synced: ${AppDateUtils.formatDisplayDate(syncState.lastSyncedAt!.split('T')[0])}',
                                style: TextStyle(fontSize: 11, color: theme.secondaryText),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: NeumorphicButton(
                        isProminent: true,
                        isEnabled: !syncState.isSyncing,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: () async {
                          final res = await ref.read(syncStatusProvider.notifier).triggerSync();
                          ref.invalidate(todayRecordProvider);
                          ref.invalidate(homeWeeklySummaryProvider);
                          ref.invalidate(cycleMealsCountProvider);
                          ref.invalidate(cycleTotalAmountProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success ? Colors.green[700] : (res.isOffline ? Colors.amber[800] : Colors.redAccent),
                              ),
                            );
                          }
                        },
                        child: syncState.isSyncing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.sync_rounded, size: 18, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('Sync Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    NeumorphicButton(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () async {
                        await ref.read(authStateProvider.notifier).logout();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logged out. Switched to offline mode.')),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text('Log Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_off_rounded, size: 22, color: Colors.amber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Offline Guest Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.text)),
                          const SizedBox(height: 2),
                          Text(
                            'Meals are saved on this device. Sign in to back up & sync with MongoDB.',
                            style: TextStyle(fontSize: 12, color: theme.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: NeumorphicButton(
                    isProminent: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen(isModal: true)),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Sign In with Name & Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _showServerConfigDialog(context, theme),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dns_outlined, size: 14, color: theme.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      'Server & MongoDB Details',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.secondaryText),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.tune_rounded, size: 12, color: theme.secondaryText),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showServerConfigDialog(BuildContext context, dynamic theme) {
    _serverUrlController.text = AppConfig.apiBaseUrl;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Server & Database Settings', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Server Base URL:', style: TextStyle(color: theme.secondaryText, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            NeumorphicInput(
              controller: _serverUrlController,
              hintText: 'http://localhost:5000/api',
            ),
            const SizedBox(height: 12),
            Text('MongoDB Atlas Target:', style: TextStyle(color: theme.secondaryText, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'counter.v7ndlkx.mongodb.net/daily_counter',
                style: TextStyle(color: theme.accent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppConfig.resetApiBaseUrl();
              _serverUrlController.text = AppConfig.apiBaseUrl;
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('Reset Default', style: TextStyle(color: theme.secondaryText)),
          ),
          TextButton(
            onPressed: () async {
              final newUrl = _serverUrlController.text.trim();
              if (newUrl.isNotEmpty) {
                await AppConfig.setApiBaseUrl(newUrl);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('Save', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
