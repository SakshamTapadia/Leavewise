import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';

double _num(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

Map<String, dynamic> leaveTypeToJson(LeaveType t) => {
      'id': t.id,
      'name': t.name,
      'allocated': t.allocated,
      'consumed': t.alreadyConsumed,
    };

LeaveType leaveTypeFromJson(Map<String, dynamic> j) {
  final id = j['id'];
  final name = j['name'];
  if (id is! String || name is! String) {
    throw const FormatException('Invalid leave type');
  }
  return LeaveType(
    id: id,
    name: name,
    allocated: _num(j['allocated']),
    alreadyConsumed: _num(j['consumed']),
  );
}

Map<String, dynamic> leaveEntryToJson(LeaveEntry e) => {
      'id': e.id,
      'typeId': e.typeId,
      'start': formatDateKey(e.start),
      'end': formatDateKey(e.end),
      'days': e.days,
      'status': e.status.name,
      'note': e.note,
      if (e.planId != null) 'planId': e.planId,
    };

LeaveEntry leaveEntryFromJson(Map<String, dynamic> j) {
  final id = j['id'];
  final typeId = j['typeId'];
  final start = j['start'];
  final end = j['end'];
  if (id is! String || typeId is! String || start is! String || end is! String) {
    throw const FormatException('Invalid leave entry');
  }
  final status = LeaveStatus.values.where((s) => s.name == j['status']);
  final note = j['note'];
  final planId = j['planId'];
  return LeaveEntry(
    id: id,
    typeId: typeId,
    start: parseDateKey(start),
    end: parseDateKey(end),
    days: _num(j['days']),
    status: status.isEmpty ? LeaveStatus.planned : status.first,
    note: note is String ? note : '',
    planId: planId is String ? planId : null,
  );
}
