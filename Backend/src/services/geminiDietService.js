const crypto = require('crypto');
const config = require('../config');
const {
  loadCanonicalCatalog,
  filterVerifiedFoodsForUser,
  calculateNutritionForServing,
} = require('./foodCatalogService');

// Per-user sliding window limiter to protect Gemini free-tier quota
const _userRequests = new Map();
const WINDOW_MS = 10 * 60 * 1000; // 10 minutes
const MAX_REQUESTS_PER_WINDOW = 6;

// Anonymous nutrition-profile plan cache (15 minutes TTL)
const _planCache = new Map();
const CACHE_TTL_MS = 15 * 60 * 1000;

const REQUIRED_MEALS = [
  'breakfast',
  'morning_snack',
  'lunch',
  'evening_snack',
  'dinner',
];

function checkRateLimit(userId) {
  const now = Date.now();
  const key = String(userId);
  const recent = (_userRequests.get(key) || []).filter((t) => now - t < WINDOW_MS);
  if (recent.length >= MAX_REQUESTS_PER_WINDOW) {
    _userRequests.set(key, recent);
    return { allowed: false, retryAfterSec: Math.ceil((WINDOW_MS - (now - recent[0])) / 1000) };
  }
  recent.push(now);
  _userRequests.set(key, recent);
  return { allowed: true };
}

function makeCacheKey(dailyGoal, preferences, instructions) {
  const normalized = JSON.stringify({
    cal: Math.round((dailyGoal.calories || 2000) / 50) * 50,
    diet: preferences.dietaryPreference || 'vegetarian',
    obj: preferences.fitnessObjective || 'maintain_weight',
    allergies: (preferences.allergies || []).slice().sort(),
    excluded: (preferences.excludedFoodIds || []).slice().sort(),
    inst: (instructions || '').trim().toLowerCase(),
  });
  return crypto.createHash('sha256').update(normalized).digest('hex');
}

/**
 * Validates raw AI JSON strictly against our verified food catalogue and
 * recomputes 100% of calories and macros server-side.
 * Rejects any item with an unknown/unverified foodId or invalid quantity.
 */
