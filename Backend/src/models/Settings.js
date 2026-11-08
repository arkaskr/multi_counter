const mongoose = require('mongoose');

const SettingsSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    unitAmount: {
      type: Number,
      default: 45.0,
    },
    dailyLimit: {
      type: Number,
      default: 2,
    },
    weekStart: {
      type: String,
      default: 'monday',
    },
    currencySymbol: {
      type: String,
      default: '₹',
    },
    selectedTheme: {
      type: String,
      default: 'soft_light',
    },
    customThemeConfig: {
      type: String,
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

module.exports = mongoose.model('Settings', SettingsSchema);

