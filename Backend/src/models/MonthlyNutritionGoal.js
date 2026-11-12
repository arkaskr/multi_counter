const mongoose = require('mongoose');

const monthlyNutritionGoalSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    id: { type: String, required: true },
    yearMonth: { type: String, required: true }, // YYYY-MM
    totalCalories: { type: Number, required: true, min: 1 },
    protein: { type: Number, default: null },
    carbs: { type: Number, default: null },
    fat: { type: Number, default: null },
    fibre: { type: Number, default: null },
    targetDaysWithinGoal: { type: Number, default: null },
    notes: { type: String, default: '' },
    createdAt: { type: String, required: true },
    updatedAt: { type: String, required: true },
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: false }
);

monthlyNutritionGoalSchema.index({ userId: 1, yearMonth: 1 }, { unique: true });

module.exports = mongoose.model('MonthlyNutritionGoal', monthlyNutritionGoalSchema);

