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

/// Screen 3: Instant Offline SQLite Food Search with Category & Favorite Filters
/// plus `Request a Food` CTA for missing foods.
class FoodSearchScreen extends ConsumerStatefulWidget {
  final MealCategory initialMealCategory;
  final bool selectionOnly;
  final String? initialCategoryId;

  const FoodSearchScreen({
    super.key,
    this.initialMealCategory = MealCategory.lunch,
    this.selectionOnly = false,
    this.initialCategoryId,
  });

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _searchCtrl = TextEditingController();
  late String _categoryId;
  bool _favoritesOnly = false;
  bool _loading = true;
  List<FoodItem> _results = const [];

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId ?? 'all';
    _runSearch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    final userId = ref.read(nutritionUserIdProvider);
    final items = await ref.read(foodCatalogueServiceProvider).searchFoods(
          query: _searchCtrl.text,
          categoryId: _categoryId == 'all' ? null : _categoryId,
          favoritesOnly: _favoritesOnly,
          userId: userId,
          verifiedOnly: true,
        );
    if (mounted) {
      setState(() {
        _results = items;
        _loading = false;
      });
    }
  }

  Future<void> _openFood(FoodItem food) async {
    final res = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: food,
          initialMealCategory: widget.initialMealCategory,
          selectionOnly: widget.selectionOnly,
        ),
      ),
    );
    if (!mounted) return;
    if (widget.selectionOnly && res is Map) {
      Navigator.of(context).pop(res);
    } else if (res == true) {
      Navigator.of(context).pop(true);
    } else {
      _runSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final categoriesAsync = ref.watch(foodCategoriesProvider);

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
          widget.selectionOnly
              ? 'Select Food'
              : 'Search Foods (${widget.initialMealCategory.label})',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Favorites only',
            onPressed: () {
              setState(() => _favoritesOnly = !_favoritesOnly);
              _runSearch();
            },
            icon: Icon(
              _favoritesOnly
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _favoritesOnly
                  ? NutritionAccentPalette.fatCoral
                  : theme.secondaryText,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: NeumorphicContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: theme.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(Icons.search_rounded, color: theme.secondaryText),
                    hintText: 'Search roti, dal, paneer, oats, banana...',
                    hintStyle: TextStyle(color: theme.secondaryText),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: theme.secondaryText),
                            onPressed: () {
                              _searchCtrl.clear();
                              _runSearch();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => _runSearch(),
                ),
              ),
            ),

            // Category filter chips
            categoriesAsync.when(
              data: (categories) => SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _catChip(theme, 'all', 'All'),
                    ...categories
                        .map((c) => _catChip(theme, c.id, c.name)),
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
                  : _results.isEmpty
                      ? _emptyRequestState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: _results.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _results.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: NeumorphicContainer(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Missing a specific food or dish?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: theme.secondaryText,
                                          ),
                                        ),
                                      ),
                                      NeumorphicButton(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        color: NutritionAccentPalette.warmOrange,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => FoodRequestScreen(
                                                initialFoodName: _searchCtrl.text,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Request a Food',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final food = _results[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: NeumorphicButton(
                                padding: const EdgeInsets.all(12),
                                onTap: () => _openFood(food),
                                child: Row(
                                  children: [
                                    FoodIllustration(
                                      illustrationId: food.illustrationId,
                                      categoryId: food.categoryId,
                                      size: 46,
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
                                          const SizedBox(height: 2),
                                          Text(
                                            '${food.defaultServing.label} • ${food.caloriesPerDefaultServing.round()} kcal',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (food.isFavorite)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(
                                          Icons.favorite_rounded,
                                          size: 16,
                                          color: NutritionAccentPalette.fatCoral,
                                        ),
                                      ),
                                    Icon(Icons.chevron_right_rounded,
                                        color: theme.secondaryText),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(AppThemeData theme, String id, String label) {
    final selected = _categoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : theme.text,
          ),
        ),
        selected: selected,
        selectedColor: NutritionAccentPalette.warmOrange,
        backgroundColor: theme.surface,
        onSelected: (_) {
          setState(() => _categoryId = id);
          _runSearch();
        },
      ),
    );
  }

  Widget _emptyRequestState(AppThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeumorphicContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 42, color: NutritionAccentPalette.warmOrange),
              const SizedBox(height: 10),
              Text(
                'No verified match found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Submit a food request so we can verify its nutritional data before adding it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.secondaryText),
              ),
              const SizedBox(height: 14),
              NeumorphicButton(
                color: NutritionAccentPalette.warmOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FoodRequestScreen(
                        initialFoodName: _searchCtrl.text,
                      ),
                    ),
                  );
                },
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
      ),
    );
  }
}
