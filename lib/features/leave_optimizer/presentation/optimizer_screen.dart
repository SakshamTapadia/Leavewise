import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/core/widgets/common.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';
import 'package:leavewise/features/vacation_plans/domain/saved_plan.dart';

String _sortLabel(RecommendationSort s) {
  switch (s) {
    case RecommendationSort.maxDaysOff:
      return 'Maximum days off';
    case RecommendationSort.minLeaves:
      return 'Minimum leaves';
    case RecommendationSort.bestEfficiency:
      return 'Best efficiency';
    case RecommendationSort.earliest:
      return 'Earliest first';
  }
}

class OptimizerScreen extends ConsumerStatefulWidget {
  const OptimizerScreen({super.key});

  @override
  ConsumerState<OptimizerScreen> createState() => _OptimizerScreenState();
}

class _OptimizerScreenState extends ConsumerState<OptimizerScreen> {
  static const _presets = [1, 2, 3, 5, 7];

  late int _budget = ref.read(settingsProvider).planningLeaves;
  RecommendationSort _sort = RecommendationSort.bestEfficiency;
  int _horizonMonths = 12;
  bool _allowOverlap = false;
  final _custom = TextEditingController();
  String? _customError;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _applyCustom() {
    final value = int.tryParse(_custom.text.trim());
    if (value == null || value < 1 || value > 60) {
      setState(() => _customError = 'Enter a whole number from 1 to 60.');
      return;
    }
    setState(() {
      _customError = null;
      _budget = value;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final recs = ref.watch(
      recommendationsProvider(
        (
          budget: _budget,
          minDays: 3,
          horizonMonths: _horizonMonths,
          sort: _sort,
          allowOverlap: _allowOverlap,
          limit: 30,
        ),
      ),
    );
    final balance = ref.watch(availableBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Best breaks'),
        actions: [
          IconButton(
            tooltip: 'Saved plans',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => context.push('/plans'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.xl),
        children: [
          Text('Leave budget per break', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Gap.s),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  label: Text('$p'),
                  selected: _budget == p,
                  onSelected: (_) => setState(() => _budget = p),
                ),
              ChoiceChip(
                label: Text(_presets.contains(_budget) ? 'Custom' : 'Custom: $_budget'),
                selected: !_presets.contains(_budget),
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: Gap.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Custom number of leaves',
                    errorText: _customError,
                  ),
                  onSubmitted: (_) => _applyCustom(),
                ),
              ),
              const SizedBox(width: Gap.s),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(onPressed: _applyCustom, child: const Text('Apply')),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),
          Row(
            children: [
              Expanded(
                child: Text(
                  balance == null
                      ? 'No leave balance set, so suggestions are not capped.'
                      : 'Balance remaining: ${plural(balance, 'day')}. '
                          'Suggestions never exceed it.',
                  style: TextStyle(color: mutedColor(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            children: [
              for (final s in RecommendationSort.values)
                ChoiceChip(
                  label: Text(_sortLabel(s)),
                  selected: _sort == s,
                  onSelected: (_) => setState(() => _sort = s),
                ),
            ],
          ),
          const SizedBox(height: Gap.s),
          Wrap(
            spacing: Gap.s,
            children: [
              for (final m in const [6, 12, 24])
                ChoiceChip(
                  label: Text('Next $m months'),
                  selected: _horizonMonths == m,
                  onSelected: (_) => setState(() => _horizonMonths = m),
                ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show overlapping alternatives'),
            subtitle: const Text('Off: each suggestion uses its own days'),
            value: _allowOverlap,
            onChanged: (v) => setState(() => _allowOverlap = v),
          ),
          const SizedBox(height: Gap.s),
          const CalendarLegend(),
          const SizedBox(height: Gap.m),
          if (recs == null)
            const SizedBox(height: 200, child: LoadingState())
          else if (recs.isEmpty)
            const SizedBox(
              height: 260,
              child: EmptyState(
                icon: Icons.search_off,
                title: 'No breaks found',
                message:
                    'Try a larger leave budget or a longer period, or check that '
                    'your leave balance is not zero.',
              ),
            )
          else ...[
            Text(
              '${plural(recs.length, 'option')} found',
              style: TextStyle(color: mutedColor(context)),
            ),
            const SizedBox(height: Gap.s),
            for (final r in recs) _RecommendationCard(recommendation: r),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({required this.recommendation});

  final LeaveRecommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = recommendation;
    final efficiency = r.efficiency.isFinite ? r.efficiency.toStringAsFixed(1) : 'no leave needed';
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              breakTitle(r),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              '${plural(r.totalDays, 'consecutive day')} off for '
              '${plural(r.leavesRequired, 'leave')}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              fmtRange(r.start, r.end),
              style: TextStyle(color: mutedColor(context)),
            ),
            const SizedBox(height: Gap.s),
            BreakStrip(days: r.days),
            const SizedBox(height: Gap.s),
            Text(
              'Holidays: ${r.holidayCount}   Weekends or off days: ${r.weekendCount}   '
              'Efficiency: $efficiency days per leave'
              '${r.existingLeaveCount > 0 ? '   Already planned leave: ${r.existingLeaveCount}' : ''}',
              style: TextStyle(color: mutedColor(context), fontSize: 13),
            ),
            const SizedBox(height: Gap.s),
            Text(
              'Leave needed on: ${r.leaveDates.map(fmtShort).join(', ')}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: Gap.s),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final id = 'plan-${DateTime.now().microsecondsSinceEpoch}';
                  await ref.read(plansProvider.notifier).save(
                        SavedPlan.fromRecommendation(r, id: id, title: breakTitle(r)),
                      );
                  if (context.mounted) {
                    showMessage(context, 'Saved. No leave has been deducted.');
                  }
                },
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
