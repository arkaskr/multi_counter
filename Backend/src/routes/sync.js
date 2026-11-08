const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const DailyRecord = require('../models/DailyRecord');
const Settings = require('../models/Settings');

/**
 * POST /api/sync
 * Two-way offline sync endpoint
 * Body: {
 *   records: [{ date: '2026-11-08', count: 1, amountOverride: null, updatedAt: '...' }],
 *   settings: { unitAmount: 45, dailyLimit: 2, ... },
 *   lastSyncedAt: '...' (optional)
 * }
 */
router.post('/', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const { records = [], settings, lastSyncedAt } = req.body;

    // 1. Process client records (Last-Write-Wins based on updatedAt)
    if (Array.isArray(records) && records.length > 0) {
      for (const rec of records) {
        if (!rec.date) continue;

        const clientUpdatedAt = rec.updatedAt ? new Date(rec.updatedAt) : new Date();
        const existing = await DailyRecord.findOne({ userId, date: rec.date });

        if (!existing) {
          await DailyRecord.create({
            userId,
            date: rec.date,
            count: Number(rec.count) || 0,
            amountOverride: rec.amountOverride != null ? Number(rec.amountOverride) : null,
            updatedAt: clientUpdatedAt,
          });
        } else {
          const serverUpdatedAt = new Date(existing.updatedAt);
          // If client record is newer or same timestamp, update MongoDB
          if (clientUpdatedAt >= serverUpdatedAt) {
            existing.count = Number(rec.count) || 0;
            existing.amountOverride = rec.amountOverride != null ? Number(rec.amountOverride) : null;
            existing.updatedAt = clientUpdatedAt;
            await existing.save();
          }
        }
      }
    }

    // 2. Process client settings (if provided)
    let currentSettings = await Settings.findOne({ userId });
    if (settings) {
      const clientSettingsUpdatedAt = settings.updatedAt ? new Date(settings.updatedAt) : new Date();

      if (!currentSettings) {
        currentSettings = await Settings.create({
          userId,
          unitAmount: Number(settings.unitAmount) || 45.0,
          dailyLimit: Number(settings.dailyLimit) || 2,
          weekStart: settings.weekStart || 'monday',
          currencySymbol: settings.currencySymbol || '₹',
          selectedTheme: settings.selectedTheme || 'soft_light',
          customThemeConfig: settings.customThemeConfig || null,
          updatedAt: clientSettingsUpdatedAt,
        });
      } else {
        const serverSettingsUpdatedAt = new Date(currentSettings.updatedAt);
        if (clientSettingsUpdatedAt >= serverSettingsUpdatedAt) {
          if (settings.unitAmount != null) currentSettings.unitAmount = Number(settings.unitAmount);
          if (settings.dailyLimit != null) currentSettings.dailyLimit = Number(settings.dailyLimit);
          if (settings.weekStart != null) currentSettings.weekStart = settings.weekStart;
          if (settings.currencySymbol != null) currentSettings.currencySymbol = settings.currencySymbol;
          if (settings.selectedTheme != null) currentSettings.selectedTheme = settings.selectedTheme;
          if (settings.customThemeConfig !== undefined) currentSettings.customThemeConfig = settings.customThemeConfig;
          currentSettings.updatedAt = clientSettingsUpdatedAt;
          await currentSettings.save();
        }
      }
    }

    // 3. Fetch all current records from MongoDB for this user
    const allRecords = await DailyRecord.find({ userId }).sort({ date: -1 });

    const responseRecords = allRecords.map(r => ({
      date: r.date,
      count: r.count,
      amount_override: r.amountOverride,
      updated_at: r.updatedAt.toISOString(),
    }));

    const responseSettings = currentSettings
      ? {
          unit_amount: currentSettings.unitAmount.toString(),
          daily_limit: currentSettings.dailyLimit.toString(),
          week_start: currentSettings.weekStart,
          currency_symbol: currentSettings.currencySymbol,
          selected_theme: currentSettings.selectedTheme,
          custom_theme_config: currentSettings.customThemeConfig,
          updated_at: currentSettings.updatedAt.toISOString(),
        }
      : null;

    return res.status(200).json({
      success: true,
      syncedAt: new Date().toISOString(),
      recordsCount: responseRecords.length,
      records: responseRecords,
      settings: responseSettings,
    });
  } catch (err) {
    console.error('[Sync] POST error:', err);
    return res.status(500).json({ success: false, message: 'Sync failed: ' + err.message });
  }
});

/**
 * GET /api/sync
 * Fetch all cloud records and settings for the authenticated user
 */
router.get('/', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const records = await DailyRecord.find({ userId }).sort({ date: -1 });
    const settings = await Settings.findOne({ userId });

    const formattedRecords = records.map(r => ({
      date: r.date,
      count: r.count,
      amount_override: r.amountOverride,
      updated_at: r.updatedAt.toISOString(),
    }));

    return res.status(200).json({
      success: true,
      records: formattedRecords,
      settings: settings
        ? {
            unit_amount: settings.unitAmount.toString(),
            daily_limit: settings.dailyLimit.toString(),
            week_start: settings.weekStart,
            currency_symbol: settings.currencySymbol,
            selected_theme: settings.selectedTheme,
            custom_theme_config: settings.customThemeConfig,
            updated_at: settings.updatedAt.toISOString(),
          }
        : null,
    });
  } catch (err) {
    console.error('[Sync] GET error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch cloud data.' });
  }
});

module.exports = router;

