import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/config/app_config.dart';
import 'package:daily_counter/core/constants/app_constants.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/theme/theme_presets.dart';
import 'package:daily_counter/core/theme/theme_provider.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/auth/screens/login_screen.dart';
import 'package:daily_counter/features/meal_counter/providers/home_providers.dart';
import 'package:daily_counter/features/meal_counter/providers/settings_providers.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import 'package:daily_counter/shared/components/neumorphic_input.dart';
import 'package:daily_counter/shared/components/neumorphic_theme_card.dart';

class GlobalSettingsScreen extends ConsumerStatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  ConsumerState<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends ConsumerState<GlobalSettingsScreen> {
  final TextEditingController _serverUrlController = TextEditingController();

  static const List<String> currencyPresets = ['₹', '\$', '€', '£', '¥', '₩', '₺', '₴'];

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = AppConfig.apiBaseUrl;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final settings = settingsAsync.value;
    final currentTheme = ref.watch(themeProvider);
    final selectedThemeId = currentTheme.id;
    final currencySymbol = settings?.currencySymbol ?? '₹';
    final weekStart = settings?.weekStart ?? 'monday';

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'App Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.text,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: ACCOUNT & CLOUD SYNC
              _buildSectionHeader('ACCOUNT & CLOUD BACKUP'),
              const SizedBox(height: 12),
              _buildAccountAndSyncCard(context, ref, theme),
              const SizedBox(height: 28),

              // SECTION 2: THEME PRESETS
              _buildSectionHeader('APPEARANCE & THEME'),
              const SizedBox(height: 6),
              Text(
                'Select a neumorphic theme palette for the entire application.',
                style: TextStyle(fontSize: 12, color: theme.secondaryText),
              ),
              const SizedBox(height: 14),
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

              // SECTION 3: GLOBAL PREFERENCES
              _buildSectionHeader('GLOBAL PREFERENCES'),
              const SizedBox(height: 12),
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // SECTION 4: ABOUT & APP INFO
              _buildSectionHeader('ABOUT APPLICATION'),
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
                          child: Icon(Icons.verified_outlined, color: theme.accent, size: 24),
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
                              'Offline-First SQLite + MongoDB Atlas',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your data is preserved locally in SQLite and synchronized automatically with MongoDB Atlas whenever network connectivity is active.',
                      style: TextStyle(fontSize: 13, color: theme.secondaryText, height: 1.4),
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
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: theme.secondaryText,
      ),
    );
  }

  Widget _buildAccountAndSyncCard(BuildContext context, WidgetRef ref, dynamic theme) {
    final authState = ref.watch(authStateProvider);
    final syncState = ref.watch(syncStatusProvider);
    final user = authState.user;
    final isLoggedIn = authState.isLoggedIn && user != null;

    return NeumorphicContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLoggedIn
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.accent.withValues(alpha: 0.15),
                ),
                child: Icon(
                  isLoggedIn ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: isLoggedIn ? Colors.green : theme.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoggedIn ? user.name : 'Guest User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                    Text(
                      isLoggedIn ? user.email : 'Local offline storage',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoggedIn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Synced',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
          const SizedBox(height: 12),

          // Action Buttons: Manual Sync or Sign In
          if (isLoggedIn) ...[
            Row(
              children: [
                Expanded(
                  child: NeumorphicButton(
                    onTap: syncState.isSyncing
                        ? null
                        : () async {
                            await ref.read(syncStatusProvider.notifier).triggerSync();
                          },
                    child: syncState.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sync_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('Sync with MongoDB', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            if (syncState.lastMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                syncState.lastMessage!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: syncState.lastSuccess == true ? Colors.green : Colors.amber[800],
                ),
              ),
            ],
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: NeumorphicButton(
                isProminent: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(isModal: true),
                    ),
                  );
                },
                child: const Text('Sign In or Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
          const SizedBox(height: 12),

          // Server URL Config
          Text(
            'Backend API Endpoint',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.text),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: NeumorphicInput(
                  controller: _serverUrlController,
                  hintText: 'https://...',
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(width: 8),
              NeumorphicButton(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () async {
                  final newUrl = _serverUrlController.text.trim();
                  if (newUrl.isNotEmpty) {
                    await AppConfig.setApiBaseUrl(newUrl);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API URL updated successfully')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
