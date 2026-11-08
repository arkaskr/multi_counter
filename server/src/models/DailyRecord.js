const mongoose = require('mongoose');

const DailyRecordSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    date: {
      type: String, // YYYY-MM-DD
      required: true,
    },
    count: {
      type: Number,
      default: 0,
    },
    amountOverride: {
      type: Number,
      default: null,
    },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

DailyRecordSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('DailyRecord', DailyRecordSchema);