function validateAndHydrateAiPlan({
  rawAiPayload,
  dailyGoal,
  preferences,
  modelName,
  generatedBy = 'gemini',
  extraCatalogMap = null,
}) {
  if (!rawAiPayload || typeof rawAiPayload !== 'object' || !Array.isArray(rawAiPayload.meals)) {
    throw new Error('INVALID_AI_STRUCTURE: Missing meals array.');
  }

  const excludedSet = new Set(preferences.excludedFoodIds || []);
  const allergySet = new Set((preferences.allergies || []).map((a) => String(a).toLowerCase()));
  const timings = preferences.preferredMealTimings || {};

  const validatedMeals = [];
  let totalCalories = 0;
  let totalProtein = 0;
  let totalCarbs = 0;
  let totalFat = 0;
  let totalFibre = 0;

  for (let i = 0; i < rawAiPayload.meals.length; i++) {
    const rawMeal = rawAiPayload.meals[i];
    if (!rawMeal || !REQUIRED_MEALS.includes(rawMeal.mealCategory) || !Array.isArray(rawMeal.items)) {
      throw new Error(`INVALID_MEAL_CATEGORY: "${rawMeal?.mealCategory}"`);
    }

    const validatedItems = [];
    for (let j = 0; j < rawMeal.items.length; j++) {
      const rawItem = rawMeal.items[j];
      if (!rawItem || typeof rawItem.foodId !== 'string') {
        throw new Error('INVALID_FOOD_ITEM: Missing foodId.');
      }
      if (excludedSet.has(rawItem.foodId)) {
        throw new Error(`EXCLUDED_FOOD_SELECTED: "${rawItem.foodId}"`);
      }

      // Compute authoritative nutrients strictly from verified database (ignores any AI numbers!)
      const servingCount = Number(rawItem.servingCount ?? rawItem.quantity ?? 1);
      const calc = calculateNutritionForServing(
        rawItem.foodId,
        rawItem.servingId,
        servingCount,
        extraCatalogMap
      );

      // Double-check allergens & dietary match
      const foodAllergens = (calc.food.allergenTags || []).map((a) => a.toLowerCase());
      if (foodAllergens.some((a) => allergySet.has(a))) {
        throw new Error(`ALLERGEN_VIOLATION: "${rawItem.foodId}"`);
      }

      totalCalories += calc.calories;
      totalProtein += calc.protein;
      totalCarbs += calc.carbs;
      totalFat += calc.fat;
      totalFibre += calc.fibre;

      validatedItems.push({
        id: crypto.randomUUID(),
        foodId: calc.food.id,
        foodNameSnapshot: calc.food.name,
        illustrationSnapshot: calc.food.illustrationId || 'generic',
        servingId: calc.serving.id,
        servingLabelSnapshot: calc.serving.label,
        servingCount: calc.servingCount,
        gramsPerUnit: calc.gramsPerUnit,
        totalGrams: calc.totalGrams,
        calories: calc.calories,
        protein: calc.protein,
        carbs: calc.carbs,
        fat: calc.fat,
        fibre: calc.fibre,
      });
    }

    if (validatedItems.length > 0) {
      validatedMeals.push({
        id: crypto.randomUUID(),
        mealCategory: rawMeal.mealCategory,
        mealTiming: rawMeal.mealTiming || timings[rawMeal.mealCategory] || '',
        explanation: String(rawMeal.explanation || '').slice(0, 240),
        items: validatedItems,
      });
    }
  }

  if (validatedMeals.length < 3) {
    throw new Error('INSUFFICIENT_MEALS: Validated plan has fewer than 3 meals.');
  }

  const targetCal = Number(dailyGoal.calories || 2000);
  if (totalCalories < Math.max(700, targetCal * 0.55) || totalCalories > targetCal * 1.45) {
    throw new Error(
      `TARGET_OUT_OF_RANGE: Validated calories (${Math.round(totalCalories)}) diverge too far from target (${targetCal}).`
    );
  }

  const now = new Date().toISOString();
  return {
    id: crypto.randomUUID(),
    title: String(rawAiPayload.title || 'Personalized Verified Diet Plan').slice(0, 80),
    targetCalories: targetCal,
    targetProtein: Number(dailyGoal.protein || 75),
    targetCarbs: Number(dailyGoal.carbs || 260),
    targetFat: Number(dailyGoal.fat || 65),
    targetFibre: Number(dailyGoal.fibre || 30),
    dietaryPreference: preferences.dietaryPreference || 'vegetarian',
    fitnessObjective: preferences.fitnessObjective || 'maintain_weight',
    generatedBy,
    modelName: modelName || '',
    aiNotes: String(rawAiPayload.notes || 'Nutrients recalculated from verified food database.').slice(0, 280),
    isAccepted: false,
    isSaved: false,
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    meals: validatedMeals,
  };
}

/**
 * Deterministic rules-based fallback meal planner selecting only verified foods.
 */
