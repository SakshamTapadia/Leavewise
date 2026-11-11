import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/calendar/domain/work_schedule.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';

/// What a single day inside a break is.
///
/// Every day is exactly one kind, with this precedence: a holiday record wins,
/// then a non-working weekday ([weekend]), then an already-planned leave
/// ([existingLeave]). A day that is none of those is a [leave] this
/// recommendation asks the user to take.
enum DayKind { holiday, weekend, leave, existingLeave }

class BreakDay {
  const BreakDay({
    required this.date,
    required this.kind,
    this.holidayNames = const [],
  });

  final DateTime date;
  final DayKind kind;

  /// Names of every holiday record on this date (several may overlap).
  final List<String> holidayNames;
}

/// A contiguous run of days off, with its full day-by-day breakdown.
class LeaveRecommendation {
  LeaveRecommendation({required List<BreakDay> days})
      : assert(days.isNotEmpty),
        days = List.unmodifiable(days),
        leavesRequired = days.where((d) => d.kind == DayKind.leave).length,
        holidayCount = days.where((d) => d.kind == DayKind.holiday).length,
        weekendCount = days.where((d) => d.kind == DayKind.weekend).length,
        existingLeaveCount =
            days.where((d) => d.kind == DayKind.existingLeave).length;

  final List<BreakDay> days;
  final int leavesRequired;
  final int holidayCount;
  final int weekendCount;
  final int existingLeaveCount;

  DateTime get start => days.first.date;
  DateTime get end => days.last.date;

  /// Consecutive days off, equal to [days].length.
  int get totalDays => days.length;

  /// Days off gained per leave day spent. Infinity when no leave is needed.
  double get efficiency =>
      leavesRequired == 0 ? double.infinity : totalDays / leavesRequired;

  /// The dates the user would need to apply leave for.
  List<DateTime> get leaveDates => [
        for (final d in days)
          if (d.kind == DayKind.leave) d.date,
      ];

  bool overlaps(LeaveRecommendation other) =>
      !start.isAfter(other.end) && !other.start.isAfter(end);
}

/// A run of days off that needs no leave at all and contains a holiday.
class FreeStretch {
  const FreeStretch({
    required this.start,
    required this.end,
    required this.holidayNames,
  });

  final DateTime start;
  final DateTime end;
  final List<String> holidayNames;

  int get length => daysBetween(start, end) + 1;
}

class OptimizerInput {
  OptimizerInput({
    required DateTime horizonStart,
    required DateTime horizonEnd,
    required this.schedule,
    required Iterable<Holiday> holidays,
    Iterable<DateTime> existingLeaveDays = const [],
    required this.leaveBudget,
    this.availableBalance,
    this.minimumDaysOff = 3,
  })  : horizonStart = dateOnly(horizonStart),
        horizonEnd = dateOnly(horizonEnd),
        holidays = List.unmodifiable(holidays),
        existingLeaveDays =
            Set.unmodifiable(existingLeaveDays.map<DateTime>(dateOnly));

  /// Recommendations never extend outside [horizonStart]..[horizonEnd].
  final DateTime horizonStart;
  final DateTime horizonEnd;
  final WorkSchedule schedule;

  /// Holidays already filtered by country, region and user preferences.
  final List<Holiday> holidays;

  /// Days the user has already planned or booked as leave.
  final Set<DateTime> existingLeaveDays;

  /// The most leave days a single recommendation may use.
  final int leaveBudget;

  /// The user's remaining balance. Null means unlimited.
  final int? availableBalance;

  /// Breaks shorter than this are not worth recommending.
  final int minimumDaysOff;
}

enum RecommendationSort { maxDaysOff, minLeaves, bestEfficiency, earliest }

enum AnnualObjective {
  /// Maximise the sum of days off across the chosen breaks.
  totalDaysOff,

  /// Favour fewer, longer breaks (scores each break by its length squared).
  longestBreaks,
}

class AnnualPlan {
  AnnualPlan(List<LeaveRecommendation> breaks)
      : breaks = List.unmodifiable(breaks);

  final List<LeaveRecommendation> breaks;

  int get leavesUsed => breaks.fold(0, (sum, b) => sum + b.leavesRequired);
  int get totalDaysOff => breaks.fold(0, (sum, b) => sum + b.totalDays);
}
