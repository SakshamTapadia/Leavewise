import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';

/// How a holiday's date is derived for any year.
enum HolidayRuleKind {
  /// Same Gregorian month and day every year (for example 26 January).
  fixedDate,

  /// A fixed number of days from Western Easter Sunday (Good Friday is -2).
  easterOffset,

  /// A day of the Islamic calendar, estimated with the tabular calendar.
  /// Real dates depend on moon sighting and can differ by a day or two, so
  /// these are always generated as tentative.
  islamic,
}

/// A rule that can generate a holiday for any year.
///
/// Holidays that depend on a lunisolar panchang or on a government
/// announcement (Holi, Diwali, Dussehra and similar) have no rule. They come
/// from per-year dataset records instead, so nothing is invented.
class HolidayRule {
  const HolidayRule({
    required this.id,
    required this.name,
    required this.countryCode,
    this.regionCode,
    required this.category,
    required this.kind,
    this.month = 0,
    this.day = 0,
    this.offsetDays = 0,
    this.isOptional = false,
    this.description = '',
  });

  final String id;
  final String name;
  final String countryCode;
  final String? regionCode;
  final HolidayCategory category;
  final HolidayRuleKind kind;

  /// Gregorian month for [HolidayRuleKind.fixedDate], Hijri month for
  /// [HolidayRuleKind.islamic].
  final int month;

  /// Gregorian day for fixed dates, Hijri day for Islamic rules.
  final int day;

  /// Days from Easter Sunday for [HolidayRuleKind.easterOffset].
  final int offsetDays;
  final bool isOptional;
  final String description;
}

/// Western (Gregorian) Easter Sunday, using the Meeus/Jones/Butcher method.
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final t = h + l - 7 * m + 114;
  return DateTime.utc(year, t ~/ 31, t % 31 + 1);
}

/// Gregorian date of a Hijri date in the tabular (arithmetic) Islamic
/// calendar. An estimate: observed dates can differ by one or two days.
DateTime islamicToGregorian(int hijriYear, int hijriMonth, int hijriDay) {
  final daysSince2000 = hijriDay +
      (59 * (hijriMonth - 1) + 1) ~/ 2 +
      (hijriYear - 1) * 354 +
      (3 + 11 * hijriYear) ~/ 30 -
      503106;
  return addDays(DateTime.utc(2000, 1, 1), daysSince2000);
}

/// Holidays produced by [rule] in Gregorian [year]. Usually one, but an
/// Islamic date can occur twice in a Gregorian year, and a 29 February rule
/// produces nothing in common years.
List<Holiday> generateHolidays(HolidayRule rule, int year) {
  Holiday build(
    DateTime date,
    VerificationStatus verification,
    HolidayRecurrence recurrence,
    String source,
  ) {
    return Holiday(
      id: '${rule.id}-${formatDateKey(date)}',
      name: rule.name,
      date: date,
      countryCode: rule.countryCode,
      regionCode: rule.regionCode,
      category: rule.category,
      description: rule.description,
      source: source,
      verification: verification,
      isOptional: rule.isOptional,
      recurrence: recurrence,
      ruleId: rule.id,
    );
  }

  switch (rule.kind) {
    case HolidayRuleKind.fixedDate:
      if (rule.month < 1 ||
          rule.month > 12 ||
          rule.day < 1 ||
          rule.day > daysInMonth(year, rule.month)) {
        return [];
      }
      return [
        build(
          DateTime.utc(year, rule.month, rule.day),
          VerificationStatus.verified,
          HolidayRecurrence.yearlyFixedDate,
          'Fixed-date rule',
        ),
      ];
    case HolidayRuleKind.easterOffset:
      return [
        build(
          addDays(easterSunday(year), rule.offsetDays),
          VerificationStatus.verified,
          HolidayRecurrence.ruleBased,
          'Computed from Western Easter',
        ),
      ];
    case HolidayRuleKind.islamic:
      final estimate = ((year - 622) * 33 / 32).floor();
      final results = <Holiday>[];
      for (var hijriYear = estimate - 1; hijriYear <= estimate + 2; hijriYear++) {
        final date = islamicToGregorian(hijriYear, rule.month, rule.day);
        if (date.year == year) {
          results.add(
            build(
              date,
              VerificationStatus.tentative,
              HolidayRecurrence.lunar,
              'Estimated from the tabular Islamic calendar; confirm against '
                  'the official announcement',
            ),
          );
        }
      }
      return results;
  }
}

/// All holidays for one [year], combining dataset records with rules.
///
/// A dataset record that carries a ruleId replaces what that rule would have
/// generated for the year, so official dates always beat estimates. The
/// result is sorted by date, then name.
List<Holiday> resolveHolidaysForYear({
  required int year,
  required String countryCode,
  String? regionCode,
  Iterable<HolidayRule> rules = const [],
  Iterable<Holiday> records = const [],
}) {
  final country = countryCode.toUpperCase();
  final region = regionCode?.toUpperCase();
  final yearRecords = records.where((h) => h.date.year == year).toList();
  final overridden = {
    for (final h in yearRecords)
      if (h.ruleId != null) h.ruleId,
  };
  final generated = <Holiday>[
    for (final rule in rules)
      if (rule.countryCode.toUpperCase() == country &&
          (rule.regionCode == null || rule.regionCode!.toUpperCase() == region) &&
          !overridden.contains(rule.id))
        ...generateHolidays(rule, year),
  ];
  return [...yearRecords, ...generated]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.name.compareTo(b.name);
    });
}

/// [resolveHolidaysForYear] over every year from [firstYear] to [lastYear].
List<Holiday> resolveHolidaysForRange({
  required int firstYear,
  required int lastYear,
  required String countryCode,
  String? regionCode,
  Iterable<HolidayRule> rules = const [],
  Iterable<Holiday> records = const [],
}) {
  return [
    for (var year = firstYear; year <= lastYear; year++)
      ...resolveHolidaysForYear(
        year: year,
        countryCode: countryCode,
        regionCode: regionCode,
        rules: rules,
        records: records,
      ),
  ];
}
