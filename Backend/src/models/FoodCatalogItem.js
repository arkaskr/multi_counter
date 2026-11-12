const mongoose = require('mongoose');

const servingSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    label: { type: String, required: true },
    unitType: { type: String, default: 'piece' },
    gramsPerUnit: { type: Number, required: true, min: 0.1 },
    isDefault: { type: Boolean, default: false },
    sortOrder: { type: Number, default: 0 },
  },
  { _id: false }
);

const foodCatalogItemSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, unique: true, index: true },
    name: { type: String, required: true, index: true },
    commonNames: { type: String, default: '' },
    categoryId: { type: String, required: true, index: true },
    illustrationId: { type: String, default: 'generic' },
    preparationState: { type: String, default: '' },
    dietaryTags: { type: [String], default: [] },
    allergenTags: { type: [String], default: [] },
    sourceName: { type: String, required: true },
    sourceReference: { type: String, required: true },
    sourceLicense: { type: String, default: '' },
    isVerified: { type: Boolean, default: false, index: true },
    isComplete: { type: Boolean, default: true },
    verificationNotes: { type: String, default: '' },
    catalogueVersion: { type: Number, default: 1 },
    nutritionPer100g: {
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
    },
    servings: { type: [servingSchema], default: [] },
  },
  { timestamps: true }
);

module.exports = mongoose.model('FoodCatalogItem', foodCatalogItemSchema);

