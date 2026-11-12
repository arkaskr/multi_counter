import 'package:sqflite/sqflite.dart';

/// Dedicated SQLite DDL for the independent Calorie Counter & Nutrition module.
///
/// Kept strictly separate from `daily_records` (Meal Counter) and Expense Counter.
class NutritionDatabaseSchema {
  NutritionDatabaseSchema._();

  static const String tableFoodCategories = 'food_categories';
  static const String tableFoods = 'foods';
  static const String tableFoodNutrition = 'food_nutrition';
  static const String tableFoodServings = 'food_servings';
  static const String tableFoodLogs = 'food_logs';
  static const String tableDailyNutritionGoals = 'daily_nutrition_goals';
  static const String tableMonthlyNutritionGoals = 'monthly_nutrition_goals';
  static const String tableUserNutritionPreferences =
      'user_nutrition_preferences';
  static const String tableDietPlans = 'diet_plans';
  static const String tableDietPlanMeals = 'diet_plan_meals';
  static const String tableDietPlanItems = 'diet_plan_items';
  static const String tableFoodRequests = 'food_requests';
  static const String tableFoodFavorites = 'food_favorites';
  static const String tableDailyHydrationLogs = 'daily_hydration_logs';

  static const List<String> _ddlStatements = [
    '''
    CREATE TABLE IF NOT EXISTS $tableFoodCategories (
      id TEXT PRIMARY KEY,
      slug TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      icon_key TEXT NOT NULL DEFAULT 'intl_plate',
      sort_order INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFoods (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      common_names TEXT NOT NULL DEFAULT '',
      category_id TEXT NOT NULL,
      illustration_id TEXT NOT NULL DEFAULT 'generic',
      preparation_state TEXT NOT NULL DEFAULT '',
      dietary_tags TEXT NOT NULL DEFAULT '[]',
      allergen_tags TEXT NOT NULL DEFAULT '[]',
      source_name TEXT NOT NULL,
      source_reference TEXT NOT NULL,
      source_license TEXT NOT NULL DEFAULT '',
      is_verified INTEGER NOT NULL DEFAULT 0,
      is_complete INTEGER NOT NULL DEFAULT 1,
      verification_notes TEXT NOT NULL DEFAULT '',
      catalogue_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES $tableFoodCategories (id) ON DELETE RESTRICT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFoodNutrition (
      food_id TEXT PRIMARY KEY,
      calories REAL NOT NULL DEFAULT 0,
      protein REAL NOT NULL DEFAULT 0,
      carbs REAL NOT NULL DEFAULT 0,
      fat REAL NOT NULL DEFAULT 0,
      fibre REAL NOT NULL DEFAULT 0,
      sugar REAL,
      sodium_mg REAL,
      saturated_fat REAL,
      potassium_mg REAL,
      calcium_mg REAL,
      iron_mg REAL,
      vitamin_c_mg REAL,
      extra_nutrients_json TEXT NOT NULL DEFAULT '{}',
      FOREIGN KEY (food_id) REFERENCES $tableFoods (id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFoodServings (
      id TEXT NOT NULL,
      food_id TEXT NOT NULL,
      label TEXT NOT NULL,
      unit_type TEXT NOT NULL DEFAULT 'piece',
      grams_per_unit REAL NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (food_id, id),
      FOREIGN KEY (food_id) REFERENCES $tableFoods (id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFoodLogs (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      date TEXT NOT NULL,
      meal_category TEXT NOT NULL,
      food_id TEXT NOT NULL,
      food_name_snapshot TEXT NOT NULL,
      preparation_snapshot TEXT NOT NULL DEFAULT '',
      illustration_snapshot TEXT NOT NULL DEFAULT 'generic',
      serving_id TEXT NOT NULL,
      serving_label_snapshot TEXT NOT NULL,
      serving_count REAL NOT NULL DEFAULT 1,
      grams_per_unit REAL NOT NULL,
      total_grams REAL NOT NULL,
      calories REAL NOT NULL,
      protein REAL NOT NULL,
      carbs REAL NOT NULL,
      fat REAL NOT NULL,
      fibre REAL NOT NULL,
      sugar REAL,
      sodium_mg REAL,
      saturated_fat REAL,
      potassium_mg REAL,
      calcium_mg REAL,
      iron_mg REAL,
      vitamin_c_mg REAL,
      source_snapshot TEXT NOT NULL DEFAULT '',
      logged_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      is_deleted INTEGER NOT NULL DEFAULT 0,
      server_version INTEGER NOT NULL DEFAULT 1,
      notes TEXT NOT NULL DEFAULT ''
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableDailyNutritionGoals (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      effective_from_date TEXT NOT NULL,
      calories REAL NOT NULL,
      protein REAL NOT NULL,
      carbs REAL NOT NULL,
      fat REAL NOT NULL,
      fibre REAL NOT NULL,
      hydration_ml INTEGER,
      source_mode TEXT NOT NULL DEFAULT 'manual',
      notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      is_deleted INTEGER NOT NULL DEFAULT 0,
      UNIQUE (user_id, effective_from_date)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableMonthlyNutritionGoals (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      year_month TEXT NOT NULL,
      total_calories REAL NOT NULL,
      protein REAL,
      carbs REAL,
      fat REAL,
      fibre REAL,
      target_days_within_goal INTEGER,
      notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      is_deleted INTEGER NOT NULL DEFAULT 0,
      UNIQUE (user_id, year_month)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableUserNutritionPreferences (
      user_id TEXT PRIMARY KEY,
      dietary_preference TEXT NOT NULL DEFAULT 'vegetarian',
      allergies_json TEXT NOT NULL DEFAULT '[]',
      excluded_food_ids_json TEXT NOT NULL DEFAULT '[]',
      preferred_meal_timings_json TEXT NOT NULL DEFAULT '{}',
      fitness_objective TEXT NOT NULL DEFAULT 'maintain_weight',
      age INTEGER,
      sex TEXT,
      height_cm REAL,
      weight_kg REAL,
      activity_level TEXT NOT NULL DEFAULT 'moderate',
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending'
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableDietPlans (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      title TEXT NOT NULL,
      target_calories REAL NOT NULL,
      target_protein REAL NOT NULL,
      target_carbs REAL NOT NULL,
      target_fat REAL NOT NULL,
      target_fibre REAL NOT NULL,
      dietary_preference TEXT NOT NULL,
      fitness_objective TEXT NOT NULL,
      generated_by TEXT NOT NULL DEFAULT 'fallback',
      model_name TEXT NOT NULL DEFAULT '',
      ai_notes TEXT NOT NULL DEFAULT '',
      is_accepted INTEGER NOT NULL DEFAULT 0,
      is_saved INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableDietPlanMeals (
      id TEXT PRIMARY KEY,
      plan_id TEXT NOT NULL,
      meal_category TEXT NOT NULL,
      meal_timing TEXT NOT NULL DEFAULT '',
      explanation TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (plan_id) REFERENCES $tableDietPlans (id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableDietPlanItems (
      id TEXT PRIMARY KEY,
      meal_id TEXT NOT NULL,
      food_id TEXT NOT NULL,
      food_name_snapshot TEXT NOT NULL,
      illustration_snapshot TEXT NOT NULL DEFAULT 'generic',
      serving_id TEXT NOT NULL,
      serving_label_snapshot TEXT NOT NULL,
      serving_count REAL NOT NULL DEFAULT 1,
      grams_per_unit REAL NOT NULL,
      total_grams REAL NOT NULL,
      calories REAL NOT NULL,
      protein REAL NOT NULL,
      carbs REAL NOT NULL,
      fat REAL NOT NULL,
      fibre REAL NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (meal_id) REFERENCES $tableDietPlanMeals (id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFoodRequests (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      food_name TEXT NOT NULL,
      category_hint TEXT NOT NULL DEFAULT '',
      brand_or_preparation TEXT NOT NULL DEFAULT '',
      serving_description TEXT NOT NULL DEFAULT '',
      reference_url_or_note TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'pending',
      admin_notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending'
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFoodFavorites (
      user_id TEXT NOT NULL,
      food_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, food_id)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableDailyHydrationLogs (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      date TEXT NOT NULL,
      amount_ml INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      UNIQUE (user_id, date)
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_foods_category ON $tableFoods (category_id)',
    'CREATE INDEX IF NOT EXISTS idx_foods_name ON $tableFoods (name)',
    'CREATE INDEX IF NOT EXISTS idx_food_logs_user_date ON $tableFoodLogs (user_id, date, is_deleted)',
    'CREATE INDEX IF NOT EXISTS idx_food_logs_logged_at ON $tableFoodLogs (user_id, logged_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_daily_goals_user_date ON $tableDailyNutritionGoals (user_id, effective_from_date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_monthly_goals_user_ym ON $tableMonthlyNutritionGoals (user_id, year_month)',
    'CREATE INDEX IF NOT EXISTS idx_diet_plans_user ON $tableDietPlans (user_id, is_deleted, updated_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_food_requests_user ON $tableFoodRequests (user_id, created_at DESC)',
  ];

  static Future<void> createTables(DatabaseExecutor db) async {
    for (final stmt in _ddlStatements) {
      await db.execute(stmt);
    }
  }
}

