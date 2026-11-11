import 'package:flutter_test/flutter_test.dart';
import 'package:leavewise/features/calendar/domain/work_schedule.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

LeaveEntry entry(String id, LeaveStatus status, double days,
    {String typeId = 'casual'}) {
  return LeaveEntry(
    id: id,
    typeId: typeId,
    start: d(2027, 3, 1),
    end: d(2027, 3, 1),
    days: days,
    status: status,
  );
}

void main() {
  const casual = LeaveType(id: 'casual', name: 'Casual', allocated: 12);

  test('no entries leaves the full allocation', () {
    final s = computeBalances(types: [casual], entries: []).single;
    expect(s.allocated, 12);
    expect(s.used, 0);
    expect(s.planned, 0);
    expect(s.remaining, 12);
  });

  test('suggested, rejected and cancelled never deduct', () {
    final s = computeBalances(
      types: [casual],
      entries: [
        entry('a', LeaveStatus.suggested, 5),
        entry('b', LeaveStatus.rejected, 3),
        entry('c', LeaveStatus.cancelled, 2),
      ],
    ).single;
    expect(s.used, 0);
    expect(s.planned, 0);
    expect(s.remaining, 12);
  });

  test('planned and applied count as planned, approved as used', () {
    final s = computeBalances(
      types: [casual],
      entries: [
        entry('a', LeaveStatus.planned, 2),
        entry('b', LeaveStatus.applied, 1),
        entry('c', LeaveStatus.approved, 3),
      ],
    ).single;
    expect(s.planned, 3);
    expect(s.used, 3);
    expect(s.remaining, 6);
    expect(s.availableIfPlansFail, 9);
  });

  test('already consumed leaves and half days are included', () {
    const earned = LeaveType(
      id: 'earned',
      name: 'Earned',
      allocated: 15,
      alreadyConsumed: 4,
    );
    final s = computeBalances(
      types: [earned],
      entries: [entry('a', LeaveStatus.approved, 0.5, typeId: 'earned')],
    ).single;
    expect(s.used, 4.5);
    expect(s.remaining, 10.5);
  });

  test('custom deduction rules are honoured', () {
    final s = computeBalances(
      types: [casual],
      entries: [entry('a', LeaveStatus.applied, 2)],
      rules: const DeductionRules(
        usedStatuses: {LeaveStatus.approved, LeaveStatus.applied},
        plannedStatuses: {LeaveStatus.planned},
      ),
    ).single;
    expect(s.used, 2);
    expect(s.planned, 0);
  });

  test('summaries stay per type', () {
    const sick = LeaveType(id: 'sick', name: 'Sick', allocated: 6);
    final result = computeBalances(
      types: [casual, sick],
      entries: [entry('a', LeaveStatus.approved, 1, typeId: 'sick')],
    );
    expect(result[0].used, 0);
    expect(result[1].used, 1);
  });

  test('an entry for an unknown type is rejected', () {
    expect(
      () => computeBalances(
        types: [casual],
        entries: [entry('a', LeaveStatus.approved, 1, typeId: 'nope')],
      ),
      throwsArgumentError,
    );
  });

  group('chargeableDays', () {
    test('counts working days only and skips holidays', () {
      // Mon 25 Jan - Sun 31 Jan 2027, Tue 26 Jan is a holiday.
      expect(
        chargeableDays(
          start: d(2027, 1, 25),
          end: d(2027, 1, 31),
          schedule: WorkSchedule.mondayToFriday,
          holidayDates: {d(2027, 1, 26)},
        ),
        4,
      );
    });

    test('respects a Monday to Saturday schedule', () {
      expect(
        chargeableDays(
          start: d(2027, 1, 25),
          end: d(2027, 1, 31),
          schedule: WorkSchedule.mondayToSaturday,
        ),
        6,
      );
    });

    test('a weekend-only range charges nothing', () {
      expect(
        chargeableDays(
          start: d(2027, 1, 23),
          end: d(2027, 1, 24),
          schedule: WorkSchedule.mondayToFriday,
        ),
        0,
      );
    });
  });
}
