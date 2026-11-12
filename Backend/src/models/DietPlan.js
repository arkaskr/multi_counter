const mongoose = require('mongoose');

const dietPlanItemSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    foodId: { type: String, required: true },
    foodNameSnapshot: { type: String, required: true },
    illustrationSnapshot: { type: String, default: 'generic' },
    servingId: { type: String, required: true },
    servingLabelSnapshot: { type: String, required: true },
    servingCount: { type: Number, required: true },
    gramsPerUnit: { type: Number, required: true },
    totalGrams: { type: Number, required: true },
    calories: { type: Number, required: true },
    protein: { type: Number, required: true },
    carbs: { type: Number, required: true },
    fat: { type: Number, required: true },
    fibre: { type: Number, required: true },
  },
  { _id: false }
);

const dietPlanMealSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    mealCategory: { type: String, required: true },
    mealTiming: { type: String, default: '' },
    explanation: { type: String, default: '' },
    items: { type: [dietPlanItemSchema], default: [] },
  },
  { _id: false }
);

const dietPlanSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    id: { type: String, required: true },
    title: { type: String, required: true },
    targetCalories: { type: Number, required: true },
    targetProtein: { type: Number, required: true },
    targetCarbs: { type: Number, required: true },
    targetFat: { type: Number, required: true },
    targetFibre: { type: Number, required: true },
    dietaryPreference: { type: String, required: true },
    fitnessObjective: { type: String, required: true },
    generatedBy: { type: String, default: 'gemini' },
    modelName: { type: String, default: '' },
    aiNotes: { type: String, default: '' },
    isAccepted: { type: Boolean, default: false },
    isSaved: { type: Boolean, default: false },
    createdAt: { type: String, required: true },
    updatedAt: { type: String, required: true },
    isDeleted: { type: Boolean, default: false },
    meals: { type: [dietPlanMealSchema], default: [] },
  },
  { timestamps: false }
);

dietPlanSchema.index({ userId: 1, id: 1 }, { unique: true });

module.exports = mongoose.model('DietPlan', dietPlanSchema);

