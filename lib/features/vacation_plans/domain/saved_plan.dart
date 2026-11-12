import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';

class SavedPlan {
  SavedPlan({
    required this.id,
    required this.title,
    required DateTime start,
    required DateTime end,
    required this.leavesRequired,
    required this.holidayCount,
    required this.weekendCount,
    List<DateTime> leaveDates = const [],
    List<String> holidayNames = const [],
    this.note = '',
    this.status = LeaveStatus.suggested,
    DateTime? createdAt,
  })  : start = dateOnly(start),
        end = dateOnly(end),
        leaveDates = List.unmodifiable(leaveDates.map<DateTime>(dateOnly)),
        holidayNames = List.unmodifiable(holidayNames),
        createdAt = createdAt ?? DateTime.now().toUtc();

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final int leavesRequired;
  final int holidayCount;
  final int weekendCount;

  /// The exact dates that need leave. This is the leave breakdown.
  final List<DateTime> leaveDates;
  final List<String> holidayNames;
  final String note;
  final LeaveStatus status;
  final DateTime createdAt;

  int get totalDays => daysBetween(start, end) + 1;

  factory SavedPlan.fromRecommendation(
    LeaveRecommendation r, {
    required String id,
    required String title,
  }) {
    final names = <String>[];
    for (final day in r.days) {
      for (final n in day.holidayNames) {
        if (!names.contains(n)) names.add(n);
      }
    }
    return SavedPlan(
      id: id,
      title: title,
      start: r.start,
      end: r.end,
      leavesRequired: r.leavesRequired,
      holidayCount: r.holidayCount,
      weekendCount: r.weekendCount,
      leaveDates: r.leaveDates,
      holidayNames: names,
    );
  }

  SavedPlan copyWith({
    String? id,
    String? title,
    String? note,
    LeaveStatus? status,
  }) {
    return SavedPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start,
      end: end,
      leavesRequired: leavesRequired,
      holidayCount: holidayCount,
      weekendCount: weekendCount,
      leaveDates: leaveDates,
      holidayNames: holidayNames,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': formatDateKey(start),
        'end': formatDateKey(end),
        'leavesRequired': leavesRequired,
        'holidayCount': holidayCount,
        'weekendCount': weekendCount,
        'leaveDates': leaveDates.map(formatDateKey).toList(),
        'holidayNames': holidayNames,
        'note': note,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedPlan.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final title = j['title'];
    final start = j['start'];
    final end = j['end'];
    if (id is! String || title is! String || start is! String || end is! String) {
      throw const FormatException('Invalid plan');
    }
    final status = LeaveStatus.values.where((s) => s.name == j['status']);
    final dates = j['leaveDates'];
    final names = j['holidayNames'];
    final created = j['createdAt'];
    final note = j['note'];
    return SavedPlan(
      id: id,
      title: title,
      start: parseDateKey(start),
      end: parseDateKey(end),
      leavesRequired: j['leavesRequired'] is int ? j['leavesRequired'] as int : 0,
      holidayCount: j['holidayCount'] is int ? j['holidayCount'] as int : 0,
      weekendCount: j['weekendCount'] is int ? j['weekendCount'] as int : 0,
      leaveDates: dates is List
          ? [for (final d in dates) if (d is String) parseDateKey(d)]
          : const [],
      holidayNames: names is List ? [for (final n in names) if (n is String) n] : const [],
      note: note is String ? note : '',
      status: status.isEmpty ? LeaveStatus.suggested : status.first,
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }

  /// Plain text for sharing. Never promises approval.
  String shareText() {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln(fmtRange(start, end))
      ..writeln(
        '${plural(totalDays, 'day')} off using ${plural(leavesRequired, 'leave day')}',
      );
    if (holidayNames.isNotEmpty) {
      buffer.writeln('Holidays: ${holidayNames.join(', ')}');
    }
    if (note.trim().isNotEmpty) buffer.writeln(note.trim());
    buffer.write('Planned with LeaveWise. Leave is subject to employer approval.');
    return buffer.toString();
  }
}

/// Groups a plan's leave dates into runs of consecutive calendar days and
/// returns one leave entry per run, carrying the plan's status.
List<LeaveEntry> leaveEntriesForPlan(SavedPlan plan, String typeId) {
  final dates = [...plan.leaveDates]..sort();
  final entries = <LeaveEntry>[];
  var index = 0;
  var i = 0;
  while (i < dates.length) {
    var j = i;
    while (j + 1 < dates.length && daysBetween(dates[j], dates[j + 1]) == 1) {
      j++;
    }
    entries.add(
      LeaveEntry(
        id: 'plan-${plan.id}-$index',
        typeId: typeId,
        start: dates[i],
        end: dates[j],
        days: (j - i + 1).toDouble(),
        status: plan.status,
        note: plan.title,
        planId: plan.id,
      ),
    );
    index++;
    i = j + 1;
  }
  return entries;
}
