/// The weekdays on which a user normally works.
///
/// Weekdays use the [DateTime] numbering: Monday = 1 ... Sunday = 7.
class WorkSchedule {
  const WorkSchedule(this.workingWeekdays);

  final Set<int> workingWeekdays;

  static const WorkSchedule mondayToFriday = WorkSchedule({1, 2, 3, 4, 5});
  static const WorkSchedule mondayToSaturday = WorkSchedule({1, 2, 3, 4, 5, 6});

  /// At least one working day and every value within 1..7.
  bool get isValid =>
      workingWeekdays.isNotEmpty &&
      workingWeekdays.every((d) => d >= 1 && d <= 7);

  bool isWorkingDay(DateTime date) => workingWeekdays.contains(date.weekday);

  List<int> toJson() => (workingWeekdays.toList()..sort());

  factory WorkSchedule.fromJson(List<dynamic> json) {
    final schedule = WorkSchedule(json.map((e) => e as int).toSet());
    if (!schedule.isValid) {
      throw const FormatException('Invalid work schedule');
    }
    return schedule;
  }

  @override
  bool operator ==(Object other) =>
      other is WorkSchedule &&
      other.workingWeekdays.length == workingWeekdays.length &&
      other.workingWeekdays.containsAll(workingWeekdays);

  @override
  int get hashCode => Object.hashAll(toJson());
}
