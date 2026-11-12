const mongoose = require('mongoose');

const foodRequestSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    id: { type: String, required: true },
    foodName: { type: String, required: true },
    categoryHint: { type: String, default: '' },
    brandOrPreparation: { type: String, default: '' },
    servingDescription: { type: String, default: '' },
    referenceUrlOrNote: { type: String, default: '' },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
    adminNotes: { type: String, default: '' },
    createdAt: { type: String, required: true },
    updatedAt: { type: String, required: true },
  },
  { timestamps: false }
);

foodRequestSchema.index({ userId: 1, id: 1 }, { unique: true });

module.exports = mongoose.model('FoodRequest', foodRequestSchema);

