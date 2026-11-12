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
import 'food_detail_screen.dart';
import 'food_request_screen.dart';
import 'food_search_screen.dart';

/// Screen 2: Browseable Verified Food Catalogue organized by category.
class FoodCatalogueScreen extends ConsumerStatefulWidget {
  const FoodCatalogueScreen({super.key});

  @override
  ConsumerState<FoodCatalogueScreen> createState() =>
      _FoodCatalogueScreenState();
}

class _FoodCatalogueScreenState extends ConsumerState<FoodCatalogueScreen> {
  String _selectedCategory = 'all';
  bool _favoritesOnly = false;
  bool _filterByDietPref = false;
  List<FoodItem> _foods = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() => _loading = true);
    final userId = ref.read(nutritionUserIdProvider);
    final dashboardState = ref.read(dailyDashboardProvider).value;
    final dietPref =
        _filterByDietPref ? dashboardState?.preferences.dietaryPreference : null;

    final list = await ref.read(foodCatalogueServiceProvider).searchFoods(
          categoryId: _selectedCategory == 'all' ? null : _selectedCategory,
          dietaryPreference: dietPref,
          favoritesOnly: _favoritesOnly,
          userId: userId,
          verifiedOnly: true,
        );
    if (mounted) {
      setState(() {
        _foods = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final categoriesAsync = ref.watch(foodCategoriesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: NeumorphicButton(
                  onTap: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const FoodSearchScreen(),
                      ),
                    );
                    if (res == true) _loadFoods();
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          size: 20, color: theme.secondaryText),
                      const SizedBox(width: 8),
                      Text(
                        'Search verified foods...',
                        style: TextStyle(color: theme.secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              NeumorphicButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FoodRequestScreen(),
                    ),
                  );
                },
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.add_comment_rounded,
                  size: 20,
                  color: NutritionAccentPalette.warmOrange,
                ),
              ),
            ],
          ),
        ),

        // Quick toggle chips (Favorites & Diet Filter)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Favorites'),
                selected: _favoritesOnly,
                selectedColor:
                    NutritionAccentPalette.fatCoral.withValues(alpha: 0.2),
                onSelected: (v) {
                  setState(() => _favoritesOnly = v);
                  _loadFoods();
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Match My Diet'),
                selected: _filterByDietPref,
                selectedColor:
                    NutritionAccentPalette.softGreen.withValues(alpha: 0.2),
                onSelected: (v) {
                  setState(() => _filterByDietPref = v);
                  _loadFoods();
                },
              ),
              const Spacer(),
              Text(
                '${_foods.length} items',
                style: TextStyle(fontSize: 12, color: theme.secondaryText),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Categories strip
        categoriesAsync.when(
          data: (categories) => SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _catChip(theme, 'all', 'All Categories'),
                ...categories.map((c) => _catChip(theme, c.id, c.name)),
              ],
            ),
          ),
          loading: () => const SizedBox(height: 40),
          error: (_, _) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _foods.isEmpty
                  ? Center(
                      child: NeumorphicContainer(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No foods match these filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.text,
                              ),
                            ),
                            const SizedBox(height: 10),
                            NeumorphicButton(
                              color: NutritionAccentPalette.warmOrange,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FoodRequestScreen(),
                                ),
                              ),
                              child: const Text(
                                'Request a Food',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _foods.length,
                      itemBuilder: (context, index) {
                        final food = _foods[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NeumorphicButton(
                            padding: const EdgeInsets.all(12),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FoodDetailScreen(
                                    food: food,
                                    initialMealCategory: MealCategory.lunch,
                                  ),
                                ),
                              );
                              _loadFoods();
                            },
                            child: Row(
                              children: [
                                FoodIllustration(
                                  illustrationId: food.illustrationId,
                                  categoryId: food.categoryId,
                                  size: 48,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        food.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: theme.text,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        food.defaultServing.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${food.caloriesPerDefaultServing.round()} kcal',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            NutritionAccentPalette.warmOrange,
                                      ),
                                    ),
                                    Text(
                                      'P ${food.nutritionPer100g.protein.toStringAsFixed(1)}g/100g',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _catChip(AppThemeData theme, String id, String label) {
    final selected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : theme.text,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: selected,
        selectedColor: NutritionAccentPalette.warmOrange,
        backgroundColor: theme.surface,
        onSelected: (_) {
          setState(() => _selectedCategory = id);
          _loadFoods();
        },
      ),
    );
  }
}
