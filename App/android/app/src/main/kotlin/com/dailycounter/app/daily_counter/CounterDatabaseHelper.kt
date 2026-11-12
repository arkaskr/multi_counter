package com.dailycounter.app.daily_counter

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class DailyRecordData(
    val date: String,
    val count: Int,
    val amountOverride: Double?,
    val updatedAt: String
) {
    fun calculateAmount(unitAmount: Double): Double {
        return amountOverride ?: (count * unitAmount)
    }
}

data class WidgetDisplayData(
    val date: String,
    val displayDate: String,
    val count: Int,
    val dailyLimit: Int,
    val totalAmount: Double,
    val totalMeals: Int,
    val currencySymbol: String,
    val selectedTheme: String,
    val isCompleted: Boolean
)

class CounterDatabaseHelper(context: Context) : SQLiteOpenHelper(
    context,
    DATABASE_NAME,
    null,
    DATABASE_VERSION
) {
    companion object {
        const val DATABASE_NAME = "daily_counter.db"
        // Must stay >= DatabaseConstants.databaseVersion in Flutter (lib/core/constants/database_constants.dart)
        const val DATABASE_VERSION = 2

        // Table: daily_records
        const val TABLE_DAILY_RECORDS = "daily_records"
        const val COL_ID = "id"
        const val COL_DATE = "date"
        const val COL_COUNT = "count"
        const val COL_AMOUNT_OVERRIDE = "amount_override"
        const val COL_UPDATED_AT = "updated_at"

        // Table: app_settings
        const val TABLE_APP_SETTINGS = "app_settings"
        const val COL_KEY = "key"
        const val COL_VALUE = "value"

        // Keys
        const val KEY_UNIT_AMOUNT = "unit_amount"
        const val KEY_DAILY_LIMIT = "daily_limit"
        const val KEY_WEEK_START = "week_start"
        const val KEY_CURRENCY_SYMBOL = "currency_symbol"
        const val KEY_SELECTED_THEME = "selected_theme"
        const val KEY_CHECKPOINT_DATE = "checkpoint_date"
    }

    init {
        try {
            setWriteAheadLoggingEnabled(true)
        } catch (_: Throwable) {}
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        try {
            db.setForeignKeyConstraintsEnabled(true)
        } catch (_: Throwable) {}
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_DAILY_RECORDS (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_DATE TEXT UNIQUE NOT NULL,
                $COL_COUNT INTEGER NOT NULL DEFAULT 0,
                $COL_AMOUNT_OVERRIDE REAL,
                $COL_UPDATED_AT TEXT NOT NULL
            );
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE INDEX IF NOT EXISTS idx_daily_records_date 
            ON $TABLE_DAILY_RECORDS ($COL_DATE);
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_APP_SETTINGS (
                $COL_KEY TEXT PRIMARY KEY NOT NULL,
                $COL_VALUE TEXT NOT NULL
            );
            """.trimIndent()
        )

        // Seed defaults
        val initial = listOf(
            KEY_UNIT_AMOUNT to "55.0",
            KEY_DAILY_LIMIT to "2",
            KEY_WEEK_START to "monday",
            KEY_CURRENCY_SYMBOL to "₹",
            KEY_SELECTED_THEME to "midnight_dark",
            KEY_CHECKPOINT_DATE to ""
        )
        for ((k, v) in initial) {
            val cv = ContentValues().apply {
                put(COL_KEY, k)
                put(COL_VALUE, v)
            }
            db.insertWithOnConflict(TABLE_APP_SETTINGS, null, cv, SQLiteDatabase.CONFLICT_IGNORE)
        }
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Nutrition tables are managed idempotently by Flutter on open/upgrade; ensure base widget tables exist.
        if (oldVersion < 2) {
            onCreate(db)
        }
    }

    fun getTodayString(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        return sdf.format(Date())
    }

    fun getFormattedDisplayDate(): String {
        val sdf = SimpleDateFormat("EEE, d MMM", Locale.getDefault())
        return sdf.format(Date())
    }

    fun getSetting(key: String, defaultValue: String): String {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_APP_SETTINGS,
            arrayOf(COL_VALUE),
            "$COL_KEY = ?",
            arrayOf(key),
            null,
            null,
            null
        )
        cursor.use {
            if (it.moveToFirst()) {
                return it.getString(0) ?: defaultValue
            }
        }
        return defaultValue
    }

    fun getDailyLimit(): Int {
        return getSetting(KEY_DAILY_LIMIT, "2").toIntOrNull() ?: 2
    }

    fun getUnitAmount(): Double {
        return getSetting(KEY_UNIT_AMOUNT, "55.0").toDoubleOrNull() ?: 55.0
    }

    fun getCurrencySymbol(): String {
        return getSetting(KEY_CURRENCY_SYMBOL, "₹")
    }

    fun getSelectedTheme(): String {
        return getSetting(KEY_SELECTED_THEME, "midnight_dark")
    }

    fun getCheckpointDate(): String {
        return getSetting(KEY_CHECKPOINT_DATE, "").trim()
    }

    fun getRecord(date: String): DailyRecordData {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_DAILY_RECORDS,
            arrayOf(COL_COUNT, COL_AMOUNT_OVERRIDE, COL_UPDATED_AT),
            "$COL_DATE = ?",
            arrayOf(date),
            null,
            null,
            null
        )
        cursor.use {
            if (it.moveToFirst()) {
                val count = it.getInt(0)
                val override = if (it.isNull(1)) null else it.getDouble(1)
                val updatedAt = it.getString(2) ?: ""
                return DailyRecordData(date, count, override, updatedAt)
            }
        }
        return DailyRecordData(date, 0, null, "")
    }

    fun getTodayRecord(): DailyRecordData {
        return getRecord(getTodayString())
    }

    /**
     * Total amount for the current billing cycle (records with date > checkpoint_date).
     * If no checkpoint is set, calculates across all records.
     */
    fun getCycleTotalAmount(): Double {
        val db = readableDatabase
        val unitAmount = getUnitAmount()
        val checkpoint = getCheckpointDate()
        val cursor = if (checkpoint.isNotEmpty()) {
            db.rawQuery(
                "SELECT SUM(COALESCE($COL_AMOUNT_OVERRIDE, $COL_COUNT * ?)) FROM $TABLE_DAILY_RECORDS WHERE $COL_DATE > ?",
                arrayOf(unitAmount.toString(), checkpoint)
            )
        } else {
            db.rawQuery(
                "SELECT SUM(COALESCE($COL_AMOUNT_OVERRIDE, $COL_COUNT * ?)) FROM $TABLE_DAILY_RECORDS",
                arrayOf(unitAmount.toString())
            )
        }
        cursor.use {
            if (it.moveToFirst() && !it.isNull(0)) {
                return it.getDouble(0)
            }
        }
        return 0.0
    }

    /**
     * Total meals for the current billing cycle (records with date > checkpoint_date).
     * If no checkpoint is set, calculates across all records.
     */
    fun getCycleMeals(): Int {
        val db = readableDatabase
        val checkpoint = getCheckpointDate()
        val cursor = if (checkpoint.isNotEmpty()) {
            db.rawQuery(
                "SELECT SUM($COL_COUNT) FROM $TABLE_DAILY_RECORDS WHERE $COL_DATE > ?",
                arrayOf(checkpoint)
            )
        } else {
            db.rawQuery(
                "SELECT SUM($COL_COUNT) FROM $TABLE_DAILY_RECORDS",
                null
            )
        }
        var count = 0
        cursor.use {
            if (it.moveToFirst() && !it.isNull(0)) {
                count = it.getInt(0)
            }
        }
        return count
    }

    fun getTotalAmount(): Double {
        return getCycleTotalAmount()
    }

    fun getWidgetDisplayData(): WidgetDisplayData {
        val today = getTodayString()
        val record = getTodayRecord()
        val limit = getDailyLimit()
        val symbol = getCurrencySymbol()
        val theme = getSelectedTheme()
        val totalAmount = getCycleTotalAmount()
        val totalMeals = getCycleMeals()
        val isCompleted = record.count >= limit

        return WidgetDisplayData(
            date = today,
            displayDate = getFormattedDisplayDate(),
            count = record.count,
            dailyLimit = limit,
            totalAmount = totalAmount,
            totalMeals = totalMeals,
            currencySymbol = symbol,
            selectedTheme = theme,
            isCompleted = isCompleted
        )
    }

    /**
     * Increment today's counter atomically.
     * Returns true if incremented, false if limit already reached.
     */
    fun incrementToday(): Boolean {
        val db = writableDatabase
        val today = getTodayString()
        val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())

        db.beginTransaction()
        try {
            val limit = getDailyLimit()
            val currentRecord = getRecord(today)

            if (currentRecord.count >= limit) {
                return false // Limit reached
            }

            val newCount = currentRecord.count + 1
            val cv = ContentValues().apply {
                put(COL_DATE, today)
                put(COL_COUNT, newCount)
                if (currentRecord.amountOverride != null) {
                    put(COL_AMOUNT_OVERRIDE, currentRecord.amountOverride)
                }
                put(COL_UPDATED_AT, nowIso)
            }

            db.insertWithOnConflict(
                TABLE_DAILY_RECORDS,
                null,
                cv,
                SQLiteDatabase.CONFLICT_REPLACE
            )

            db.setTransactionSuccessful()
            return true
        } finally {
            db.endTransaction()
        }
    }
}
