import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/core/utils/format.dart';
import 'package:leavewise/core/widgets/common.dart';
import 'package:leavewise/features/calendar/presentation/day_sheet.dart';
import 'package:leavewise/features/calendar/presentation/year_overview.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';

enum _View { month, year, agenda }

const int _firstYear = 2000;
const int _lastYear = 2100;

int _pageOf(int year, int month) => (year - _firstYear) * 12 + (month - 1);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _View _view = _View.month;
  late final PageController _pages;
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    _year = today.year;
    _month = today.month;
    _pages = PageController(initialPage: _pageOf(_year, _month));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int year, int month, {bool animate = true}) {
    final clamped = year.clamp(_firstYear, _lastYear);
    final page = _pageOf(clamped, month);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (animate && !reduce && _pages.hasClients) {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else if (_pages.hasClients) {
      _pages.jumpToPage(page);
    }
    setState(() {
      _year = clamped;
      _month = month;
    });
  }

  Future<void> _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month, 1),
      firstDate: DateTime(_firstYear),
      lastDate: DateTime(_lastYear, 12, 31),
      helpText: 'Jump to a date',
    );
    if (picked == null || !mounted) return;
    _goTo(picked.year, picked.month, animate: false);
    if (_view != _View.month) setState(() => _view = _View.month);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Jump to a date',
            icon: const Icon(Icons.event),
            onPressed: _jumpToDate,
          ),
          IconButton(
            tooltip: 'Go to today',
            icon: const Icon(Icons.today),
            onPressed: () {
              if (_view == _View.month) {
                _goTo(today.year, today.month);
              } else {
                setState(() {
                  _year = today.year;
                  _month = today.month;
                });
                _pages.jumpToPage(_pageOf(today.year, today.month));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_View>(
                segments: const [
                  ButtonSegment(value: _View.month, label: Text('Month')),
                  ButtonSegment(value: _View.year, label: Text('Year')),
                  ButtonSegment(value: _View.agenda, label: Text('Agenda')),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
          const SizedBox(height: Gap.s),
          Expanded(child: _body()),
          const Padding(
            padding: EdgeInsets.fromLTRB(Gap.m, Gap.xs, Gap.m, Gap.m),
            child: Row(
              children: [
                Expanded(child: CalendarLegend()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_view) {
      case _View.month:
        return Column(
          children: [
            _MonthHeader(
              title: '${monthName(_month)} $_year',
              onPrev: () => _month == 1 ? _goTo(_year - 1, 12) : _goTo(_year, _month - 1),
              onNext: () => _month == 12 ? _goTo(_year + 1, 1) : _goTo(_year, _month + 1),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: (_lastYear - _firstYear + 1) * 12,
                onPageChanged: (page) => setState(() {
                  _year = _firstYear + page ~/ 12;
                  _month = page % 12 + 1;
                }),
                itemBuilder: (context, page) => _MonthGrid(
                  year: _firstYear + page ~/ 12,
                  month: page % 12 + 1,
                ),
              ),
            ),
          ],
        );
      case _View.year:
        return ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            _MonthHeader(
              title: '$_year',
              onPrev: () => _goTo(_year - 1, _month, animate: false),
              onNext: () => _goTo(_year + 1, _month, animate: false),
            ),
            const SizedBox(height: Gap.s),
            YearOverview(
              year: _year,
              onMonthTap: (m) {
                setState(() => _view = _View.month);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _goTo(_year, m, animate: false);
                });
              },
            ),
          ],
        );
      case _View.agenda:
        return _Agenda(year: _year);
    }
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.title,
    required this.onPrev,
    required this.onNext,
  });

  final String title;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        ),
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.year, required this.month});

  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(settingsProvider.select((s) => s.schedule));
    final holidays = ref.watch(holidaysByDateProvider);
    final leaves = ref.watch(leaveDayMapProvider);
    final today = ref.watch(todayProvider);

    final first = DateTime.utc(year, month, 1);
    final lead = first.weekday - 1;
    final count = daysInMonth(year, month);

    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var day = 1; day <= count; day++)
        _DayCell(
          date: DateTime.utc(year, month, day),
          holidays: holidays[DateTime.utc(year, month, day)] ?? const [],
          leaves: leaves[DateTime.utc(year, month, day)] ?? const [],
          isOff: !schedule.isWorkingDay(DateTime.utc(year, month, day)),
          isToday: DateTime.utc(year, month, day) == today,
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.s),
      child: Column(
        children: [
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayLetter(d),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: mutedColor(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.date,
    required this.holidays,
    required this.leaves,
    required this.isOff,
    required this.isToday,
  });

  final DateTime date;
  final List<Holiday> holidays;
  final List<LeaveEntry> leaves;
  final bool isOff;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color? color;
    final String marker;
    final String status;
    if (holidays.isNotEmpty) {
      color = AppColors.holiday;
      marker = 'H';
      status = 'Public holiday: ${holidays.map((h) => h.name).join(', ')}';
    } else if (leaves.isNotEmpty) {
      color = AppColors.leave;
      marker = 'L';
      status = 'Planned leave';
    } else if (isOff) {
      color = AppColors.weekend;
      marker = 'O';
      status = 'Weekend or day off';
    } else {
      color = null;
      marker = '';
      status = 'Working day';
    }
    final primary = Theme.of(context).colorScheme.primary;
    final textColor = color == null ? null : AppColors.textPrimary;

    return Semantics(
      button: true,
      label: '${weekdayName(date)} ${fmtDate(date)}, $status'
          '${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          showDaySheet(context, date);
        },
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: primary, width: 2.5) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (marker.isNotEmpty)
                Text(
                  marker,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Agenda extends ConsumerWidget {
  const _Agenda({required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider).valueOrNull ?? const <Holiday>[];
    final leaves = ref.watch(leaveDayMapProvider);

    final items = <(DateTime, String, String)>[];
    for (final h in holidays.where((h) => h.date.year == year)) {
      final tag = h.verification == VerificationStatus.verified ? '' : ' (tentative)';
      items.add((h.date, h.name, 'Holiday$tag'));
    }
    for (final entry in leaves.entries.where((e) => e.key.year == year)) {
      items.add((entry.key, entry.value.first.note.isEmpty ? 'Leave' : entry.value.first.note, 'Leave'));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'Nothing listed for this year',
        message: 'Holidays and planned leave will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Gap.m),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (date, title, kind) = items[i];
        final newMonth = i == 0 || items[i - 1].$1.month != date.month;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (newMonth) SectionHeader('${monthName(date.month)} ${date.year}'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => showDaySheet(context, date),
              leading: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kind.startsWith('Holiday') ? AppColors.holiday : AppColors.leave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              title: Text(title),
              subtitle: Text('${weekdayName(date)} - $kind'),
            ),
          ],
        );
      },
    );
  }
}
