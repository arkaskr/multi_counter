const fs = require('fs');
const path = require('path');
const FoodCatalogItem = require('../models/FoodCatalogItem');

const CATALOG_PATH = path.resolve(__dirname, '../data/food_catalogue.json');

let _cachedCatalog = null;
let _foodById = null;

function loadCanonicalCatalog() {
  if (_cachedCatalog && _foodById) {
    return { catalog: _cachedCatalog, foodById: _foodById };
  }
  const raw = fs.readFileSync(CATALOG_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  const byId = new Map();
  for (const food of parsed.foods || []) {
    byId.set(food.id, food);
  }
  _cachedCatalog = parsed;
  _foodById = byId;
  return { catalog: _cachedCatalog, foodById: _foodById };
}

function getFoodById(foodId) {
  const { foodById } = loadCanonicalCatalog();
  return foodById.get(foodId) || null;
}

function matchesDietaryPreference(food, dietaryPreference) {
  const tags = food.dietaryTags || [];
  switch (dietaryPreference) {
    case 'vegan':
      return tags.includes('vegan');
    case 'vegetarian':
      return tags.includes('vegetarian') || tags.includes('vegan');
    case 'eggetarian':
      return tags.includes('vegetarian') || tags.includes('vegan') || tags.includes('eggetarian');
    case 'non_vegetarian':
    default:
      return true;
  }
}

function filterVerifiedFoodsForUser({
  dietaryPreference = 'vegetarian',
  allergies = [],
  excludedFoodIds = [],
} = {}) {
  const { catalog } = loadCanonicalCatalog();
  const excludedSet = new Set(excludedFoodIds);
  const allergySet = new Set(allergies.map((a) => String(a).trim().toLowerCase()));

  return (catalog.foods || []).filter((food) => {
    if (!food.isVerified) return false;
    if (excludedSet.has(food.id)) return false;
    if (!matchesDietaryPreference(food, dietaryPreference)) return false;
    const foodAllergens = (food.allergenTags || []).map((a) => a.toLowerCase());
    if (
      foodAllergens.some((fa) =>
        Array.from(allergySet).some((a) => fa === a || fa.includes(a) || a.includes(fa))
      )
    ) {
      return false;
    }
    return true;
  });
}

function round1(val) {
  return Math.round(val * 10) / 10;
}

function round2(val) {
  return Math.round(val * 100) / 100;
}

/**
 * Computes exact authoritative nutrition from verified per-100g catalogue values.
 */
function calculateNutritionForServing(foodId, servingId, servingCount, extraCatalogMap = null) {
  const food = extraCatalogMap ? extraCatalogMap.get(foodId) : getFoodById(foodId);
  if (!food) {
    throw new Error(`UNKNOWN_FOOD: "${foodId}" is not in the approved catalogue.`);
  }
  if (!food.isVerified) {
    throw new Error(`UNVERIFIED_FOOD: "${foodId}" is not verified and cannot be logged.`);
  }
  const count = Number(servingCount);
  if (!Number.isFinite(count) || count <= 0 || count > 25) {
    throw new Error(`INVALID_QUANTITY: servingCount "${servingCount}" must be between 0 and 25.`);
  }

  let serving = (food.servings || []).find((s) => s.id === servingId);
  if (!serving && servingId === 'g_100') {
    serving = { id: 'g_100', label: '100 g', unitType: 'gram', gramsPerUnit: 100 };
  }
  if (!serving) {
    throw new Error(`INVALID_SERVING: servingId "${servingId}" does not belong to "${foodId}".`);
  }

  const totalGrams = serving.gramsPerUnit * count;
  const factor = totalGrams / 100.0;
  const p100 = food.nutritionPer100g;

  const scaleOpt = (v) => (v == null ? null : round2(v * factor));

  return {
    food,
    serving,
    servingCount: count,
    gramsPerUnit: serving.gramsPerUnit,
    totalGrams: round1(totalGrams),
    calories: round1(p100.calories * factor),
    protein: round1(p100.protein * factor),
    carbs: round1(p100.carbs * factor),
    fat: round1(p100.fat * factor),
    fibre: round1(p100.fibre * factor),
    sugar: scaleOpt(p100.sugar),
    sodiumMg: scaleOpt(p100.sodiumMg),
    saturatedFat: scaleOpt(p100.saturatedFat),
    potassiumMg: scaleOpt(p100.potassiumMg),
    calciumMg: scaleOpt(p100.calciumMg),
    ironMg: scaleOpt(p100.ironMg),
    vitaminCMg: scaleOpt(p100.vitaminCMg),
  };
}

let _mongoSeedPromise = null;

async function ensureMongoCatalogSeeded() {
  if (_mongoSeedPromise) return _mongoSeedPromise;
  _mongoSeedPromise = (async () => {
    const existingCount = await FoodCatalogItem.countDocuments();
    const { catalog } = loadCanonicalCatalog();
    if (existingCount >= (catalog.foods || []).length) return;

    const ops = (catalog.foods || []).map((food) => ({
      updateOne: {
        filter: { id: food.id },
        update: {
          $set: {
            ...food,
            catalogueVersion: catalog.catalogueVersion || 1,
          },
        },
        upsert: true,
      },
    }));
    if (ops.length > 0) {
      await FoodCatalogItem.bulkWrite(ops, { ordered: false });
    }
  })().catch((err) => {
    _mongoSeedPromise = null;
    throw err;
  });
  return _mongoSeedPromise;
}

module.exports = {
  loadCanonicalCatalog,
  getFoodById,
  matchesDietaryPreference,
  filterVerifiedFoodsForUser,
  calculateNutritionForServing,
  ensureMongoCatalogSeeded,
};
