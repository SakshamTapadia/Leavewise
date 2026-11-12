import 'package:flutter/material.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Gap.m),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final card = Material(
      color: isLight ? Colors.white : AppColors.darkCard,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      shadowColor: Colors.black,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLight ? const Color(0xFFEAEAF1) : const Color(0xFF2A2B38),
            ),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
    if (semanticLabel == null) return card;
    return Semantics(label: semanticLabel, container: true, child: card);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.l, bottom: Gap.s),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: mutedColor(context),
                    ),
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: mutedColor(context)),
            const SizedBox(height: Gap.m),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.s),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor(context)),
            ),
            if (action != null) ...[const SizedBox(height: Gap.m), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading',
        child: const CircularProgressIndicator.adaptive(),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final color = leaveStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        leaveStatusLabel(status),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.light
              ? color
              : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// A single colored swatch plus a text label. Used in legends.
class LegendItem extends StatelessWidget {
  const LegendItem({
    super.key,
    required this.color,
    required this.letter,
    required this.label,
  });

  final Color color;
  final String letter;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: Gap.m,
      runSpacing: Gap.s,
      children: [
        LegendItem(color: AppColors.holiday, letter: 'H', label: 'Public holiday'),
        LegendItem(color: AppColors.leave, letter: 'L', label: 'Planned leave'),
        LegendItem(color: AppColors.weekend, letter: 'O', label: 'Weekend or off'),
      ],
    );
  }
}

/// Day-by-day strip for a break. Each day shows its number and a letter, so
/// the meaning never depends on color alone.
class BreakStrip extends StatelessWidget {
  const BreakStrip({super.key, required this.days});

  final List<BreakDay> days;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final d in days)
          Semantics(
            label:
                '${weekdayName(d.date)} ${fmtDate(d.date)}, ${dayKindLabel(d.kind)}'
                '${d.holidayNames.isEmpty ? '' : ', ${d.holidayNames.join(', ')}'}',
            excludeSemantics: true,
            child: Container(
              width: 34,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dayKindColor(d.kind),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${d.date.day}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    dayKindLetter(d.kind),
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
      ],
    );
  }
}

/// Title for a recommendation, built from what is actually in it.
String breakTitle(LeaveRecommendation r) {
  for (final d in r.days) {
    if (d.holidayNames.isNotEmpty) return '${d.holidayNames.first} break';
  }
  return '${monthName(r.start.month)} break';
}

/// One-line summary that only states what the calendar supports.
String breakSummary(LeaveRecommendation r) {
  return '${plural(r.totalDays, 'consecutive day')} off, '
      '${plural(r.leavesRequired, 'leave')} required';
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