function buildRulesBasedPlan({ dailyGoal, preferences }) {
  const eligible = filterVerifiedFoodsForUser({
    dietaryPreference: preferences.dietaryPreference || 'vegetarian',
    allergies: preferences.allergies || [],
    excludedFoodIds: preferences.excludedFoodIds || [],
  });
  const eligibleIds = new Set(eligible.map((f) => f.id));
  const { foodById } = loadCanonicalCatalog();

  function pickFirst(candidates) {
    for (const id of candidates) {
      if (eligibleIds.has(id)) return foodById.get(id);
    }
    return eligible[0] || null;
  }

  const scale = Math.max(0.6, Math.min(1.8, (dailyGoal.calories || 2000) / 2000));
  const snap = (v) => Math.max(0.5, Math.min(4, Math.round(v * scale * 2) / 2));

  function makeDraftItem(candidates, preferredServingId, baseCount) {
    const food = pickFirst(candidates);
    if (!food) return null;
    const serving =
      (food.servings || []).find((s) => s.id === preferredServingId) ||
      (food.servings || [])[0];
    if (!serving) return null;
    return {
      foodId: food.id,
      servingId: serving.id,
      servingCount: snap(baseCount),
    };
  }

  const timings = preferences.preferredMealTimings || {};
  const rawPayload = {
    title: `Balanced ${(preferences.fitnessObjective || 'nutrition').replace(/_/g, ' ')} Plan`,
    notes: 'Rules-based verified meal plan matched to your calorie and dietary profile.',
    meals: [
      {
        mealCategory: 'breakfast',
        mealTiming: timings.breakfast || '08:00',
        explanation: 'Complex carbohydrates paired with steady morning protein.',
        items: [
          makeDraftItem(['poha_veg', 'oats_cooked_water', 'idli_steamed'], 'bowl_poha', 1),
          makeDraftItem(['egg_boiled', 'paneer_fresh', 'tofu_firm', 'milk_toned'], 'one_boiled_egg', 2),
        ].filter(Boolean),
      },
      {
        mealCategory: 'morning_snack',
        mealTiming: timings.morning_snack || '11:00',
        explanation: 'Fresh fruit micronutrients and healthy nuts/seeds.',
        items: [
          makeDraftItem(['apple_raw', 'banana_ripe', 'orange_raw', 'guava_raw'], 'med_apple', 1),
          makeDraftItem(['almonds_raw', 'walnuts_raw', 'chia_seeds'], 'ten_almonds', 1),
        ].filter(Boolean),
      },
      {
        mealCategory: 'lunch',
        mealTiming: timings.lunch || '13:30',
        explanation: 'Balanced whole grains, lentil/legume protein and probiotic curd/veg.',
        items: [
          makeDraftItem(['roti_plain', 'rice_brown_cooked'], 'med_roti', 2),
          makeDraftItem(['dal_plain', 'rajma_curry', 'chole_curry'], 'bowl_dal', 1),
          makeDraftItem(['curd_dahi', 'cucumber_raw', 'carrot_raw'], 'bowl_curd', 1),
        ].filter(Boolean),
      },
      {
        mealCategory: 'evening_snack',
        mealTiming: timings.evening_snack || '17:00',
        explanation: 'Light beverage with fibre-rich fruit or roasted nuts.',
        items: [
          makeDraftItem(['tea_green_plain', 'coffee_black', 'buttermilk_chaas', 'coconut_water'], 'cup_green_tea', 1),
          makeDraftItem(['peanuts_roasted', 'papaya_raw', 'watermelon_raw'], 'handful_peanuts', 1),
        ].filter(Boolean),
      },
      {
        mealCategory: 'dinner',
        mealTiming: timings.dinner || '20:30',
        explanation: 'Satiating evening meal supporting recovery and overnight satiety.',
        items: [
          makeDraftItem(['roti_plain', 'khichdi_moong', 'rice_white_cooked'], 'med_roti', 2),
          makeDraftItem(
            preferences.dietaryPreference === 'non_vegetarian'
              ? ['chicken_breast_cooked', 'chicken_curry', 'paneer_bhurji', 'dal_plain']
              : ['paneer_bhurji', 'tofu_firm', 'dal_plain'],
            'bowl_paneer_bhurji',
            1
          ),
        ].filter(Boolean),
      },
    ],
  };

  return validateAndHydrateAiPlan({
    rawAiPayload: rawPayload,
    dailyGoal,
    preferences,
    modelName: 'rules-v1',
    generatedBy: 'fallback',
  });
}

