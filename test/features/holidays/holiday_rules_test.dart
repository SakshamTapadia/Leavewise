import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/holidays/domain/holiday_json.dart';
import 'package:leavewise/features/holidays/domain/holiday_rules.dart';
import 'package:leavewise/features/holidays/domain/india_rules.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Holiday named(List<Holiday> all, String name) =>
    all.singleWhere((h) => h.name == name);

void main() {
  group('Easter', () {
    test('matches known Easter Sundays', () {
      expect(easterSunday(1900), d(1900, 4, 15));
      expect(easterSunday(2000), d(2000, 4, 23));
      expect(easterSunday(2024), d(2024, 3, 31));
      expect(easterSunday(2025), d(2025, 4, 20));
      expect(easterSunday(2026), d(2026, 4, 5));
      expect(easterSunday(2027), d(2027, 3, 28));
      expect(easterSunday(2028), d(2028, 4, 16));
    });

    test('Good Friday is two days before Easter', () {
      final good = generateHolidays(
        indiaNationalRules.singleWhere((r) => r.id == 'in-good-friday'),
        2027,
      );
      expect(good.single.date, d(2027, 3, 26));
      expect(good.single.verification, VerificationStatus.verified);
    });
  });

  group('Islamic tabular estimate', () {
    test('lands within one day of the official 2027 dates', () {
      void check(int hijriYear, int month, int day, DateTime official) {
        final estimate = islamicToGregorian(hijriYear, month, day);
        expect(
          daysBetween(estimate, official).abs(),
          lessThanOrEqualTo(1),
          reason: 'estimate $estimate vs official $official',
        );
      }

      check(1448, 10, 1, d(2027, 3, 10)); // Id-ul-Fitr
      check(1448, 12, 10, d(2027, 5, 17)); // Id-ul-Zuha
      check(1449, 1, 10, d(2027, 6, 16)); // Muharram
      check(1449, 3, 12, d(2027, 8, 15)); // Milad-un-Nabi
    });

    test('is always generated as tentative', () {
      for (final rule in indiaNationalRules
          .where((r) => r.kind == HolidayRuleKind.islamic)) {
        final list = generateHolidays(rule, 2030);
        expect(list, isNotEmpty);
        for (final h in list) {
          expect(h.verification, VerificationStatus.tentative);
          expect(h.recurrence, HolidayRecurrence.lunar);
          expect(h.date.year, 2030);
        }
      }
    });
  });

  group('fixed dates', () {
    test('Republic Day exists in every year', () {
      const rule = HolidayRule(
        id: 'r',
        name: 'Republic Day',
        countryCode: 'IN',
        category: HolidayCategory.national,
        kind: HolidayRuleKind.fixedDate,
        month: 1,
        day: 26,
      );
      for (final year in [1999, 2024, 2027, 2100]) {
        expect(generateHolidays(rule, year).single.date, d(year, 1, 26));
      }
    });

    test('a 29 February rule only fires in leap years', () {
      const rule = HolidayRule(
        id: 'leap',
        name: 'Leap Day',
        countryCode: 'IN',
        category: HolidayCategory.custom,
        kind: HolidayRuleKind.fixedDate,
        month: 2,
        day: 29,
      );
      expect(generateHolidays(rule, 2028).single.date, d(2028, 2, 29));
      expect(generateHolidays(rule, 2027), isEmpty);
      expect(generateHolidays(rule, 2100), isEmpty);
    });
  });

  group('resolveHolidaysForYear', () {
    test('rules alone cover a future year with no dataset', () {
      final all = resolveHolidaysForYear(
        year: 2031,
        countryCode: 'IN',
        rules: indiaNationalRules,
      );
      expect(named(all, 'Republic Day').date, d(2031, 1, 26));
      expect(named(all, 'Independence Day').date, d(2031, 8, 15));
      expect(named(all, 'Good Friday').date, d(2031, 4, 11));
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].date.isAfter(all[i].date), isFalse);
      }
    });

    test('an official record replaces the estimate for its year', () {
      final dataset = importHolidaysJson(
        File('assets/data/holidays/IN-2027.json').readAsStringSync(),
      );
      final all = resolveHolidaysForYear(
        year: 2027,
        countryCode: 'IN',
        rules: indiaNationalRules,
        records: dataset,
      );
      final muharram = all.where((h) => h.name == 'Muharram').toList();
      expect(muharram, hasLength(1));
      expect(muharram.single.date, d(2027, 6, 16));
      // Every rule-backed holiday appears exactly once.
      expect(all.where((h) => h.name == 'Republic Day'), hasLength(1));
      expect(all.where((h) => h.name == 'Good Friday'), hasLength(1));
    });

    test('dataset records for other years do not leak in', () {
      final dataset = importHolidaysJson(
        File('assets/data/holidays/IN-2027.json').readAsStringSync(),
      );
      final all = resolveHolidaysForYear(
        year: 2028,
        countryCode: 'IN',
        rules: indiaNationalRules,
        records: dataset,
      );
      expect(all.every((h) => h.date.year == 2028), isTrue);
      expect(all.any((h) => h.name == 'Diwali (Deepavali)'), isFalse);
    });

    test('other countries and regions are excluded', () {
      final all = resolveHolidaysForYear(
        year: 2027,
        countryCode: 'US',
        rules: indiaNationalRules,
      );
      expect(all, isEmpty);
    });

    test('range resolves every year in order', () {
      final all = resolveHolidaysForRange(
        firstYear: 2027,
        lastYear: 2029,
        countryCode: 'IN',
        rules: indiaNationalRules,
      );
      expect(all.map((h) => h.date.year).toSet(), {2027, 2028, 2029});
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].date.isAfter(all[i].date), isFalse);
      }
    });
  });

  group('India 2027 dataset file', () {
    final dataset = importHolidaysJson(
      File('assets/data/holidays/IN-2027.json').readAsStringSync(),
    );

    test('has the 17 gazetted holidays, all in 2027 for India', () {
      expect(dataset, hasLength(17));
      expect(dataset.every((h) => h.date.year == 2027), isTrue);
      expect(dataset.every((h) => h.countryCode == 'IN'), isTrue);
      expect(dataset.every((h) => h.source.isNotEmpty), isTrue);
    });

    test('moon-sighting holidays are tentative', () {
      for (final name in [
        'Id-ul-Fitr',
        'Id-ul-Zuha (Bakrid)',
        'Muharram',
        "Milad-un-Nabi (Prophet Mohammad's Birthday)",
      ]) {
        expect(named(dataset, name).verification, VerificationStatus.tentative);
      }
    });

    test('two holidays can share a date', () {
      final aug15 = dataset.where((h) => h.date == d(2027, 8, 15)).toList();
      expect(aug15, hasLength(2));
    });

    test('fixed dates agree with the rule engine', () {
      for (final rule in indiaNationalRules.where(
        (r) => r.kind == HolidayRuleKind.fixedDate ||
            r.kind == HolidayRuleKind.easterOffset,
      )) {
        final record = dataset.singleWhere((h) => h.ruleId == rule.id);
        expect(generateHolidays(rule, 2027).single.date, record.date);
      }
    });

    test('weekdays match the published list', () {
      expect(named(dataset, 'Republic Day').date.weekday, DateTime.tuesday);
      expect(named(dataset, 'Holi').date.weekday, DateTime.tuesday);
      expect(named(dataset, 'Diwali (Deepavali)').date.weekday, DateTime.friday);
      expect(named(dataset, 'Christmas Day').date.weekday, DateTime.saturday);
    });
  });
}
