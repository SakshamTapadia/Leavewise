import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/core/widgets/common.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';
import 'package:leavewise/features/vacation_plans/domain/saved_plan.dart';
import 'package:share_plus/share_plus.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved plans')),
      body: plans.isEmpty
          ? EmptyState(
              icon: Icons.bookmarks_outlined,
              title: 'No saved plans yet',
              message:
                  'Save a suggestion from the Breaks tab to keep it here. '
                  'Saving does not deduct any leave.',
              action: FilledButton(
                onPressed: () => context.go('/breaks'),
                child: const Text('Find breaks'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(Gap.m),
              children: [for (final p in plans) _PlanCard(plan: p)],
            ),
    );
  }
}

enum _Action { edit, duplicate, export, share, delete }

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final SavedPlan plan;

  Future<void> _setStatus(WidgetRef ref, LeaveStatus status) {
    return ref.read(plansProvider.notifier).save(plan.copyWith(status: status));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                StatusChip(plan.status),
                PopupMenuButton<_Action>(
                  tooltip: 'Plan actions',
                  onSelected: (a) => _handle(context, ref, a),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _Action.edit, child: Text('Edit')),
                    PopupMenuItem(value: _Action.duplicate, child: Text('Duplicate')),
                    PopupMenuItem(value: _Action.export, child: Text('Export')),
                    PopupMenuItem(value: _Action.share, child: Text('Share')),
                    PopupMenuItem(value: _Action.delete, child: Text('Delete')),
                  ],
                ),
              ],
            ),
            Text(fmtRange(plan.start, plan.end)),
            Text(
              '${plural(plan.totalDays, 'day')} off using ${plural(plan.leavesRequired, 'leave day')}',
              style: TextStyle(color: mutedColor(context)),
            ),
            const SizedBox(height: Gap.s),
            _PlanStrip(plan: plan),
            const SizedBox(height: Gap.s),
            if (plan.holidayNames.isNotEmpty)
              Text('Holidays included: ${plan.holidayNames.join(', ')}'),
            Text(
              'Leave on: ${plan.leaveDates.isEmpty ? 'none needed' : plan.leaveDates.map(fmtShort).join(', ')}',
              style: const TextStyle(fontSize: 13),
            ),
            if (plan.note.trim().isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(plan.note, style: TextStyle(color: mutedColor(context))),
            ],
            const SizedBox(height: Gap.s),
            Wrap(
              spacing: Gap.s,
              runSpacing: Gap.xs,
              children: [
                for (final entry in const [
                  (LeaveStatus.planned, 'Mark planned'),
                  (LeaveStatus.applied, 'Mark applied'),
                  (LeaveStatus.approved, 'Mark approved'),
                  (LeaveStatus.rejected, 'Mark rejected'),
                  (LeaveStatus.cancelled, 'Cancel'),
                ])
                  if (plan.status != entry.$1)
                    ActionChip(
                      label: Text(entry.$2),
                      onPressed: () => _setStatus(ref, entry.$1),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, _Action action) async {
    final notifier = ref.read(plansProvider.notifier);
    switch (action) {
      case _Action.edit:
        await showDialog<void>(
          context: context,
          builder: (_) => _EditPlanDialog(plan: plan),
        );
      case _Action.duplicate:
        final copy = SavedPlan(
          id: 'plan-${DateTime.now().microsecondsSinceEpoch}',
          title: '${plan.title} (copy)',
          start: plan.start,
          end: plan.end,
          leavesRequired: plan.leavesRequired,
          holidayCount: plan.holidayCount,
          weekendCount: plan.weekendCount,
          leaveDates: plan.leaveDates,
          holidayNames: plan.holidayNames,
          note: plan.note,
        );
        await notifier.save(copy);
        if (context.mounted) showMessage(context, 'Plan duplicated as a suggestion');
      case _Action.export:
        await Share.share(
          const JsonEncoder.withIndent('  ').convert(plan.toJson()),
          subject: '${plan.title} (LeaveWise plan data)',
        );
      case _Action.share:
        await Share.share(plan.shareText(), subject: plan.title);
      case _Action.delete:
        final ok = await showAdaptiveDialog<bool>(
          context: context,
          builder: (context) => AlertDialog.adaptive(
            title: const Text('Delete this plan?'),
            content: Text(
              plan.status == LeaveStatus.suggested
                  ? 'The plan will be removed.'
                  : 'The plan and the leave entries created from it will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) await notifier.delete(plan.id);
    }
  }
}

class _PlanStrip extends StatelessWidget {
  const _PlanStrip({required this.plan});

  final SavedPlan plan;

  @override
  Widget build(BuildContext context) {
    final leaves = plan.leaveDates.toSet();
    final days = <Widget>[];
    var date = plan.start;
    while (!date.isAfter(plan.end)) {
      final isLeave = leaves.contains(date);
      days.add(
        Semantics(
          label: '${fmtDate(date)}, ${isLeave ? 'leave needed' : 'already off'}',
          excludeSemantics: true,
          child: Container(
            width: 34,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLeave ? AppColors.leave : AppColors.weekend,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  isLeave ? 'L' : 'O',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      date = DateTime.utc(date.year, date.month, date.day + 1);
    }
    return Wrap(spacing: 4, runSpacing: 4, children: days);
  }
}

class _EditPlanDialog extends ConsumerStatefulWidget {
  const _EditPlanDialog({required this.plan});

  final SavedPlan plan;

  @override
  ConsumerState<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends ConsumerState<_EditPlanDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.plan.title);
  late final TextEditingController _note =
      TextEditingController(text: widget.plan.note);
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    final navigator = Navigator.of(context);
    await ref.read(plansProvider.notifier).save(
          widget.plan.copyWith(title: title, note: _note.text.trim()),
        );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit plan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: 60,
              decoration: InputDecoration(labelText: 'Title', errorText: _error),
            ),
            TextField(
              controller: _note,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
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
