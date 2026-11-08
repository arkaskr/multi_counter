import 'package:flutter_test/flutter_test.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/core/utils/currency_utils.dart';
import 'package:daily_counter/shared/models/daily_record.dart';
import 'package:daily_counter/shared/models/weekly_summary.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('Formats integer amounts without decimals', () {
      expect(CurrencyUtils.formatCurrency(45.0, '₹'), '₹45');
      expect(CurrencyUtils.formatCurrency(0.0, '₹'), '₹0');
      expect(CurrencyUtils.formatCurrency(100.0, '\$'), '\$100');
    });

    test('Formats fractional amounts with 2 decimals', () {
      expect(CurrencyUtils.formatCurrency(45.5, '₹'), '₹45.50');
      expect(CurrencyUtils.formatCurrency(99.99, '₹'), '₹99.99');
    });

    test('formatNumber helper works', () {
      expect(CurrencyUtils.formatNumber(45.0), '45');
      expect(CurrencyUtils.formatNumber(45.25), '45.25');
    });
  });

  group('AppDateUtils Tests', () {
    test('Parses and formats date string correctly', () {
      const dateStr = '2026-11-02'; // A Monday
      expect(AppDateUtils.getDayOfWeekFull(dateStr), 'Monday');
      expect(AppDateUtils.getDayOfWeekAbbr(dateStr), 'MON');
      expect(AppDateUtils.formatShortDate(dateStr), '2 Nov');
      expect(AppDateUtils.formatDisplayDate(dateStr), 'Monday, 2 November');
    });

    test('Calculates Monday-start week correctly', () {
      // 2026-11-04 is Wednesday
      final wednesday = DateTime(2026, 11, 4);
      final weekDates = AppDateUtils.getWeekDates(wednesday, 'monday');

      expect(weekDates.length, 7);
      expect(weekDates.first, '2026-11-02'); // Monday
      expect(weekDates.last, '2026-11-08');  // Sunday
    });

    test('Calculates Sunday-start week correctly', () {
      // 2026-11-04 is Wednesday
      final wednesday = DateTime(2026, 11, 4);
      final weekDates = AppDateUtils.getWeekDates(wednesday, 'sunday');

      expect(weekDates.length, 7);
      expect(weekDates.first, '2026-11-01'); // Sunday
      expect(weekDates.last, '2026-11-07');  // Saturday
    });

    test('Detects future weeks properly', () {
      final now = DateTime(2026, 11, 2);
      final pastWeek = DateTime(2026, 10, 26);
      final futureWeek = DateTime(2026, 11, 9);

      expect(AppDateUtils.isFutureWeek(pastWeek, 'monday', now), false);
      expect(AppDateUtils.isFutureWeek(now, 'monday', now), false);
      expect(AppDateUtils.isFutureWeek(futureWeek, 'monday', now), true);
    });

    test('Week range formatting works across months', () {
      final weekAcrossMonths = [
        '2026-10-26',
        '2026-10-27',
        '2026-10-28',
        '2026-10-29',
        '2026-10-30',
        '2026-10-31',
        '2026-11-01'
      ];
      final range = AppDateUtils.formatWeekRange(weekAcrossMonths);
      expect(range, contains('26 Oct'));
      expect(range, contains('1 Nov 2026'));
    });
  });

  group('DailyRecord & WeeklySummary Calculation Tests', () {
    test('Amount calculated correctly without override', () {
      final record = DailyRecord(
        date: '2026-11-02',
        count: 2,
        updatedAt: '2026-11-02T10:00:00',
      );
      expect(record.calculateAmount(45.0), 90.0);
    });

    test('Amount override takes precedence over count * unit', () {
      final record = DailyRecord(
        date: '2026-11-02',
        count: 1,
        amountOverride: 60.0,
        updatedAt: '2026-11-02T10:00:00',
      );
      expect(record.calculateAmount(45.0), 60.0);
    });

    test('WeeklySummary aggregates correctly matching prompt example', () {
      // Prompt example:
      // Mon: 1 (45), Tue: 2 (90), Wed: 1 (45), Thu: 0 (0), Fri: 2 (90), Sat: 1 (45), Sun: 2 (90)
      // Total count: 9, Total amount: ₹405
      final weekDates = [
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
        '2026-11-07',
        '2026-11-08',
      ];

      final counts = [1, 2, 1, 0, 2, 1, 2];
      final records = <String, DailyRecord>{};

      for (int i = 0; i < 7; i++) {
        records[weekDates[i]] = DailyRecord(
          date: weekDates[i],
          count: counts[i],
          updatedAt: '2026-11-02T00:00:00',
        );
      }

      final summary = WeeklySummary.calculate(
        weekDates: weekDates,
        records: records,
        unitAmount: 45.0,
        dailyLimit: 2,
      );

      expect(summary.totalCount, 9);
      expect(summary.totalAmount, 405.0);
      expect(summary.completedDays, 3); // Tue (2), Fri (2), Sun (2)
      expect(summary.averageDailyCount, closeTo(9 / 7, 0.01));
    });
  });
}
