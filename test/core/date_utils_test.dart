import 'package:flutter_test/flutter_test.dart';
import 'package:leavewise/core/utils/date_utils.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  group('leap years', () {
    test('follows the Gregorian rules', () {
      expect(isLeapYear(2024), isTrue);
      expect(isLeapYear(2028), isTrue);
      expect(isLeapYear(2000), isTrue);
      expect(isLeapYear(1900), isFalse);
      expect(isLeapYear(2100), isFalse);
      expect(isLeapYear(2027), isFalse);
    });

    test('daysInMonth handles February and every other month', () {
      expect(daysInMonth(2028, 2), 29);
      expect(daysInMonth(2027, 2), 28);
      expect(daysInMonth(2100, 2), 28);
      expect(daysInMonth(2027, 1), 31);
      expect(daysInMonth(2027, 4), 30);
      expect(daysInMonth(2027, 12), 31);
      expect(() => daysInMonth(2027, 13), throwsRangeError);
    });

    test('makeDate rejects dates that do not exist', () {
      expect(makeDate(2028, 2, 29), d(2028, 2, 29));
      expect(() => makeDate(2027, 2, 29), throwsArgumentError);
      expect(() => makeDate(2027, 4, 31), throwsArgumentError);
      expect(() => makeDate(2027, 0, 1), throwsArgumentError);
    });
  });

  group('day arithmetic', () {
    test('addDays crosses month, year and leap-day boundaries', () {
      expect(addDays(d(2028, 2, 28), 1), d(2028, 2, 29));
      expect(addDays(d(2028, 2, 29), 1), d(2028, 3, 1));
      expect(addDays(d(2027, 2, 28), 1), d(2027, 3, 1));
      expect(addDays(d(2026, 12, 31), 1), d(2027, 1, 1));
      expect(addDays(d(2027, 1, 1), -1), d(2026, 12, 31));
      expect(addDays(d(2027, 3, 1), -1), d(2027, 2, 28));
    });

    test('daysBetween is exact across boundaries', () {
      expect(daysBetween(d(2028, 2, 28), d(2028, 3, 1)), 2);
      expect(daysBetween(d(2027, 2, 28), d(2027, 3, 1)), 1);
      expect(daysBetween(d(2026, 12, 25), d(2027, 1, 3)), 9);
      expect(daysBetween(d(2027, 1, 1), d(2027, 1, 1)), 0);
      expect(daysBetween(d(2027, 1, 5), d(2027, 1, 1)), -4);
      expect(daysBetween(d(2027, 1, 1), d(2028, 1, 1)), 365);
      expect(daysBetween(d(2028, 1, 1), d(2029, 1, 1)), 366);
    });

    test('is not affected by time of day or local time', () {
      final late = DateTime(2027, 3, 28, 23, 59);
      final early = DateTime(2027, 3, 29, 0, 1);
      expect(daysBetween(late, early), 1);
      expect(dateOnly(late), d(2027, 3, 28));
    });

    test('eachDay is inclusive and handles empty ranges', () {
      expect(eachDay(d(2028, 1, 1), d(2028, 12, 31)).length, 366);
      expect(eachDay(d(2027, 1, 1), d(2027, 12, 31)).length, 365);
      expect(eachDay(d(2027, 1, 1), d(2027, 1, 1)).length, 1);
      expect(eachDay(d(2027, 1, 2), d(2027, 1, 1)), isEmpty);
    });

    test('weekday of 1 January 2027 is Friday', () {
      expect(d(2027, 1, 1).weekday, DateTime.friday);
      expect(d(2027, 1, 26).weekday, DateTime.tuesday);
    });
  });

  group('date keys', () {
    test('round trip', () {
      expect(formatDateKey(d(2027, 1, 5)), '2027-01-05');
      expect(parseDateKey('2027-01-05'), d(2027, 1, 5));
      expect(parseDateKey('2028-02-29'), d(2028, 2, 29));
    });

    test('impossible or malformed dates are rejected', () {
      expect(() => parseDateKey('2027-02-30'), throwsFormatException);
      expect(() => parseDateKey('2027-02-29'), throwsFormatException);
      expect(() => parseDateKey('2027-13-01'), throwsFormatException);
      expect(() => parseDateKey('2027-1-5'), throwsFormatException);
      expect(() => parseDateKey('not a date'), throwsFormatException);
    });
  });

  group('addMonths', () {
    test('clamps the day to the target month', () {
      expect(addMonths(d(2027, 1, 31), 1), d(2027, 2, 28));
      expect(addMonths(d(2028, 1, 31), 1), d(2028, 2, 29));
      expect(addMonths(d(2027, 3, 31), -1), d(2027, 2, 28));
    });

    test('crosses year boundaries in both directions', () {
      expect(addMonths(d(2026, 11, 15), 3), d(2027, 2, 15));
      expect(addMonths(d(2027, 1, 15), -2), d(2026, 11, 15));
      expect(addMonths(d(2026, 11, 12), 12), d(2027, 11, 12));
      expect(addMonths(d(2026, 11, 12), 0), d(2026, 11, 12));
    });
  });
}
