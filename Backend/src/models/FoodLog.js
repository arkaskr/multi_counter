const mongoose = require('mongoose');

const foodLogSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    id: { type: String, required: true }, // client UUID
    date: { type: String, required: true }, // YYYY-MM-DD
    mealCategory: {
      type: String,
      required: true,
      enum: ['breakfast', 'morning_snack', 'lunch', 'evening_snack', 'dinner', 'other'],
    },
    foodId: { type: String, required: true },
    foodNameSnapshot: { type: String, required: true },
    preparationSnapshot: { type: String, default: '' },
    illustrationSnapshot: { type: String, default: 'generic' },
    servingId: { type: String, required: true },
    servingLabelSnapshot: { type: String, required: true },
    servingCount: { type: Number, required: true, min: 0.01 },
    gramsPerUnit: { type: Number, required: true, min: 0.1 },
    totalGrams: { type: Number, required: true, min: 0 },
    calories: { type: Number, required: true, min: 0 },
    protein: { type: Number, required: true, min: 0 },
    carbs: { type: Number, required: true, min: 0 },
    fat: { type: Number, required: true, min: 0 },
    fibre: { type: Number, required: true, min: 0 },
    sugar: { type: Number, default: null },
    sodiumMg: { type: Number, default: null },
    saturatedFat: { type: Number, default: null },
    potassiumMg: { type: Number, default: null },
    calciumMg: { type: Number, default: null },
    ironMg: { type: Number, default: null },
    vitaminCMg: { type: Number, default: null },
    sourceSnapshot: { type: String, default: '' },
    loggedAt: { type: String, required: true },
    updatedAt: { type: String, required: true },
    isDeleted: { type: Boolean, default: false },
    serverVersion: { type: Number, default: 1 },
    notes: { type: String, default: '' },
  },
  { timestamps: false }
);

foodLogSchema.index({ userId: 1, id: 1 }, { unique: true });
foodLogSchema.index({ userId: 1, date: 1, isDeleted: 1 });
foodLogSchema.index({ userId: 1, updatedAt: 1 });

module.exports = mongoose.model('FoodLog', foodLogSchema);

