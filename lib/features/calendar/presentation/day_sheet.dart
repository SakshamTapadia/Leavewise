import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';

Future<void> showDaySheet(BuildContext context, DateTime date) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DaySheet(date: date),
  );
}

String holidayCategoryLabel(Holiday h) {
  final base = switch (h.category) {
    HolidayCategory.national => 'National',
    HolidayCategory.regional => 'Regional',
    HolidayCategory.religious => 'Religious',
    HolidayCategory.company => 'Company',
    HolidayCategory.custom => 'Personal',
  };
  return h.isOptional ? '$base, optional' : base;
}

class DaySheet extends ConsumerStatefulWidget {
  const DaySheet({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<DaySheet> {
  String? _typeId;

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final settings = ref.watch(settingsProvider);
    final holidays = ref.watch(holidaysByDateProvider)[date] ?? const <Holiday>[];
    final leaves = ref.watch(leaveDayMapProvider)[date] ?? const <LeaveEntry>[];
    final types = ref.watch(effectiveLeaveTypesProvider);
    final isWorking = settings.schedule.isWorkingDay(date);
    final typeId = _typeId ?? types.first.id;

    final String workStatus;
    if (holidays.isNotEmpty) {
      workStatus = 'Off (public holiday)';
    } else if (!isWorking) {
      workStatus = 'Off (not a working day)';
    } else if (leaves.isNotEmpty) {
      workStatus = 'Off (on leave)';
    } else {
      workStatus = 'Working day';
    }

    final String? cannotAddReason;
    if (leaves.isNotEmpty) {
      cannotAddReason = 'Leave is already planned for this day.';
    } else if (holidays.isNotEmpty) {
      cannotAddReason = 'This day is a holiday, so no leave is needed.';
    } else if (!isWorking) {
      cannotAddReason = 'This is not a working day, so no leave is needed.';
    } else {
      cannotAddReason = null;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Gap.l,
          0,
          Gap.l,
          Gap.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                fmtDate(date),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(weekdayName(date), style: TextStyle(color: mutedColor(context))),
            const SizedBox(height: Gap.m),
            _Line(label: 'Working status', value: workStatus),
            _Line(
              label: 'Leave status',
              value: leaves.isEmpty
                  ? 'No leave'
                  : leaves.map((e) => leaveStatusLabel(e.status)).toSet().join(', '),
            ),
            if (leaves.any((e) => e.note.trim().isNotEmpty))
              _Line(
                label: 'Notes',
                value: leaves
                    .map((e) => e.note.trim())
                    .where((n) => n.isNotEmpty)
                    .toSet()
                    .join('; '),
              ),
            const SizedBox(height: Gap.s),
            Text('Holidays', style: Theme.of(context).textTheme.titleSmall),
            if (holidays.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.s),
                child: Text(
                  'No holiday on this day.',
                  style: TextStyle(color: mutedColor(context)),
                ),
              ),
            for (final h in holidays) _HolidayTile(holiday: h),
            const SizedBox(height: Gap.m),
            if (types.length > 1 && cannotAddReason == null) ...[
              Wrap(
                spacing: Gap.s,
                children: [
                  for (final t in types)
                    ChoiceChip(
                      label: Text(t.name),
                      selected: typeId == t.id,
                      onSelected: (_) => setState(() => _typeId = t.id),
                    ),
                ],
              ),
              const SizedBox(height: Gap.s),
            ],
            if (cannotAddReason != null && leaves.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: Text(
                  cannotAddReason,
                  style: TextStyle(color: mutedColor(context)),
                ),
              ),
            Wrap(
              spacing: Gap.s,
              runSpacing: Gap.s,
              children: [
                FilledButton.icon(
                  onPressed: cannotAddReason != null
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          await ref.read(leaveEntriesProvider.notifier).add(
                                LeaveEntry(
                                  id: 'leave-${DateTime.now().microsecondsSinceEpoch}',
                                  typeId: typeId,
                                  start: date,
                                  end: date,
                                  days: 1,
                                  status: LeaveStatus.planned,
                                ),
                              );
                          navigator.pop();
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Add leave'),
                ),
                OutlinedButton.icon(
                  onPressed: leaves.isEmpty
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          await ref.read(leaveEntriesProvider.notifier).removeDate(
                                date,
                                settings.schedule,
                                ref.read(holidaysByDateProvider).keys.toSet(),
                              );
                          navigator.pop();
                        },
                  icon: const Icon(Icons.remove),
                  label: const Text('Remove leave'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editHoliday(context, ref, date, null),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Add custom holiday'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: mutedColor(context))),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _HolidayTile extends ConsumerWidget {
  const _HolidayTile({required this.holiday});

  final Holiday holiday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = isUserHoliday(holiday);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.holiday,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(holiday.name),
      subtitle: Text(
        '${holidayCategoryLabel(holiday)}'
        '${holiday.verification == VerificationStatus.verified ? '' : ', date tentative'}',
      ),
      trailing: mine
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit holiday',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editHoliday(context, ref, holiday.date, holiday),
                ),
                IconButton(
                  tooltip: 'Delete holiday',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(customHolidaysProvider.notifier).remove(holiday.id),
                ),
              ],
            )
          : null,
    );
  }
}

Future<void> _editHoliday(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  Holiday? existing,
) async {
  final result = await showDialog<Holiday>(
    context: context,
    builder: (context) => _HolidayDialog(
      date: date,
      existing: existing,
      countryCode: ref.read(settingsProvider).countryCode,
    ),
  );
  if (result == null) return;
  final notifier = ref.read(customHolidaysProvider.notifier);
  if (existing == null) {
    await notifier.add(result);
  } else {
    await notifier.replace(result);
  }
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({
    required this.date,
    required this.existing,
    required this.countryCode,
  });

  final DateTime date;
  final Holiday? existing;
  final String countryCode;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late HolidayCategory _category =
      widget.existing?.category == HolidayCategory.company
          ? HolidayCategory.company
          : widget.existing?.category ?? HolidayCategory.company;
  late bool _optional = widget.existing?.isOptional ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (name.length > 60) {
      setState(() => _error = 'Keep the name under 60 characters.');
      return;
    }
    final id = widget.existing?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}';
    Navigator.of(context).pop(
      Holiday(
        id: id,
        name: name,
        date: widget.date,
        countryCode: widget.countryCode,
        category: _category,
        source: 'Added by you',
        verification: VerificationStatus.verified,
        isOptional: _optional,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add custom holiday' : 'Edit holiday'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtDate(widget.date)),
            const SizedBox(height: Gap.s),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Holiday name',
                errorText: _error,
              ),
            ),
            Wrap(
              spacing: Gap.s,
              children: [
                ChoiceChip(
                  label: const Text('Company'),
                  selected: _category == HolidayCategory.company,
                  onSelected: (_) => setState(() => _category = HolidayCategory.company),
                ),
                ChoiceChip(
                  label: const Text('Personal'),
                  selected: _category == HolidayCategory.custom,
                  onSelected: (_) => setState(() => _category = HolidayCategory.custom),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Optional holiday'),
              subtitle: const Text('Counted only if optional holidays are enabled'),
              value: _optional,
              onChanged: (v) => setState(() => _optional = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
