import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/core/widgets/common.dart';
import 'package:leavewise/features/calendar/presentation/year_overview.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';
import 'package:leavewise/features/vacation_plans/domain/saved_plan.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning!';
  if (hour < 17) return 'Good afternoon!';
  return 'Good evening!';
}

String _countdown(int days) {
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider);
    return Scaffold(
      body: SafeArea(
        child: holidays.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(
            message: 'The holiday data could not be loaded.',
            onRetry: () => ref.invalidate(holidayDatasetProvider),
          ),
          data: (list) => _Content(holidays: list),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.holidays});

  final List<Holiday> holidays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider);
    final upcoming = holidays.where((h) => !h.date.isBefore(today)).toList();
    final next = upcoming.isEmpty ? null : upcoming.first;
    final endOfYear = DateTime.utc(today.year, 12, 31);
    final thisYearCount =
        upcoming.where((h) => !h.date.isAfter(endOfYear)).map((h) => h.date).toSet().length;

    final breaks = ref.watch(
      recommendationsProvider(
        (
          budget: settings.planningLeaves,
          minDays: 4,
          horizonMonths: 12,
          sort: RecommendationSort.bestEfficiency,
          allowOverlap: false,
          limit: 3,
        ),
      ),
    );
    final best = ref.watch(
      recommendationsProvider(
        (
          budget: settings.planningLeaves,
          minDays: 3,
          horizonMonths: 12,
          sort: RecommendationSort.maxDaysOff,
          allowOverlap: true,
          limit: 1,
        ),
      ),
    );
    final stretches = ref.watch(freeStretchesProvider);
    final balance = ref.watch(availableBalanceProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, Gap.xl),
      children: [
        Semantics(
          header: true,
          child: Text(
            _greeting(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Your next break is closer than you think.',
          style: TextStyle(color: mutedColor(context)),
        ),
        const SizedBox(height: Gap.l),
        _NextHolidayCard(holiday: next, today: today),
        const SizedBox(height: Gap.m),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Gap.s,
          crossAxisSpacing: Gap.s,
          childAspectRatio: 1.45,
          children: [
            _SummaryCard(
              label: 'Upcoming holidays',
              value: '$thisYearCount',
              caption: 'left in ${today.year}',
              icon: Icons.flag_outlined,
            ),
            _SummaryCard(
              label: 'Available leaves',
              value: balance == null ? 'Not set' : '$balance',
              caption: balance == null ? 'add in Leaves' : 'days remaining',
              icon: Icons.event_available_outlined,
            ),
            _SummaryCard(
              label: 'Long weekends',
              value: stretches == null ? '-' : '${stretches.length}',
              caption: 'next 12 months, no leave',
              icon: Icons.weekend_outlined,
            ),
            _SummaryCard(
              label: 'Potential vacation',
              value: best == null || best.isEmpty ? '-' : '${best.first.totalDays} days',
              caption: best == null || best.isEmpty
                  ? 'nothing found'
                  : 'with ${plural(best.first.leavesRequired, 'leave')}',
              icon: Icons.beach_access_outlined,
            ),
          ],
        ),
        const SectionHeader('Best upcoming breaks'),
        if (breaks == null || breaks.isEmpty)
          const AppCard(
            child: Text(
              'No breaks found yet. Check your holiday settings or add leave '
              'budget in Breaks.',
            ),
          )
        else
          for (final r in breaks) _BreakCard(recommendation: r),
        SectionHeader(
          'Upcoming holidays',
          action: TextButton(
            onPressed: () => context.go('/calendar'),
            child: const Text('Calendar'),
          ),
        ),
        if (upcoming.isEmpty)
          const AppCard(child: Text('No upcoming holidays found.'))
        else
          for (final h in upcoming.take(5)) _HolidayRow(holiday: h, today: today),
        const SectionHeader('Your year'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YearOverview(
                year: today.year,
                onMonthTap: (month) => context.go('/calendar'),
              ),
              const SizedBox(height: Gap.m),
              const CalendarLegend(),
              const SizedBox(height: Gap.m),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/breaks'),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Explore all leave opportunities'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextHolidayCard extends StatelessWidget {
  const _NextHolidayCard({required this.holiday, required this.today});

  final Holiday? holiday;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final h = holiday;
    if (h == null) {
      return const AppCard(child: Text('No upcoming holidays for your settings.'));
    }
    final days = daysBetween(today, h.date);
    return Semantics(
      label: 'Next holiday, ${h.name}, ${weekdayName(h.date)} ${fmtDate(h.date)}, '
          '${_countdown(days)}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.l),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT HOLIDAY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: Gap.s),
            Text(
              h.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              '${weekdayName(h.date)}, ${fmtDate(h.date)}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: Gap.m),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.leave,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _countdown(days),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (h.verification != VerificationStatus.verified) ...[
                  const SizedBox(width: Gap.s),
                  const Text(
                    'Date tentative',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel: '$label: $value, $caption',
      padding: const EdgeInsets.all(Gap.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: mutedColor(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: mutedColor(context), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Text(
            caption,
            style: TextStyle(color: mutedColor(context), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BreakCard extends ConsumerWidget {
  const _BreakCard({required this.recommendation});

  final LeaveRecommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = recommendation;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              breakTitle(r).toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: Gap.xs),
            Text(breakSummary(r)),
            Text(
              fmtRange(r.start, r.end),
              style: TextStyle(color: mutedColor(context)),
            ),
            const SizedBox(height: Gap.s),
            BreakStrip(days: r.days),
            const SizedBox(height: Gap.s),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final id = 'plan-${DateTime.now().microsecondsSinceEpoch}';
                  await ref.read(plansProvider.notifier).save(
                        SavedPlan.fromRecommendation(
                          r,
                          id: id,
                          title: breakTitle(r),
                        ),
                      );
                  if (context.mounted) showMessage(context, 'Saved to your plans');
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

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.holiday, required this.today});

  final Holiday holiday;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = daysBetween(today, holiday.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s),
        semanticLabel:
            '${holiday.name}, ${weekdayName(holiday.date)} ${fmtDate(holiday.date)}, '
            '${_countdown(days)}',
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.holiday,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${holiday.date.day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    monthShort(holiday.date.month),
                    style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${weekdayName(holiday.date)} - ${_countdown(days)}'
                    '${holiday.verification == VerificationStatus.verified ? '' : ' - tentative'}',
                    style: TextStyle(color: mutedColor(context), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
