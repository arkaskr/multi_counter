const assert = require('assert');
const {
  loadCanonicalCatalog,
  calculateNutritionForServing,
  filterVerifiedFoodsForUser,
} = require('../src/services/foodCatalogService');
const {
  validateAndHydrateAiPlan,
  buildRulesBasedPlan,
  generatePersonalizedDietPlan,
  checkRateLimit,
} = require('../src/services/geminiDietService');

async function runTests() {
  console.log('Running Backend Calorie Counter / Nutrition tests...');

  // 1. Canonical catalog verification & formula check
  const { catalog } = loadCanonicalCatalog();
  assert(catalog.categories.length === 8, 'Expected 8 food categories');
  assert(catalog.foods.length >= 80, 'Expected >= 80 verified foods');

  const rotiCalc = calculateNutritionForServing('roti_plain', 'med_roti', 2);
  assert.strictEqual(rotiCalc.totalGrams, 70);
  assert(Math.abs(rotiCalc.calories - 240 * 0.7) < 0.2, 'Roti calories match 70% of 100g');

  // 2. Reject unknown or unverified foodId
  assert.throws(
    () => calculateNutritionForServing('unknown_food_xyz', 'g_100', 1),
    /UNKNOWN_FOOD/
  );
  const fakeCatalogMap = new Map([
    [
      'unverified_item',
      {
        id: 'unverified_item',
        name: 'Mystery Unverified',
        isVerified: false,
        nutritionPer100g: { calories: 100, protein: 5, carbs: 10, fat: 2, fibre: 1 },
        servings: [{ id: 'g_100', label: '100 g', gramsPerUnit: 100 }],
      },
    ],
  ]);
  assert.throws(
    () => calculateNutritionForServing('unverified_item', 'g_100', 1, fakeCatalogMap),
    /UNVERIFIED_FOOD/
  );

  // 3. Dietary & allergen filtering
  const veganFoods = filterVerifiedFoodsForUser({
    dietaryPreference: 'vegan',
    allergies: ['nuts'],
    excludedFoodIds: ['tofu_firm'],
  });
  assert(!veganFoods.some((f) => f.id === 'chicken_breast_cooked'), 'Vegan excludes chicken');
  assert(!veganFoods.some((f) => f.id === 'almonds_raw'), 'Nut allergy excludes almonds');
  assert(!veganFoods.some((f) => f.id === 'tofu_firm'), 'Excluded list excludes tofu');

  // 4. Gemini validation rejects hallucinated/unknown foodIds
  const badAiPayload = {
    title: 'Bad Plan',
    meals: [
      {
        mealCategory: 'breakfast',
        items: [{ foodId: 'hallucinated_magic_shake', servingId: 'g_100', servingCount: 1 }],
      },
      { mealCategory: 'lunch', items: [{ foodId: 'dal_plain', servingId: 'bowl_dal', servingCount: 1 }] },
      { mealCategory: 'dinner', items: [{ foodId: 'roti_plain', servingId: 'med_roti', servingCount: 2 }] },
    ],
  };
  assert.throws(
    () =>
      validateAndHydrateAiPlan({
        rawAiPayload: badAiPayload,
        dailyGoal: { calories: 2000, protein: 75, carbs: 260, fat: 65, fibre: 30 },
        preferences: { dietaryPreference: 'vegetarian', allergies: [], excludedFoodIds: [] },
      }),
    /UNKNOWN_FOOD/
  );

  // 5. Gemini validation ignores AI calorie guesses & computes from verified catalog
  const validAiPayload = {
    title: 'Indian Balanced Day',
    meals: [
      {
        mealCategory: 'breakfast',
        mealTiming: '08:30',
        explanation: 'High fibre breakfast',
        items: [
          { foodId: 'poha_veg', servingId: 'bowl_poha', servingCount: 1.5, calories: 9999 }, // fake AI cal!
          { foodId: 'milk_toned', servingId: 'glass_toned_milk', servingCount: 1 },
        ],
      },
      {
        mealCategory: 'morning_snack',
        mealTiming: '11:00',
        items: [{ foodId: 'banana_ripe', servingId: 'med_banana', servingCount: 1 }],
      },
      {
        mealCategory: 'lunch',
        mealTiming: '13:30',
        items: [
          { foodId: 'roti_plain', servingId: 'med_roti', servingCount: 3 },
          { foodId: 'dal_plain', servingId: 'bowl_dal', servingCount: 1.5 },
          { foodId: 'curd_dahi', servingId: 'bowl_curd', servingCount: 1 },
        ],
      },
      {
        mealCategory: 'evening_snack',
        mealTiming: '17:00',
        items: [
          { foodId: 'tea_green_plain', servingId: 'cup_green_tea', servingCount: 1 },
          { foodId: 'almonds_raw', servingId: 'ten_almonds', servingCount: 1 },
        ],
      },
      {
        mealCategory: 'dinner',
        mealTiming: '20:30',
        items: [
          { foodId: 'roti_plain', servingId: 'med_roti', servingCount: 2 },
          { foodId: 'paneer_bhurji', servingId: 'bowl_paneer_bhurji', servingCount: 1 },
        ],
      },
    ],
  };

  const validated = validateAndHydrateAiPlan({
    rawAiPayload: validAiPayload,
    dailyGoal: { calories: 2000, protein: 75, carbs: 260, fat: 65, fibre: 30 },
    preferences: { dietaryPreference: 'vegetarian', allergies: [], excludedFoodIds: [] },
    modelName: 'gemini-2.5-flash',
  });
  const pohaItem = validated.meals[0].items[0];
  assert.notStrictEqual(pohaItem.calories, 9999, 'Must overwrite hallucinated AI calories');
  assert(pohaItem.calories > 200 && pohaItem.calories < 600, 'Uses verified Poha calories');

  // 6. Rules-based fallback works reliably
  const fallback = buildRulesBasedPlan({
    dailyGoal: { calories: 2000, protein: 75, carbs: 260, fat: 65, fibre: 30 },
    preferences: { dietaryPreference: 'vegetarian', fitnessObjective: 'maintain_weight', allergies: [], excludedFoodIds: [] },
  });
  assert(fallback.meals.length === 5, 'Fallback produces 5 meals');
  assert.strictEqual(fallback.generatedBy, 'fallback');

  // 7. generatePersonalizedDietPlan falls back gracefully without key / network
  const genRes = await generatePersonalizedDietPlan({
    userId: 'test_user_nokey',
    dailyGoal: { calories: 1900, protein: 75, carbs: 230, fat: 60, fibre: 28 },
    preferences: { dietaryPreference: 'vegan', allergies: [], excludedFoodIds: [] },
    fetchImpl: null,
  });
  assert(genRes.usedFallback === true);
  assert(genRes.plan.meals.length >= 4);

  // 8. Rate limiter blocks excess requests within window
  const testLimiterId = `rate_${Date.now()}`;
  for (let i = 0; i < 6; i++) {
    assert.strictEqual(checkRateLimit(testLimiterId).allowed, true);
  }
  assert.strictEqual(checkRateLimit(testLimiterId).allowed, false);

  console.log('All Backend Calorie Counter tests passed cleanly!');
}

runTests().catch((err) => {
  console.error('TEST FAILED:', err);
  process.exit(1);
});
