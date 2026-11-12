const mongoose = require('mongoose');

const dailyNutritionGoalSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    id: { type: String, required: true },
    effectiveFromDate: { type: String, required: true }, // YYYY-MM-DD
    calories: { type: Number, required: true, min: 800, max: 10000 },
    protein: { type: Number, required: true, min: 0 },
    carbs: { type: Number, required: true, min: 0 },
    fat: { type: Number, required: true, min: 0 },
    fibre: { type: Number, required: true, min: 0 },
    hydrationMl: { type: Number, default: null },
    sourceMode: { type: String, default: 'manual' },
    notes: { type: String, default: '' },
    createdAt: { type: String, required: true },
    updatedAt: { type: String, required: true },
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: false }
);

dailyNutritionGoalSchema.index({ userId: 1, effectiveFromDate: 1 }, { unique: true });

module.exports = mongoose.model('DailyNutritionGoal', dailyNutritionGoalSchema);

