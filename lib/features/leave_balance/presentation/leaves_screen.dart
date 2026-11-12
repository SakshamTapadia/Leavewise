import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/core/widgets/common.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';

class LeavesScreen extends ConsumerStatefulWidget {
  const LeavesScreen({super.key});

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

enum _Filter { upcoming, history, all }

class _LeavesScreenState extends ConsumerState<LeavesScreen> {
  _Filter _filter = _Filter.upcoming;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final balances = ref.watch(balancesProvider);
    final types = ref.watch(effectiveLeaveTypesProvider);
    final entries = [...ref.watch(normalizedEntriesProvider)]
      ..sort((a, b) => b.start.compareTo(a.start));
    final shown = entries.where((e) {
      switch (_filter) {
        case _Filter.upcoming:
          return !e.end.isBefore(today);
        case _Filter.history:
          return e.end.isBefore(today);
        case _Filter.all:
          return true;
      }
    }).toList();
    final hasEntitlement = ref.watch(hasEntitlementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaves'),
        actions: [
          IconButton(
            tooltip: 'Manage leave types',
            icon: const Icon(Icons.tune),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const _TypesSheet(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLeaveDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add leave'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, 96),
        children: [
          if (!hasEntitlement)
            const Padding(
              padding: EdgeInsets.only(bottom: Gap.s),
              child: AppCard(
                child: Text(
                  'No leave entitlement set. Leave is tracked, but nothing is '
                  'deducted from a balance. Tap the sliders icon to add your '
                  'allocation.',
                ),
              ),
            ),
          for (final b in balances)
            _BalanceCard(
              summary: b,
              name: types.firstWhere((t) => t.id == b.typeId).name,
              showBalance: hasEntitlement,
            ),
          const SizedBox(height: Gap.s),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Filter>(
              segments: const [
                ButtonSegment(value: _Filter.upcoming, label: Text('Upcoming')),
                ButtonSegment(value: _Filter.history, label: Text('History')),
                ButtonSegment(value: _Filter.all, label: Text('All')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          const SizedBox(height: Gap.m),
          if (shown.isEmpty)
            const SizedBox(
              height: 220,
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: 'No leave here yet',
                message: 'Add leave with the button below, or from a day in the calendar.',
              ),
            )
          else
            for (final e in shown)
              _EntryTile(
                entry: e,
                typeName: types.firstWhere((t) => t.id == e.typeId).name,
              ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.summary,
    required this.name,
    required this.showBalance,
  });

  final LeaveBalanceSummary summary;
  final String name;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final used = s.used + s.planned;
    final progress = s.allocated <= 0 ? 0.0 : (used / s.allocated).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s),
      child: AppCard(
        semanticLabel: showBalance
            ? '$name. Allocated ${plural(s.allocated, 'day')}, used ${plural(s.used, 'day')}, '
                'planned ${plural(s.planned, 'day')}, remaining ${plural(s.remaining, 'day')}'
            : '$name. Used ${plural(s.used, 'day')}, planned ${plural(s.planned, 'day')}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Gap.s),
            if (showBalance) ...[
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: Gap.s),
            ],
            Wrap(
              spacing: Gap.m,
              runSpacing: Gap.xs,
              children: [
                if (showBalance) Text('Allocated ${plural(s.allocated, 'day')}'),
                Text('Used ${plural(s.used, 'day')}'),
                Text('Planned ${plural(s.planned, 'day')}'),
                if (showBalance)
                  Text(
                    'Remaining ${plural(s.remaining, 'day')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.typeName});

  final LeaveEntry entry;
  final String typeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s),
      child: AppCard(
        onTap: () => showLeaveDialog(context, ref, existing: entry),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fmtRange(entry.start, entry.end),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$typeName - ${plural(entry.days, 'day')}',
                    style: TextStyle(color: mutedColor(context)),
                  ),
                  if (entry.note.trim().isNotEmpty)
                    Text(entry.note, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            StatusChip(entry.status),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a leave. Pass [existing] to edit or delete.
Future<void> showLeaveDialog(
  BuildContext context,
  WidgetRef ref, {
  LeaveEntry? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LeaveDialog(existing: existing),
  );
}

class _LeaveDialog extends ConsumerStatefulWidget {
  const _LeaveDialog({this.existing});

  final LeaveEntry? existing;

  @override
  ConsumerState<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends ConsumerState<_LeaveDialog> {
  late DateTime _start = widget.existing?.start ?? ref.read(todayProvider);
  late DateTime _end = widget.existing?.end ?? ref.read(todayProvider);
  late String _typeId =
      widget.existing?.typeId ?? ref.read(effectiveLeaveTypesProvider).first.id;
  late LeaveStatus _status = widget.existing?.status ?? LeaveStatus.planned;
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
  }

  double _days() {
    return chargeableDays(
      start: _start,
      end: _end,
      schedule: ref.read(settingsProvider).schedule,
      holidayDates: ref.read(holidaysByDateProvider).keys.toSet(),
    );
  }

  Future<void> _save() async {
    if (_end.isBefore(_start)) {
      setState(() => _error = 'The end date is before the start date.');
      return;
    }
    final days = _days();
    if (days <= 0) {
      setState(() => _error = 'No working days in this range, so there is nothing to deduct.');
      return;
    }
    final notifier = ref.read(leaveEntriesProvider.notifier);
    final navigator = Navigator.of(context);
    final existing = widget.existing;
    final entry = LeaveEntry(
      id: existing?.id ?? 'leave-${DateTime.now().microsecondsSinceEpoch}',
      typeId: _typeId,
      start: _start,
      end: _end,
      days: days,
      status: _status,
      note: _note.text.trim(),
      planId: existing?.planId,
    );
    if (existing == null) {
      await notifier.add(entry);
    } else {
      await notifier.replace(entry);
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await ref.read(leaveEntriesProvider.notifier).remove(widget.existing!.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(effectiveLeaveTypesProvider);
    final validRange = !_end.isBefore(_start);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add leave' : 'Edit leave'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await _pick(_start);
                      if (d == null) return;
                      setState(() {
                        _start = DateTime.utc(d.year, d.month, d.day);
                        if (_end.isBefore(_start)) _end = _start;
                      });
                    },
                    child: Text('From ${fmtShort(_start)}'),
                  ),
                ),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await _pick(_end);
                      if (d == null) return;
                      setState(() => _end = DateTime.utc(d.year, d.month, d.day));
                    },
                    child: Text('To ${fmtShort(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.s),
            Text(
              validRange
                  ? 'Will use ${plural(_days(), 'working day')}'
                  : 'End date must not be before start date',
            ),
            const SizedBox(height: Gap.m),
            Wrap(
              spacing: Gap.s,
              children: [
                for (final t in types)
                  ChoiceChip(
                    label: Text(t.name),
                    selected: _typeId == t.id,
                    onSelected: (_) => setState(() => _typeId = t.id),
                  ),
              ],
            ),
            const SizedBox(height: Gap.s),
            Wrap(
              spacing: Gap.s,
              children: [
                for (final s in LeaveStatus.values)
                  ChoiceChip(
                    label: Text(leaveStatusLabel(s)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            const SizedBox(height: Gap.s),
            TextField(
              controller: _note,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _delete,
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _TypesSheet extends ConsumerStatefulWidget {
  const _TypesSheet();

  @override
  ConsumerState<_TypesSheet> createState() => _TypesSheetState();
}

class _TypesSheetState extends ConsumerState<_TypesSheet> {
  Future<void> _edit(LeaveType? existing) async {
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final allocCtl = TextEditingController(
      text: existing == null ? '' : fmtNum(existing.allocated),
    );
    final usedCtl = TextEditingController(
      text: existing == null ? '' : fmtNum(existing.alreadyConsumed),
    );
    String? error;
    final result = await showDialog<LeaveType>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add leave type' : 'Edit leave type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: allocCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Days per year'),
              ),
              const SizedBox(height: Gap.s),
              TextField(
                controller: usedCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Already used before using the app'),
              ),
              if (error != null)
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtl.text.trim();
                final alloc = double.tryParse(allocCtl.text.trim().isEmpty ? '0' : allocCtl.text.trim());
                final used = double.tryParse(usedCtl.text.trim().isEmpty ? '0' : usedCtl.text.trim());
                if (name.isEmpty) {
                  setLocal(() => error = 'Enter a name.');
                  return;
                }
                if (alloc == null || used == null || alloc < 0 || used < 0 || alloc > 366 || used > 366) {
                  setLocal(() => error = 'Enter numbers between 0 and 366.');
                  return;
                }
                Navigator.of(context).pop(
                  LeaveType(
                    id: existing?.id ?? 'type-${DateTime.now().microsecondsSinceEpoch}',
                    name: name,
                    allocated: alloc,
                    alreadyConsumed: used,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameCtl.dispose();
    allocCtl.dispose();
    usedCtl.dispose();
    if (result != null) {
      await ref.read(leaveTypesProvider.notifier).upsert(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(leaveTypesProvider);
    final entries = ref.watch(leaveEntriesProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
        children: [
          Text('Leave types', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Gap.s),
          if (types.isEmpty)
            Text(
              'No leave types yet. Add one to set an entitlement.',
              style: TextStyle(color: mutedColor(context)),
            ),
          for (final t in types)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.name),
              subtitle: Text(
                '${plural(t.allocated, 'day')} per year, ${plural(t.alreadyConsumed, 'day')} already used',
              ),
              onTap: () => _edit(t),
              trailing: IconButton(
                tooltip: 'Delete ${t.name}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (entries.any((e) => e.typeId == t.id)) {
                    showMessage(context, 'Remove the leave using ${t.name} first.');
                    return;
                  }
                  await ref.read(leaveTypesProvider.notifier).remove(t.id);
                },
              ),
            ),
          const SizedBox(height: Gap.s),
          FilledButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('Add leave type'),
          ),
        ],
      ),
    );
  }
}
