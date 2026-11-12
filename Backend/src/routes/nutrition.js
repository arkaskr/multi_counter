const crypto = require('crypto');
const express = require('express');
const authMiddleware = require('../middleware/auth');
const FoodLog = require('../models/FoodLog');
const DailyNutritionGoal = require('../models/DailyNutritionGoal');
const MonthlyNutritionGoal = require('../models/MonthlyNutritionGoal');
const UserNutritionPreference = require('../models/UserNutritionPreference');
const DietPlan = require('../models/DietPlan');
const FoodRequest = require('../models/FoodRequest');
const DailyHydrationLog = require('../models/DailyHydrationLog');
const {
  loadCanonicalCatalog,
  getFoodById,
  filterVerifiedFoodsForUser,
  calculateNutritionForServing,
  ensureMongoCatalogSeeded,
} = require('../services/foodCatalogService');
const { generatePersonalizedDietPlan } = require('../services/geminiDietService');

const router = express.Router();
router.use(authMiddleware);

function daysInCalendarMonth(year, month) {
  return new Date(year, month, 0).getDate();
}

function round1(v) {
  return Math.round((Number(v) || 0) * 10) / 10;
}

// GET /api/nutrition/catalog
router.get('/catalog', async (req, res) => {
  try {
    ensureMongoCatalogSeeded().catch(() => {});
    const { catalog } = loadCanonicalCatalog();
    const { q = '', categoryId = '', dietaryPreference = '' } = req.query;

    let foods = filterVerifiedFoodsForUser({
      dietaryPreference: dietaryPreference || 'non_vegetarian',
    });

    if (categoryId && categoryId !== 'all') {
      foods = foods.filter((f) => f.categoryId === categoryId);
    }
    const needle = String(q).trim().toLowerCase();
    if (needle) {
      foods = foods.filter(
        (f) =>
          f.name.toLowerCase().includes(needle) ||
          (f.commonNames || '').toLowerCase().includes(needle) ||
          (f.preparationState || '').toLowerCase().includes(needle)
      );
    }

    res.json({
      success: true,
      catalogueVersion: catalog.catalogueVersion || 1,
      categories: catalog.categories || [],
      foods,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/nutrition/foods/:id
router.get('/foods/:id', (req, res) => {
  const food = getFoodById(req.params.id);
  if (!food || !food.isVerified) {
    return res.status(404).json({ success: false, message: 'Verified food not found.' });
  }
  res.json({ success: true, food });
});

// GET /api/nutrition/logs
router.get('/logs', async (req, res) => {
  try {
    const userId = req.user._id;
    const { date, startDate, endDate } = req.query;
    const filter = { userId, isDeleted: false };
    if (date) {
      filter.date = String(date);
    } else if (startDate && endDate) {
      filter.date = { $gte: String(startDate), $lte: String(endDate) };
    }
    const logs = await FoodLog.find(filter).sort({ date: 1, loggedAt: 1 }).lean();
    res.json({ success: true, logs });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/nutrition/logs
router.post('/logs', async (req, res) => {
  try {
    const userId = req.user._id;
    const { id, date, mealCategory, foodId, servingId, servingCount = 1, notes = '' } = req.body;
    if (!date || !mealCategory || !foodId || !servingId) {
      return res.status(400).json({ success: false, message: 'date, mealCategory, foodId and servingId are required.' });
    }

    let calc;
    try {
      calc = calculateNutritionForServing(foodId, servingId, servingCount);
    } catch (calcErr) {
      return res.status(400).json({ success: false, message: calcErr.message });
    }

    const now = new Date().toISOString();
    const logId = id || crypto.randomUUID();
    const doc = await FoodLog.findOneAndUpdate(
      { userId, id: logId },
      {
        $set: {
          userId,
          id: logId,
          date: String(date),
          mealCategory,
          foodId: calc.food.id,
          foodNameSnapshot: calc.food.name,
          preparationSnapshot: calc.food.preparationState || '',
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
          sugar: calc.sugar,
          sodiumMg: calc.sodiumMg,
          saturatedFat: calc.saturatedFat,
          potassiumMg: calc.potassiumMg,
          calciumMg: calc.calciumMg,
          ironMg: calc.ironMg,
          vitaminCMg: calc.vitaminCMg,
          sourceSnapshot: calc.food.sourceName || '',
          loggedAt: now,
          updatedAt: now,
          isDeleted: false,
          notes: String(notes || ''),
        },
      },
      { upsert: true, new: true }
    );

    res.status(201).json({ success: true, log: doc });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/nutrition/logs/:id
router.put('/logs/:id', async (req, res) => {
  try {
    const userId = req.user._id;
    const existing = await FoodLog.findOne({ userId, id: req.params.id, isDeleted: false });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Food log not found.' });
    }

    const nextServingId = req.body.servingId || existing.servingId;
    const nextCount = Number(req.body.servingCount ?? existing.servingCount);
    const nextCategory = req.body.mealCategory || existing.mealCategory;

    let calc;
    try {
      calc = calculateNutritionForServing(existing.foodId, nextServingId, nextCount);
    } catch (calcErr) {
      return res.status(400).json({ success: false, message: calcErr.message });
    }

    existing.mealCategory = nextCategory;
    existing.servingId = calc.serving.id;
    existing.servingLabelSnapshot = calc.serving.label;
    existing.servingCount = calc.servingCount;
    existing.gramsPerUnit = calc.gramsPerUnit;
    existing.totalGrams = calc.totalGrams;
    existing.calories = calc.calories;
    existing.protein = calc.protein;
    existing.carbs = calc.carbs;
    existing.fat = calc.fat;
    existing.fibre = calc.fibre;
    existing.sugar = calc.sugar;
    existing.sodiumMg = calc.sodiumMg;
    existing.saturatedFat = calc.saturatedFat;
    existing.potassiumMg = calc.potassiumMg;
    existing.calciumMg = calc.calciumMg;
    existing.ironMg = calc.ironMg;
    existing.vitaminCMg = calc.vitaminCMg;
    existing.updatedAt = new Date().toISOString();
    existing.notes = req.body.notes != null ? String(req.body.notes) : existing.notes;
    await existing.save();

    res.json({ success: true, log: existing });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/nutrition/logs/:id
router.delete('/logs/:id', async (req, res) => {
  try {
    const userId = req.user._id;
    const updated = await FoodLog.findOneAndUpdate(
      { userId, id: req.params.id },
      { $set: { isDeleted: true, updatedAt: new Date().toISOString() } },
      { new: true }
    );
    if (!updated) {
      return res.status(404).json({ success: false, message: 'Food log not found.' });
    }
    res.json({ success: true, message: 'Deleted.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/nutrition/summary/daily?date=YYYY-MM-DD
router.get('/summary/daily', async (req, res) => {
  try {
    const userId = req.user._id;
    const date = String(req.query.date || new Date().toISOString().slice(0, 10));
    const logs = await FoodLog.find({ userId, date, isDeleted: false }).lean();
    const hydration = await DailyHydrationLog.findOne({ userId, date }).lean();

    const goal =
      (await DailyNutritionGoal.findOne({
        userId,
        effectiveFromDate: { $lte: date },
        isDeleted: false,
      })
        .sort({ effectiveFromDate: -1 })
        .lean()) || {
        calories: 2000,
        protein: 75,
        carbs: 260,
        fat: 65,
        fibre: 30,
        hydrationMl: 2500,
      };

    const totals = logs.reduce(
      (acc, l) => {
        acc.calories += l.calories || 0;
        acc.protein += l.protein || 0;
        acc.carbs += l.carbs || 0;
        acc.fat += l.fat || 0;
        acc.fibre += l.fibre || 0;
        return acc;
      },
      { calories: 0, protein: 0, carbs: 0, fat: 0, fibre: 0 }
    );

    res.json({
      success: true,
      date,
      hasRecords: logs.length > 0,
      entryCount: logs.length,
      hydrationMl: hydration ? hydration.amountMl : 0,
      totals: {
        calories: round1(totals.calories),
        protein: round1(totals.protein),
        carbs: round1(totals.carbs),
        fat: round1(totals.fat),
        fibre: round1(totals.fibre),
      },
      goal,
      logs,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/nutrition/analytics/monthly?year=2026&month=11
router.get('/analytics/monthly', async (req, res) => {
  try {
    const userId = req.user._id;
    const now = new Date();
    const year = parseInt(req.query.year || now.getFullYear(), 10);
    const month = parseInt(req.query.month || now.getMonth() + 1, 10);
    const ym = `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}`;
    const totalCalendarDays = daysInCalendarMonth(year, month);
    const startDate = `${ym}-01`;
    const endDate = `${ym}-${String(totalCalendarDays).padStart(2, '0')}`;

    const [logs, dailyGoals, monthlyGoal] = await Promise.all([
      FoodLog.find({
        userId,
        date: { $gte: startDate, $lte: endDate },
        isDeleted: false,
      }).lean(),
      DailyNutritionGoal.find({ userId, isDeleted: false }).sort({ effectiveFromDate: -1 }).lean(),
      MonthlyNutritionGoal.findOne({ userId, yearMonth: ym, isDeleted: false }).lean(),
    ]);

    const byDate = new Map();
    for (const l of logs) {
      if (!byDate.has(l.date)) byDate.set(l.date, []);
      byDate.get(l.date).push(l);
    }

    let daysLogged = 0;
    let daysWithinTarget = 0;
    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFat = 0;
    let totalFibre = 0;

    for (const [date, dayLogs] of byDate.entries()) {
      daysLogged += 1;
      const dayCal = dayLogs.reduce((s, l) => s + (l.calories || 0), 0);
      totalCalories += dayCal;
      totalProtein += dayLogs.reduce((s, l) => s + (l.protein || 0), 0);
      totalCarbs += dayLogs.reduce((s, l) => s + (l.carbs || 0), 0);
      totalFat += dayLogs.reduce((s, l) => s + (l.fat || 0), 0);
      totalFibre += dayLogs.reduce((s, l) => s + (l.fibre || 0), 0);

      const g =
        dailyGoals.find((dg) => dg.effectiveFromDate <= date) || { calories: 2000 };
      if (dayCal >= g.calories * 0.7 && dayCal <= g.calories * 1.1) {
        daysWithinTarget += 1;
      }
    }

    res.json({
      success: true,
      yearMonth: ym,
      totalCalendarDays,
      daysLogged,
      daysWithinTarget,
      totalCalories: round1(totalCalories),
      averageDailyCalories: daysLogged ? round1(totalCalories / daysLogged) : 0,
      averageDailyProtein: daysLogged ? round1(totalProtein / daysLogged) : 0,
      averageDailyCarbs: daysLogged ? round1(totalCarbs / daysLogged) : 0,
      averageDailyFat: daysLogged ? round1(totalFat / daysLogged) : 0,
      averageDailyFibre: daysLogged ? round1(totalFibre / daysLogged) : 0,
      monthlyGoal,
      monthlyProgressPercent:
        monthlyGoal && monthlyGoal.totalCalories > 0
          ? round1((totalCalories / monthlyGoal.totalCalories) * 100)
          : null,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Daily & Monthly Goals & Preferences
router.get('/goals/daily', async (req, res) => {
  const goals = await DailyNutritionGoal.find({
    userId: req.user._id,
    isDeleted: false,
  })
    .sort({ effectiveFromDate: -1 })
    .lean();
  res.json({ success: true, goals });
});

router.post('/goals/daily', async (req, res) => {
  try {
    const userId = req.user._id;
    const {
      id,
      effectiveFromDate = new Date().toISOString().slice(0, 10),
      calories,
      protein,
      carbs,
      fat,
      fibre,
      hydrationMl = null,
      sourceMode = 'manual',
      notes = '',
    } = req.body;
    const now = new Date().toISOString();
    const goal = await DailyNutritionGoal.findOneAndUpdate(
      { userId, effectiveFromDate },
      {
        $set: {
          userId,
          id: id || crypto.randomUUID(),
          effectiveFromDate,
          calories,
          protein,
          carbs,
          fat,
          fibre,
          hydrationMl,
          sourceMode,
          notes,
          updatedAt: now,
          isDeleted: false,
        },
        $setOnInsert: { createdAt: now },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, goal });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

router.get('/goals/monthly', async (req, res) => {
  const goals = await MonthlyNutritionGoal.find({
    userId: req.user._id,
    isDeleted: false,
  })
    .sort({ yearMonth: -1 })
    .lean();
  res.json({ success: true, goals });
});

router.post('/goals/monthly', async (req, res) => {
  try {
    const userId = req.user._id;
    const {
      id,
      yearMonth,
      totalCalories,
      protein = null,
      carbs = null,
      fat = null,
      fibre = null,
      targetDaysWithinGoal = null,
      notes = '',
    } = req.body;
    const now = new Date().toISOString();
    const goal = await MonthlyNutritionGoal.findOneAndUpdate(
      { userId, yearMonth },
      {
        $set: {
          userId,
          id: id || crypto.randomUUID(),
          yearMonth,
          totalCalories,
          protein,
          carbs,
          fat,
          fibre,
          targetDaysWithinGoal,
          notes,
          updatedAt: now,
          isDeleted: false,
        },
        $setOnInsert: { createdAt: now },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, goal });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

router.get('/preferences', async (req, res) => {
  const prefs = await UserNutritionPreference.findOne({ userId: req.user._id }).lean();
  res.json({ success: true, preferences: prefs });
});

router.put('/preferences', async (req, res) => {
  try {
    const userId = req.user._id;
    const prefs = await UserNutritionPreference.findOneAndUpdate(
      { userId },
      {
        $set: {
          ...req.body,
          userId,
          updatedAt: new Date().toISOString(),
        },
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, preferences: prefs });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// Diet Plans & Gemini AI Generation
router.get('/diet-plans', async (req, res) => {
  const plans = await DietPlan.find({ userId: req.user._id, isDeleted: false })
    .sort({ updatedAt: -1 })
    .lean();
  res.json({ success: true, plans });
});

router.post('/diet-plans', async (req, res) => {
  try {
    const userId = req.user._id;
    const planId = req.body.id || crypto.randomUUID();
    const now = new Date().toISOString();
    const plan = await DietPlan.findOneAndUpdate(
      { userId, id: planId },
      {
        $set: {
          ...req.body,
          userId,
          id: planId,
          updatedAt: now,
          isDeleted: false,
        },
        $setOnInsert: { createdAt: req.body.createdAt || now },
      },
      { upsert: true, new: true }
    );
    res.status(201).json({ success: true, plan });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

router.post('/diet-plans/generate', async (req, res) => {
  try {
    const dailyGoal = req.body.dailyGoal || {
      calories: 2000,
      protein: 75,
      carbs: 260,
      fat: 65,
      fibre: 30,
    };
    const preferences =
      req.body.preferences ||
      (await UserNutritionPreference.findOne({ userId: req.user._id }).lean()) || {
        dietaryPreference: 'vegetarian',
        fitnessObjective: 'maintain_weight',
        allergies: [],
        excludedFoodIds: [],
      };

    const result = await generatePersonalizedDietPlan({
      userId: req.user._id,
      dailyGoal,
      preferences,
      instructions: req.body.instructions || '',
    });

    res.json({ success: true, ...result });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Food Requests (remain pending until admin verification)
router.get('/food-requests', async (req, res) => {
  const requests = await FoodRequest.find({ userId: req.user._id })
    .sort({ createdAt: -1 })
    .lean();
  res.json({ success: true, requests });
});

router.post('/food-requests', async (req, res) => {
  try {
    const userId = req.user._id;
    const now = new Date().toISOString();
    const reqId = req.body.id || crypto.randomUUID();
    const doc = await FoodRequest.findOneAndUpdate(
      { userId, id: reqId },
      {
        $set: {
          userId,
          id: reqId,
          foodName: String(req.body.foodName || '').trim(),
          categoryHint: String(req.body.categoryHint || ''),
          brandOrPreparation: String(req.body.brandOrPreparation || ''),
          servingDescription: String(req.body.servingDescription || ''),
          referenceUrlOrNote: String(req.body.referenceUrlOrNote || ''),
          status: 'pending', // Strictly pending until verified
          updatedAt: now,
        },
        $setOnInsert: { createdAt: now },
      },
      { upsert: true, new: true }
    );
    res.status(201).json({ success: true, request: doc });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/nutrition/sync — Offline-first multi-collection sync scoped strictly by req.user._id
router.post('/sync', async (req, res) => {
  try {
    const userId = req.user._id;
    const {
      lastSyncAt,
      foodLogs = [],
      dailyGoals = [],
      monthlyGoals = [],
      preferences = null,
      dietPlans = [],
      foodRequests = [],
      hydrationLogs = [],
    } = req.body || {};

    // 1. Merge Food Logs (enforce verified food check for non-deleted records)
    for (const incoming of foodLogs) {
      if (!incoming.id) continue;
      if (!incoming.isDeleted) {
        const catalogFood = getFoodById(incoming.foodId);
        if (!catalogFood || !catalogFood.isVerified) {
          continue; // Never accept logs for unverified foods
        }
      }
      const existing = await FoodLog.findOne({ userId, id: incoming.id });
      if (!existing || existing.updatedAt <= incoming.updatedAt) {
        await FoodLog.findOneAndUpdate(
          { userId, id: incoming.id },
          { $set: { ...incoming, userId } },
          { upsert: true }
        );
      }
    }

    // 2. Merge Daily Goals
    for (const dg of dailyGoals) {
      if (!dg.effectiveFromDate) continue;
      const existing = await DailyNutritionGoal.findOne({
        userId,
        effectiveFromDate: dg.effectiveFromDate,
      });
      if (!existing || existing.updatedAt <= dg.updatedAt) {
        await DailyNutritionGoal.findOneAndUpdate(
          { userId, effectiveFromDate: dg.effectiveFromDate },
          { $set: { ...dg, userId } },
          { upsert: true }
        );
      }
    }

    // 3. Merge Monthly Goals
    for (const mg of monthlyGoals) {
      if (!mg.yearMonth) continue;
      const existing = await MonthlyNutritionGoal.findOne({
        userId,
        yearMonth: mg.yearMonth,
      });
      if (!existing || existing.updatedAt <= mg.updatedAt) {
        await MonthlyNutritionGoal.findOneAndUpdate(
          { userId, yearMonth: mg.yearMonth },
          { $set: { ...mg, userId } },
          { upsert: true }
        );
      }
    }

    // 4. Merge Preferences
    if (preferences && preferences.updatedAt) {
      const existing = await UserNutritionPreference.findOne({ userId });
      if (!existing || existing.updatedAt <= preferences.updatedAt) {
        await UserNutritionPreference.findOneAndUpdate(
          { userId },
          { $set: { ...preferences, userId } },
          { upsert: true }
        );
      }
    }

    // 5. Merge Diet Plans
    for (const dp of dietPlans) {
      if (!dp.id) continue;
      const existing = await DietPlan.findOne({ userId, id: dp.id });
      if (!existing || existing.updatedAt <= dp.updatedAt) {
        await DietPlan.findOneAndUpdate(
          { userId, id: dp.id },
          { $set: { ...dp, userId } },
          { upsert: true }
        );
      }
    }

    // 6. Merge Food Requests (status stays server-controlled for new pending requests)
    for (const fr of foodRequests) {
      if (!fr.id) continue;
      const existing = await FoodRequest.findOne({ userId, id: fr.id });
      if (!existing) {
        await FoodRequest.create({ ...fr, userId, status: 'pending' });
      }
    }

    // 7. Merge Hydration Logs
    for (const hl of hydrationLogs) {
      if (!hl.date) continue;
      const existing = await DailyHydrationLog.findOne({ userId, date: hl.date });
      if (!existing || existing.updatedAt <= hl.updatedAt) {
        await DailyHydrationLog.findOneAndUpdate(
          { userId, date: hl.date },
          { $set: { ...hl, userId } },
          { upsert: true }
        );
      }
    }

    // 8. Fetch server delta changes since lastSyncAt
    const deltaFilter = lastSyncAt
      ? { userId, updatedAt: { $gt: lastSyncAt } }
      : { userId };

    const [
      serverLogs,
      serverDailyGoals,
      serverMonthlyGoals,
      serverPrefs,
      serverPlans,
      serverRequests,
      serverHydration,
    ] = await Promise.all([
      FoodLog.find(deltaFilter).lean(),
      DailyNutritionGoal.find(deltaFilter).lean(),
      MonthlyNutritionGoal.find(deltaFilter).lean(),
      UserNutritionPreference.findOne({ userId }).lean(),
      DietPlan.find(deltaFilter).lean(),
      FoodRequest.find(deltaFilter).lean(),
      DailyHydrationLog.find(deltaFilter).lean(),
    ]);

    res.json({
      success: true,
      serverTime: new Date().toISOString(),
      foodLogs: serverLogs,
      dailyGoals: serverDailyGoals,
      monthlyGoals: serverMonthlyGoals,
      preferences: serverPrefs,
      dietPlans: serverPlans,
      foodRequests: serverRequests,
      hydrationLogs: serverHydration,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;

