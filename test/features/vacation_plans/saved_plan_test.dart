import 'package:flutter_test/flutter_test.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';
import 'package:leavewise/features/vacation_plans/domain/saved_plan.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

SavedPlan plan({
  List<DateTime>? leaves,
  LeaveStatus status = LeaveStatus.suggested,
}) {
  return SavedPlan(
    id: 'p1',
    title: 'Year end break',
    start: d(2026, 12, 25),
    end: d(2027, 1, 3),
    leavesRequired: 4,
    holidayCount: 2,
    weekendCount: 4,
    leaveDates: leaves ??
        [d(2026, 12, 28), d(2026, 12, 29), d(2026, 12, 30), d(2026, 12, 31)],
    holidayNames: const ['Christmas Day', 'New Year'],
    note: 'Beach trip',
    status: status,
    createdAt: DateTime.utc(2026, 11, 12),
  );
}

void main() {
  test('total days spans the year boundary', () {
    expect(plan().totalDays, 10);
  });

  test('JSON round trip keeps every field', () {
    final original = plan(status: LeaveStatus.approved);
    final copy = SavedPlan.fromJson(original.toJson());
    expect(copy.toJson(), original.toJson());
    expect(copy.status, LeaveStatus.approved);
    expect(copy.leaveDates, original.leaveDates);
  });

  test('malformed JSON is rejected', () {
    expect(() => SavedPlan.fromJson({'id': 'x'}), throwsFormatException);
    expect(
      () => SavedPlan.fromJson({
        'id': 'x',
        'title': 't',
        'start': '2027-02-30',
        'end': '2027-03-01',
      }),
      throwsFormatException,
    );
  });

  test('share text states facts and never promises approval', () {
    final text = plan().shareText();
    expect(text, contains('10 days off using 4 leave days'));
    expect(text, contains('25 Dec 2026 to 3 Jan 2027'));
    expect(text, contains('Christmas Day'));
    expect(text, contains('subject to employer approval'));
  });

  group('leaveEntriesForPlan', () {
    test('groups consecutive dates into runs', () {
      final entries = leaveEntriesForPlan(
        plan(
          leaves: [d(2027, 3, 1), d(2027, 3, 2), d(2027, 3, 4), d(2027, 3, 8)],
          status: LeaveStatus.planned,
        ),
        'casual',
      );
      expect(entries, hasLength(3));
      expect(entries[0].start, d(2027, 3, 1));
      expect(entries[0].end, d(2027, 3, 2));
      expect(entries[0].days, 2);
      expect(entries[1].days, 1);
      expect(entries[2].start, d(2027, 3, 8));
      expect(entries.every((e) => e.status == LeaveStatus.planned), isTrue);
      expect(entries.every((e) => e.planId == 'p1'), isTrue);
      expect(entries.every((e) => e.typeId == 'casual'), isTrue);
    });

    test('runs cross month and year boundaries', () {
      final entries = leaveEntriesForPlan(
        plan(leaves: [d(2026, 12, 31), d(2027, 1, 1), d(2027, 1, 2)]),
        'casual',
      );
      expect(entries, hasLength(1));
      expect(entries.single.days, 3);
      expect(entries.single.end, d(2027, 1, 2));
    });

    test('no leave dates means no entries', () {
      expect(leaveEntriesForPlan(plan(leaves: const []), 'casual'), isEmpty);
    });

    test('a suggested plan deducts nothing once entries are balanced', () {
      const type = LeaveType(id: 'casual', name: 'Casual', allocated: 12);
      List<double> remaining(LeaveStatus status) {
        final entries = leaveEntriesForPlan(plan(status: status), 'casual');
        return [
          computeBalances(types: [type], entries: entries).single.remaining,
        ];
      }

      expect(remaining(LeaveStatus.suggested), [12]);
      expect(remaining(LeaveStatus.rejected), [12]);
      expect(remaining(LeaveStatus.cancelled), [12]);
      expect(remaining(LeaveStatus.planned), [8]);
      expect(remaining(LeaveStatus.approved), [8]);
    });
  });
}