async function generatePersonalizedDietPlan({
  userId,
  dailyGoal,
  preferences,
  instructions = '',
  fetchImpl = global.fetch,
}) {
  const cacheKey = makeCacheKey(dailyGoal, preferences, instructions);
  const cached = _planCache.get(cacheKey);
  if (cached && Date.now() - cached.createdAt < CACHE_TTL_MS) {
    return {
      plan: { ...cached.plan, id: crypto.randomUUID() },
      usedFallback: cached.usedFallback,
      cached: true,
      notice: cached.notice,
    };
  }

  const apiKey = config.gemini.apiKey;
  const primaryModel = config.gemini.model || 'gemini-3-flash-preview';
  const candidateModels = Array.from(
    new Set([
      primaryModel,
      'gemini-flash-lite-latest',
      'gemini-3.1-flash-lite-preview',
      'gemini-3-flash-preview',
    ])
  );

  if (!apiKey || typeof fetchImpl !== 'function') {
    const fallback = buildRulesBasedPlan({ dailyGoal, preferences });
    return {
      plan: fallback,
      usedFallback: true,
      cached: false,
      notice: 'Gemini API key is not configured on the server. Using verified rules-based planner.',
    };
  }

  const rateCheck = checkRateLimit(userId);
  if (!rateCheck.allowed) {
    const fallback = buildRulesBasedPlan({ dailyGoal, preferences });
    return {
      plan: fallback,
      usedFallback: true,
      cached: false,
      notice: `Rate limit reached (retry in ~${rateCheck.retryAfterSec}s). Used verified rules-based planner instead.`,
    };
  }

  const eligibleFoods = filterVerifiedFoodsForUser({
    dietaryPreference: preferences.dietaryPreference || 'vegetarian',
    allergies: preferences.allergies || [],
    excludedFoodIds: preferences.excludedFoodIds || [],
  });

  // Only send anonymous nutrition targets + catalog menu (zero PII!)
  const compactCatalog = eligibleFoods.map((f) => ({
    id: f.id,
    name: f.name,
    cat: f.categoryId,
    kcal100: f.nutritionPer100g.calories,
    p100: f.nutritionPer100g.protein,
    servings: (f.servings || []).slice(0, 3).map((s) => ({
      id: s.id,
      label: s.label,
      g: s.gramsPerUnit,
    })),
  }));

  const prompt = [
    'You are a nutrition meal-planning assistant.',
    'Select ONLY foodId and servingId values from the ALLOWED_FOODS JSON below.',
    'Do NOT invent foods or calculate nutrition totals yourself; return strictly JSON matching the schema.',
    `TARGET: calories=${dailyGoal.calories} kcal, protein=${dailyGoal.protein}g, carbs=${dailyGoal.carbs}g, fat=${dailyGoal.fat}g, fibre=${dailyGoal.fibre}g.`,
    `PREFERENCES: diet=${preferences.dietaryPreference}, objective=${preferences.fitnessObjective}, timings=${JSON.stringify(preferences.preferredMealTimings || {})}.`,
    instructions ? `USER_NOTE: ${String(instructions).slice(0, 200)}` : '',
    `ALLOWED_FOODS: ${JSON.stringify(compactCatalog)}`,
    'OUTPUT SCHEMA: {"title":"string","notes":"string","meals":[{"mealCategory":"breakfast|morning_snack|lunch|evening_snack|dinner","mealTiming":"HH:MM","explanation":"short string","items":[{"foodId":"id from ALLOWED_FOODS","servingId":"id from that food servings","servingCount":1.0}]}]}',
  ]
    .filter(Boolean)
    .join('\n');

  let lastFailureReason = 'Gemini API unavailable.';
  let lastStatus = null;

  for (const model of candidateModels) {
    try {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`;
      const response = await fetchImpl(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.4,
            responseMimeType: 'application/json',
          },
        }),
      });

      if (!response.ok) {
        lastStatus = response.status;
        lastFailureReason =
          lastStatus === 429
            ? 'Gemini free-tier quota exceeded.'
            : `Gemini API unavailable (${lastStatus}).`;

        // Try backup verified models on model unavailability, overload, or quota limits.
        if (lastStatus === 404 || lastStatus === 429 || lastStatus === 503) {
          continue;
        }
        break;
      }

      const data = await response.json();
      const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
      const cleanedJson = rawText
        .replace(/^```json\s*/i, '')
        .replace(/^```\s*/i, '')
        .replace(/```$/i, '')
        .trim();
      const parsedAi = JSON.parse(cleanedJson);

      const validatedPlan = validateAndHydrateAiPlan({
        rawAiPayload: parsedAi,
        dailyGoal,
        preferences,
        modelName: model,
        generatedBy: 'gemini',
      });

      const result = {
        plan: validatedPlan,
        usedFallback: false,
        cached: false,
        notice: `Generated by ${model} & verified against canonical nutrition database.`,
      };
      _planCache.set(cacheKey, { ...result, createdAt: Date.now() });
      return result;
    } catch (err) {
      lastFailureReason = `AI validation or network error (${err.message}).`;
    }
  }

  const fallback = buildRulesBasedPlan({ dailyGoal, preferences });
  const notice =
    lastStatus === 429
      ? 'Gemini free-tier quota exceeded. Used verified rules-based planner.'
      : `${lastFailureReason} Used verified rules-based planner.`;
  return {
    plan: fallback,
    usedFallback: true,
    cached: false,
    notice,
  };
}

module.exports = {
  validateAndHydrateAiPlan,
  buildRulesBasedPlan,
  generatePersonalizedDietPlan,
  checkRateLimit,
};
