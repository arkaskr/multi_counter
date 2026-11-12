const mongoose = require('mongoose');

const userNutritionPreferenceSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    dietaryPreference: {
      type: String,
      enum: ['vegetarian', 'eggetarian', 'non_vegetarian', 'vegan'],
      default: 'vegetarian',
    },
    allergies: { type: [String], default: [] },
    excludedFoodIds: { type: [String], default: [] },
    preferredMealTimings: {
      type: Map,
      of: String,
      default: {
        breakfast: '08:00',
        morning_snack: '11:00',
        lunch: '13:30',
        evening_snack: '17:00',
        dinner: '20:30',
      },
    },
    fitnessObjective: {
      type: String,
      enum: ['maintain_weight', 'lose_weight', 'gain_weight', 'improve_nutrition'],
      default: 'maintain_weight',
    },
    age: { type: Number, default: null },
    sex: { type: String, default: null },
    heightCm: { type: Number, default: null },
    weightKg: { type: Number, default: null },
    activityLevel: { type: String, default: 'moderate' },
    updatedAt: { type: String, required: true },
  },
  { timestamps: false }
);

module.exports = mongoose.model('UserNutritionPreference', userNutritionPreferenceSchema);

