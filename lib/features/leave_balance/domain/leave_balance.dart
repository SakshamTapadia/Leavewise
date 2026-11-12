import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/calendar/domain/work_schedule.dart';

enum LeaveStatus { suggested, planned, applied, approved, rejected, cancelled }

/// A leave category such as casual, earned or sick, or a user-defined one.
class LeaveType {
  const LeaveType({
    required this.id,
    required this.name,
    required this.allocated,
    this.alreadyConsumed = 0,
  });

  final String id;
  final String name;

  /// Days granted for the year.
  final double allocated;

  /// Days already used before the user started tracking in the app.
  final double alreadyConsumed;
}

class LeaveEntry {
  const LeaveEntry({
    required this.id,
    required this.typeId,
    required this.start,
    required this.end,
    required this.days,
    required this.status,
    this.note = '',
    this.planId,
  });

  final String id;
  final String typeId;
  final DateTime start;
  final DateTime end;

  /// Chargeable leave days, see [chargeableDays]. Half days are allowed.
  final double days;
  final LeaveStatus status;
  final String note;

  /// The saved plan this entry was created from, if any.
  final String? planId;

  LeaveEntry copyWith({
    String? id,
    String? typeId,
    DateTime? start,
    DateTime? end,
    double? days,
    LeaveStatus? status,
    String? note,
  }) {
    return LeaveEntry(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      start: start ?? this.start,
      end: end ?? this.end,
      days: days ?? this.days,
      status: status ?? this.status,
      note: note ?? this.note,
      planId: planId,
    );
  }
}

/// Statuses that mean the user really intends to be away on those days.
const Set<LeaveStatus> activeLeaveStatuses = {
  LeaveStatus.planned,
  LeaveStatus.applied,
  LeaveStatus.approved,
};

/// Which statuses count against a balance.
///
/// Saving a suggestion never deducts anything: [LeaveStatus.suggested],
/// [LeaveStatus.rejected] and [LeaveStatus.cancelled] are in neither set.
class DeductionRules {
  const DeductionRules({
    this.usedStatuses = const {LeaveStatus.approved},
    this.plannedStatuses = const {LeaveStatus.planned, LeaveStatus.applied},
  });

  final Set<LeaveStatus> usedStatuses;
  final Set<LeaveStatus> plannedStatuses;
}

class LeaveBalanceSummary {
  const LeaveBalanceSummary({
    required this.typeId,
    required this.allocated,
    required this.used,
    required this.planned,
  });

  final String typeId;
  final double allocated;
  final double used;
  final double planned;

  /// Allocated minus used minus planned.
  double get remaining => allocated - used - planned;

  /// Allocated minus used only, ignoring plans that may still change.
  double get availableIfPlansFail => allocated - used;
}

/// Computes one summary per leave type. Throws [ArgumentError] if an entry
/// refers to a type that does not exist.
List<LeaveBalanceSummary> computeBalances({
  required Iterable<LeaveType> types,
  required Iterable<LeaveEntry> entries,
  DeductionRules rules = const DeductionRules(),
}) {
  final used = <String, double>{};
  final planned = <String, double>{};
  for (final type in types) {
    used[type.id] = type.alreadyConsumed;
    planned[type.id] = 0;
  }
  for (final entry in entries) {
    if (!used.containsKey(entry.typeId)) {
      throw ArgumentError.value(
        entry.typeId,
        'typeId',
        'Unknown leave type on entry ${entry.id}',
      );
    }
    if (rules.usedStatuses.contains(entry.status)) {
      used[entry.typeId] = used[entry.typeId]! + entry.days;
    } else if (rules.plannedStatuses.contains(entry.status)) {
      planned[entry.typeId] = planned[entry.typeId]! + entry.days;
    }
  }
  return [
    for (final type in types)
      LeaveBalanceSummary(
        typeId: type.id,
        allocated: type.allocated,
        used: used[type.id]!,
        planned: planned[type.id]!,
      ),
  ];
}

/// Working days in [start]..[end] that are not holidays: the days a leave
/// application would actually deduct.
double chargeableDays({
  required DateTime start,
  required DateTime end,
  required WorkSchedule schedule,
  Set<DateTime> holidayDates = const {},
}) {
  var count = 0;
  for (final day in eachDay(start, end)) {
    if (schedule.isWorkingDay(day) && !holidayDates.contains(day)) count++;
  }
  return count.toDouble();
}
