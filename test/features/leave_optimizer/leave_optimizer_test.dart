import 'package:flutter_test/flutter_test.dart';
import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/calendar/domain/work_schedule.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/holidays/domain/holiday_filter.dart';
import 'package:leavewise/features/leave_optimizer/domain/leave_optimizer.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Holiday hol(
  String id,
  DateTime date, {
  HolidayCategory category = HolidayCategory.national,
  bool optional = false,
  String? name,
}) {
  return Holiday(
    id: id,
    name: name ?? id,
    date: date,
    countryCode: 'IN',
    category: category,
    isOptional: optional,
  );
}

OptimizerInput input({
  required DateTime start,
  required DateTime end,
  required List<Holiday> holidays,
  int budget = 5,
  int? balance,
  WorkSchedule schedule = WorkSchedule.mondayToFriday,
  Set<DateTime> existing = const {},
  int minimumDaysOff = 3,
}) {
  return OptimizerInput(
    horizonStart: start,
    horizonEnd: end,
    schedule: schedule,
    holidays: holidays,
    existingLeaveDays: existing,
    leaveBudget: budget,
    availableBalance: balance,
    minimumDaysOff: minimumDaysOff,
  );
}

/// Candidates that start and end on the given dates, using [leaves] leaves.
List<LeaveRecommendation> find(
  List<LeaveRecommendation> all,
  DateTime start,
  DateTime end,
  int leaves,
) {
  return all
      .where((r) =>
          r.start == start && r.end == end && r.leavesRequired == leaves)
      .toList();
}

