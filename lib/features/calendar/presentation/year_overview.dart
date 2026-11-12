import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/core/utils/format.dart';

/// All twelve months of a year as small grids. Each month also states its
/// counts in text, so the overview never relies on color alone.
class YearOverview extends ConsumerWidget {
  const YearOverview({super.key, required this.year, required this.onMonthTap});

  final int year;
  final void Function(int month) onMonthTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Gap.m,
      crossAxisSpacing: Gap.s,
      childAspectRatio: 0.82,
      children: [
        for (var m = 1; m <= 12; m++)
          _MiniMonth(year: year, month: m, onTap: () => onMonthTap(m)),
      ],
    );
  }
}

class _MiniMonth extends ConsumerWidget {
  const _MiniMonth({required this.year, required this.month, required this.onTap});

  final int year;
  final int month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(settingsProvider.select((s) => s.schedule));
    final holidays = ref.watch(holidaysByDateProvider);
    final leaves = ref.watch(leaveDayMapProvider);
    final today = ref.watch(todayProvider);

    final first = DateTime.utc(year, month, 1);
    final lead = first.weekday - 1;
    final count = daysInMonth(year, month);
    var holidayCount = 0;
    var leaveCount = 0;

    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= count; day++) {
      final date = DateTime.utc(year, month, day);
      Color? color;
      if (holidays.containsKey(date)) {
        color = AppColors.holiday;
        holidayCount++;
      } else if (leaves.containsKey(date)) {
        color = AppColors.leave;
        leaveCount++;
      } else if (!schedule.isWorkingDay(date)) {
        color = AppColors.weekend;
      }
      final isToday = date == today;
      cells.add(
        Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: isToday
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                : null,
          ),
        ),
      );
    }

    final summary = '${monthName(month)} $year: '
        '${plural(holidayCount, 'holiday')}, ${plural(leaveCount, 'leave day')}';
    return Semantics(
      label: summary,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthShort(month),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 7,
                  physics: const NeverScrollableScrollPhysics(),
                  children: cells,
                ),
              ),
              Text(
                'H$holidayCount  L$leaveCount',
                style: TextStyle(fontSize: 11, color: mutedColor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
