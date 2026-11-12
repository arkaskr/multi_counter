const mongoose = require('mongoose');

const dailyHydrationLogSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    id: { type: String, required: true },
    date: { type: String, required: true }, // YYYY-MM-DD
    amountMl: { type: Number, required: true, min: 0, max: 15000 },
    updatedAt: { type: String, required: true },
  },
  { timestamps: false }
);

dailyHydrationLogSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('DailyHydrationLog', dailyHydrationLogSchema);