void main() {
  const optimizer = LeaveOptimizer();

  group('known calendar scenarios (2027)', () {
    // 1 Jan 2027 is a Friday, so 26 Jan 2027 is a Tuesday.
    final republicDay = hol('republic', d(2027, 1, 26), name: 'Republic Day');

    test('one leave around a Tuesday holiday gives four days off', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: [republicDay],
          budget: 4,
        ),
      );
      final match = find(all, d(2027, 1, 23), d(2027, 1, 26), 1);
      expect(match, hasLength(1));
      final r = match.single;
      expect(r.totalDays, 4);
      expect(r.holidayCount, 1);
      expect(r.weekendCount, 2);
      expect(r.leaveDates, [d(2027, 1, 25)]);
      expect(r.efficiency, 4.0);
      expect(r.days.map((x) => x.kind), [
        DayKind.weekend,
        DayKind.weekend,
        DayKind.leave,
        DayKind.holiday,
      ]);
      expect(r.days.last.holidayNames, ['Republic Day']);
    });

    test('four leaves reach nine days off', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: [republicDay],
          budget: 4,
        ),
      );
      final match = find(all, d(2027, 1, 23), d(2027, 1, 31), 4);
      expect(match, hasLength(1));
      expect(match.single.totalDays, 9);
      expect(match.single.holidayCount, 1);
      expect(match.single.weekendCount, 4);
    });

    test('a Monday to Saturday schedule changes the result', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: [republicDay],
          budget: 1,
          schedule: WorkSchedule.mondayToSaturday,
        ),
      );
      // Only Sunday 24, Monday 25 (leave), Tuesday 26 (holiday).
      expect(all, hasLength(1));
      expect(all.single.start, d(2027, 1, 24));
      expect(all.single.end, d(2027, 1, 26));
      expect(all.single.totalDays, 3);
    });

    test('consecutive holidays chain into one longer break', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: [republicDay, hol('next', d(2027, 1, 27))],
          budget: 1,
        ),
      );
      final match = find(all, d(2027, 1, 23), d(2027, 1, 27), 1);
      expect(match, hasLength(1));
      expect(match.single.totalDays, 5);
      expect(match.single.holidayCount, 2);
    });

    test('overlapping holiday records on one date count once', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: [
            republicDay,
            hol(
              'second',
              d(2027, 1, 26),
              category: HolidayCategory.religious,
              name: 'Another observance',
            ),
          ],
          budget: 1,
        ),
      );
      final r = find(all, d(2027, 1, 23), d(2027, 1, 26), 1).single;
      expect(r.totalDays, 4);
      expect(r.holidayCount, 1);
      expect(
        r.days.last.holidayNames,
        ['Republic Day', 'Another observance'],
      );
    });

    test('a break can cross a month boundary', () {
      // 1 Mar 2027 is a Monday.
      final all = optimizer.candidates(
        input(
          start: d(2027, 2, 1),
          end: d(2027, 3, 31),
          holidays: [hol('mar1', d(2027, 3, 1))],
          budget: 2,
        ),
      );
      expect(find(all, d(2027, 2, 27), d(2027, 3, 2), 1), hasLength(1));
      expect(find(all, d(2027, 2, 26), d(2027, 3, 2), 2), hasLength(1));
      expect(find(all, d(2027, 2, 26), d(2027, 3, 2), 2).single.totalDays, 5);
    });

    test('a break can cross a year boundary', () {
      // 25 Dec 2026 and 1 Jan 2027 are both Fridays.
      final all = optimizer.candidates(
        input(
          start: d(2026, 12, 20),
          end: d(2027, 1, 10),
          holidays: [hol('xmas', d(2026, 12, 25)), hol('ny', d(2027, 1, 1))],
          budget: 4,
        ),
      );
      final match = find(all, d(2026, 12, 25), d(2027, 1, 3), 4);
      expect(match, hasLength(1));
      final r = match.single;
      expect(r.totalDays, 10);
      expect(r.holidayCount, 2);
      expect(r.weekendCount, 4);
      expect(r.leaveDates, [
        d(2026, 12, 28),
        d(2026, 12, 29),
        d(2026, 12, 30),
        d(2026, 12, 31),
      ]);
      expect(r.efficiency, 2.5);
    });

    test('leap day: 29 Feb 2028 exists and extends a break', () {
      // 29 Feb 2028 is a Tuesday.
      final all = optimizer.candidates(
        input(
          start: d(2028, 2, 1),
          end: d(2028, 3, 31),
          holidays: [hol('leap', d(2028, 2, 29))],
          budget: 1,
        ),
      );
      final match = find(all, d(2028, 2, 26), d(2028, 2, 29), 1);
      expect(match, hasLength(1));
      expect(match.single.totalDays, 4);
    });

    test('the same date in a non-leap year does not exist', () {
      expect(() => makeDate(2027, 2, 29), throwsArgumentError);
    });

    test('a partial work week (Mon to Wed) gives long breaks', () {
      // Thu 7 Jan - Sun 17 Jan 2027, working Mon, Tue, Wed only.
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 4),
          end: d(2027, 1, 17),
          holidays: const [],
          budget: 3,
          schedule: const WorkSchedule({1, 2, 3}),
        ),
      );
      final match = find(all, d(2027, 1, 7), d(2027, 1, 17), 3);
      expect(match, hasLength(1));
      expect(match.single.totalDays, 11);
      expect(match.single.weekendCount, 8);
    });
  });

  group('leave balance, budget and existing leave', () {
    final holidays = [hol('republic', d(2027, 1, 26))];

    test('zero balance yields no recommendations', () {
      final result = optimizer.recommend(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 12, 31),
          holidays: holidays,
          balance: 0,
        ),
      );
      expect(result, isEmpty);
    });

    test('zero budget yields no recommendations', () {
      expect(
        optimizer.candidates(
          input(
            start: d(2027, 1, 1),
            end: d(2027, 12, 31),
            holidays: holidays,
            budget: 0,
          ),
        ),
        isEmpty,
      );
    });

    test('a small balance caps every recommendation', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 12, 31),
          holidays: holidays,
          budget: 7,
          balance: 2,
        ),
      );
      expect(all, isNotEmpty);
      expect(all.every((r) => r.leavesRequired <= 2), isTrue);
    });

    test('combined recommendations never exceed the balance', () {
      final many = [
        for (var m = 1; m <= 12; m++) hol('h$m', d(2027, m, 15)),
      ];
      final picks = optimizer.recommend(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 12, 31),
          holidays: many,
          budget: 5,
          balance: 6,
        ),
        sort: RecommendationSort.maxDaysOff,
      );
      final total = picks.fold<int>(0, (s, r) => s + r.leavesRequired);
      expect(total, lessThanOrEqualTo(6));
    });

    test('existing leave is free and is never recommended again', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: holidays,
          budget: 1,
          existing: {d(2027, 1, 25)},
        ),
      );
      final match = find(all, d(2027, 1, 23), d(2027, 1, 27), 1);
      expect(match, hasLength(1));
      expect(match.single.existingLeaveCount, 1);
      expect(match.single.totalDays, 5);
      for (final r in all) {
        expect(r.leaveDates, isNot(contains(d(2027, 1, 25))));
      }
    });

    test('an existing leave on a weekend is not double counted', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: holidays,
          budget: 1,
          existing: {d(2027, 1, 23)},
        ),
      );
      final r = find(all, d(2027, 1, 23), d(2027, 1, 26), 1).single;
      expect(r.existingLeaveCount, 0);
      expect(r.weekendCount, 2);
    });

    test('optional holidays only matter when enabled', () {
      final optionalHoliday = hol('opt', d(2027, 1, 26), optional: true);
      List<Holiday> filtered(bool include) => filterHolidays(
            [optionalHoliday],
            countryCode: 'IN',
            prefs: HolidayPreferences(includeOptional: include),
          );
      final without = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: filtered(false),
          budget: 1,
        ),
      );
      final withOptional = optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: filtered(true),
          budget: 1,
        ),
      );
      expect(find(without, d(2027, 1, 23), d(2027, 1, 26), 1), isEmpty);
      expect(find(withOptional, d(2027, 1, 23), d(2027, 1, 26), 1), hasLength(1));
    });

    test('holidays outside the horizon are ignored', () {
      final all = optimizer.candidates(
        input(
          start: d(2027, 2, 1),
          end: d(2027, 2, 28),
          holidays: holidays,
          budget: 3,
        ),
      );
      expect(all.every((r) => r.holidayCount == 0), isTrue);
    });

    test('an empty or reversed horizon returns nothing', () {
      expect(
        optimizer.candidates(
          input(start: d(2027, 2, 2), end: d(2027, 2, 1), holidays: holidays),
        ),
        isEmpty,
      );
    });
  });

  group('properties checked against an independent calendar oracle', () {
    final holidays = [
      for (final date in [
        d(2027, 1, 26),
        d(2027, 3, 10),
        d(2027, 3, 11),
        d(2027, 4, 14),
        d(2027, 5, 1),
        d(2027, 8, 15),
        d(2027, 9, 8),
        d(2027, 10, 2),
        d(2027, 11, 5),
        d(2027, 12, 24),
        d(2027, 12, 25),
      ])
        hol('h-${formatDateKey(date)}', date),
    ];
    final holidayDates = holidays.map((h) => h.date).toSet();
    final existing = {d(2027, 3, 3), d(2027, 6, 16)};
    const schedule = WorkSchedule.mondayToFriday;
    final start = d(2027, 1, 1);
    final end = d(2027, 12, 31);

    bool isFree(DateTime date) =>
        holidayDates.contains(date) ||
        !schedule.isWorkingDay(date) ||
        existing.contains(date);

    final all = optimizer.candidates(
      input(
        start: start,
        end: end,
        holidays: holidays,
        budget: 7,
        existing: existing,
      ),
    );

    test('produces candidates', () {
      expect(all, isNotEmpty);
    });

    test('every day in every break is genuinely off', () {
      for (final r in all) {
        expect(r.totalDays, r.days.length);
        expect(r.totalDays, daysBetween(r.start, r.end) + 1);
        for (var k = 0; k < r.days.length; k++) {
          final day = r.days[k];
          expect(day.date, addDays(r.start, k), reason: 'contiguous');
          switch (day.kind) {
            case DayKind.leave:
              expect(schedule.isWorkingDay(day.date), isTrue);
              expect(holidayDates.contains(day.date), isFalse);
              expect(existing.contains(day.date), isFalse);
            case DayKind.holiday:
              expect(holidayDates.contains(day.date), isTrue);
            case DayKind.weekend:
              expect(schedule.isWorkingDay(day.date), isFalse);
              expect(holidayDates.contains(day.date), isFalse);
            case DayKind.existingLeave:
              expect(existing.contains(day.date), isTrue);
              expect(schedule.isWorkingDay(day.date), isTrue);
              expect(holidayDates.contains(day.date), isFalse);
          }
        }
      }
    });

    test('leave counts, budget and totals are consistent', () {
      for (final r in all) {
        expect(r.leavesRequired, greaterThanOrEqualTo(1));
        expect(r.leavesRequired, lessThanOrEqualTo(7));
        expect(r.totalDays, greaterThan(r.leavesRequired));
        expect(
          r.totalDays,
          r.leavesRequired +
              r.holidayCount +
              r.weekendCount +
              r.existingLeaveCount,
        );
        expect(r.start.isBefore(start), isFalse);
        expect(r.end.isAfter(end), isFalse);
      }
    });

    test('no break can be extended without spending another leave', () {
      for (final r in all) {
        final before = addDays(r.start, -1);
        final after = addDays(r.end, 1);
        if (!before.isBefore(start)) {
          expect(isFree(before), isFalse, reason: 'before ${r.start}');
        }
        if (!after.isAfter(end)) {
          expect(isFree(after), isFalse, reason: 'after ${r.end}');
        }
      }
    });

    test('no duplicate windows', () {
      final keys = all
          .map((r) => '${formatDateKey(r.start)}|${formatDateKey(r.end)}')
          .toList();
      expect(keys.toSet().length, keys.length);
    });

    test('recommend() without overlap really has no overlaps', () {
      for (final sort in RecommendationSort.values) {
        final picks = optimizer.recommend(
          input(
            start: start,
            end: end,
            holidays: holidays,
            budget: 7,
            existing: existing,
          ),
          sort: sort,
        );
        for (var i = 0; i < picks.length; i++) {
          for (var j = i + 1; j < picks.length; j++) {
            expect(picks[i].overlaps(picks[j]), isFalse);
          }
        }
      }
    });

    test('each sort order is actually ordered', () {
      List<LeaveRecommendation> sorted(RecommendationSort sort) =>
          optimizer.recommend(
            input(
              start: start,
              end: end,
              holidays: holidays,
              budget: 7,
              existing: existing,
            ),
            sort: sort,
            allowOverlap: true,
          );

      final byDays = sorted(RecommendationSort.maxDaysOff);
      for (var i = 1; i < byDays.length; i++) {
        expect(byDays[i - 1].totalDays >= byDays[i].totalDays, isTrue);
      }
      final byLeaves = sorted(RecommendationSort.minLeaves);
      for (var i = 1; i < byLeaves.length; i++) {
        expect(
          byLeaves[i - 1].leavesRequired <= byLeaves[i].leavesRequired,
          isTrue,
        );
      }
      final byEfficiency = sorted(RecommendationSort.bestEfficiency);
      for (var i = 1; i < byEfficiency.length; i++) {
        expect(
          byEfficiency[i - 1].efficiency >= byEfficiency[i].efficiency,
          isTrue,
        );
      }
      final byDate = sorted(RecommendationSort.earliest);
      for (var i = 1; i < byDate.length; i++) {
        expect(byDate[i - 1].start.isAfter(byDate[i].start), isFalse);
      }
    });

    test('limit is respected', () {
      final picks = optimizer.recommend(
        input(start: start, end: end, holidays: holidays, budget: 7),
        limit: 3,
      );
      expect(picks.length, lessThanOrEqualTo(3));
    });

    test('a larger budget never loses the best break', () {
      int best(int budget) {
        final cands = optimizer.candidates(
          input(
            start: start,
            end: end,
            holidays: holidays,
            budget: budget,
            existing: existing,
          ),
        );
        return cands.fold<int>(0, (m, r) => r.totalDays > m ? r.totalDays : m);
      }

      expect(best(7), greaterThanOrEqualTo(best(5)));
      expect(best(5), greaterThanOrEqualTo(best(3)));
      expect(best(3), greaterThanOrEqualTo(best(1)));
    });
  });

  group('free stretches', () {
    test('finds a long weekend across a month boundary', () {
      final stretches = optimizer.freeStretches(
        input(
          start: d(2027, 2, 1),
          end: d(2027, 3, 31),
          holidays: [hol('mar1', d(2027, 3, 1), name: 'March holiday')],
        ),
      );
      expect(stretches, hasLength(1));
      expect(stretches.single.start, d(2027, 2, 27));
      expect(stretches.single.end, d(2027, 3, 1));
      expect(stretches.single.length, 3);
      expect(stretches.single.holidayNames, ['March holiday']);
    });

    test('a plain weekend or a lone midweek holiday is not a stretch', () {
      final stretches = optimizer.freeStretches(
        input(
          start: d(2027, 1, 4),
          end: d(2027, 1, 22),
          holidays: [hol('wed', d(2027, 1, 13))],
        ),
      );
      expect(stretches, isEmpty);
    });
  });

  group('annual plan', () {
    final holidays = [
      for (final date in [
        d(2027, 1, 26),
        d(2027, 3, 10),
        d(2027, 3, 11),
        d(2027, 4, 14),
        d(2027, 5, 1),
        d(2027, 8, 15),
        d(2027, 10, 2),
        d(2027, 12, 24),
        d(2027, 12, 25),
      ])
        hol('p-${formatDateKey(date)}', date),
    ];
    OptimizerInput base({int? balance}) => input(
          start: d(2027, 1, 1),
          end: d(2027, 12, 31),
          holidays: holidays,
          budget: 7,
          balance: balance,
        );

    test('respects the leave cap and never overlaps', () {
      for (final objective in AnnualObjective.values) {
        final plan = optimizer.planAnnual(
          base(),
          totalLeaves: 10,
          objective: objective,
        );
        expect(plan.leavesUsed, lessThanOrEqualTo(10));
        expect(plan.breaks, isNotEmpty);
        for (var i = 1; i < plan.breaks.length; i++) {
          expect(
            plan.breaks[i - 1].end.isBefore(plan.breaks[i].start),
            isTrue,
          );
        }
      }
    });

    test('is at least as good as any single break and the greedy picks', () {
      final cands = optimizer.candidates(base());
      final plan = optimizer.planAnnual(
        base(),
        totalLeaves: 7,
        objective: AnnualObjective.totalDaysOff,
      );
      final bestSingle = cands
          .where((c) => c.leavesRequired <= 7)
          .fold<int>(0, (m, c) => c.totalDays > m ? c.totalDays : m);
      expect(plan.totalDaysOff, greaterThanOrEqualTo(bestSingle));

      final greedy = optimizer.recommend(
        base(balance: 7),
        sort: RecommendationSort.maxDaysOff,
      );
      final greedyTotal = greedy.fold<int>(0, (s, r) => s + r.totalDays);
      expect(plan.totalDaysOff, greaterThanOrEqualTo(greedyTotal));
    });

    test('a zero cap or zero balance gives an empty plan', () {
      expect(optimizer.planAnnual(base(), totalLeaves: 0).breaks, isEmpty);
      expect(
        optimizer.planAnnual(base(balance: 0), totalLeaves: 10).breaks,
        isEmpty,
      );
    });

    test('the balance caps the plan below the requested total', () {
      final plan = optimizer.planAnnual(base(balance: 3), totalLeaves: 10);
      expect(plan.leavesUsed, lessThanOrEqualTo(3));
    });
  });

  test('an invalid work schedule is rejected', () {
    expect(
      () => optimizer.candidates(
        input(
          start: d(2027, 1, 1),
          end: d(2027, 1, 31),
          holidays: const [],
          schedule: const WorkSchedule({}),
        ),
      ),
      throwsArgumentError,
    );
  });
}
