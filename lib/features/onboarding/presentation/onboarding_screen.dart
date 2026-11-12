import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/constants/regions.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/features/calendar/domain/work_schedule.dart';
import 'package:leavewise/features/holidays/domain/holiday_filter.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _ScheduleChoice { monFri, monSat, custom }

const _leaveKinds = <(String, String)>[
  ('annual', 'Annual leave'),
  ('casual', 'Casual leave'),
  ('earned', 'Earned leave'),
  ('sick', 'Sick leave'),
  ('compoff', 'Compensatory offs'),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 7;

  int _step = 0;
  String _country = 'IN';
  String? _region;
  _ScheduleChoice _scheduleChoice = _ScheduleChoice.monFri;
  Set<int> _customDays = {1, 2, 3, 4, 5};
  HolidayPreferences _prefs = const HolidayPreferences();
  final Map<String, TextEditingController> _allocated = {
    for (final k in _leaveKinds) k.$1: TextEditingController(),
  };
  final Map<String, TextEditingController> _consumed = {
    for (final k in _leaveKinds) k.$1: TextEditingController(),
  };
  String? _leaveError;

  @override
  void dispose() {
    for (final c in [..._allocated.values, ..._consumed.values]) {
      c.dispose();
    }
    super.dispose();
  }

  WorkSchedule get _schedule {
    switch (_scheduleChoice) {
      case _ScheduleChoice.monFri:
        return WorkSchedule.mondayToFriday;
      case _ScheduleChoice.monSat:
        return WorkSchedule.mondayToSaturday;
      case _ScheduleChoice.custom:
        return WorkSchedule(_customDays);
    }
  }

  bool get _canContinue {
    if (_step == 3) return _schedule.isValid;
    return true;
  }

  double? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    final value = double.tryParse(trimmed);
    if (value == null || value < 0 || value > 366) return null;
    return value;
  }

  /// Validates the leave step and returns the types to save, or null when an
  /// input is invalid.
  List<LeaveType>? _collectLeaveTypes() {
    final types = <LeaveType>[];
    for (final kind in _leaveKinds) {
      final allocated = _parse(_allocated[kind.$1]!.text);
      final consumed = _parse(_consumed[kind.$1]!.text);
      if (allocated == null || consumed == null) {
        setState(() => _leaveError = 'Enter numbers between 0 and 366.');
        return null;
      }
      if (allocated > 0 || consumed > 0) {
        types.add(
          LeaveType(
            id: kind.$1,
            name: kind.$2,
            allocated: allocated,
            alreadyConsumed: consumed,
          ),
        );
      }
    }
    setState(() => _leaveError = null);
    return types;
  }

  Future<void> _finish({required bool saveLeaves}) async {
    List<LeaveType> types = const [];
    if (saveLeaves) {
      final collected = _collectLeaveTypes();
      if (collected == null) return;
      types = collected;
    }
    await ref.read(leaveTypesProvider.notifier).setAll(types);
    await ref.read(settingsProvider.notifier).update(
          (s) => s.copyWith(
            onboardingDone: true,
            countryCode: _country,
            regionCode: _region,
            clearRegion: _region == null,
            schedule: _schedule,
            holidayPrefs: _prefs,
          ),
        );
  }

  void _next() {
    if (_step == 5) {
      if (_collectLeaveTypes() == null) return;
    }
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _steps - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, 0),
              child: Semantics(
                label: 'Step ${_step + 1} of $_steps',
                child: LinearProgressIndicator(
                  value: (_step + 1) / _steps,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 6,
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _page(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step == 5)
                    TextButton(
                      onPressed: () => setState(() => _step++),
                      child: const Text('Skip'),
                    ),
                  const SizedBox(width: Gap.s),
                  FilledButton(
                    onPressed: !_canContinue
                        ? null
                        : isLast
                            ? () => _finish(saveLeaves: true)
                            : _next,
                    child: Text(
                      isLast
                          ? 'Start planning'
                          : _step == 0
                              ? 'Get started'
                              : 'Continue',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page() {
    switch (_step) {
      case 0:
        return _welcome();
      case 1:
        return _countryPage();
      case 2:
        return _regionPage();
      case 3:
        return _schedulePage();
      case 4:
        return _prefsPage();
      case 5:
        return _leavePage();
      default:
        return _finalPage();
    }
  }

  Widget _title(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: Gap.s),
        Text(subtitle, style: TextStyle(color: mutedColor(context))),
        const SizedBox(height: Gap.l),
      ],
    );
  }

  Widget _welcome() {
    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        const SizedBox(height: Gap.xl),
        Container(
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WelcomeDay(color: AppColors.weekend, text: 'S'),
              _WelcomeDay(color: AppColors.holiday, text: 'M'),
              _WelcomeDay(color: AppColors.leave, text: 'T'),
              _WelcomeDay(color: AppColors.leave, text: 'W'),
              _WelcomeDay(color: AppColors.weekend, text: 'S'),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        Semantics(
          header: true,
          child: Text(
            'Your holidays deserve better planning.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: Gap.m),
        Text(
          'Discover long weekends, maximize your leaves, and make every holiday count.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: mutedColor(context),
              ),
        ),
        const SizedBox(height: Gap.l),
        Text(
          'LeaveWise works on your device. No account needed.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _countryPage() {
    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        _title('Where do you work?', 'Pick your country to see its holidays.'),
        for (final entry in supportedCountries.entries)
          _ChoiceTile(
            label: entry.value,
            selected: _country == entry.key,
            onTap: () => setState(() {
              _country = entry.key;
              _region = null;
            }),
          ),
        if (!countriesWithHolidayData.contains(_country))
          Padding(
            padding: const EdgeInsets.only(top: Gap.m),
            child: Text(
              'Holiday data for ${supportedCountries[_country]} is not included yet. '
              'You can still add your own holidays in the calendar.',
              style: TextStyle(color: mutedColor(context)),
            ),
          ),
      ],
    );
  }

  Widget _regionPage() {
    if (_country != 'IN') {
      return ListView(
        padding: const EdgeInsets.all(Gap.l),
        children: [
          _title(
            'State or region',
            'Regions are only available for India right now. Tap Continue.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        _title('Which state or union territory?', 'State holidays follow this choice.'),
        _ChoiceTile(
          label: 'Not sure or skip',
          selected: _region == null,
          onTap: () => setState(() => _region = null),
        ),
        for (final entry in indiaRegions.entries)
          _ChoiceTile(
            label: entry.value,
            selected: _region == entry.key,
            onTap: () => setState(() => _region = entry.key),
          ),
      ],
    );
  }

  Widget _schedulePage() {
    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        _title(
          'Your work schedule',
          'Days you do not work count as days off in every calculation.',
        ),
        _ChoiceTile(
          label: 'Monday to Friday',
          selected: _scheduleChoice == _ScheduleChoice.monFri,
          onTap: () => setState(() => _scheduleChoice = _ScheduleChoice.monFri),
        ),
        _ChoiceTile(
          label: 'Monday to Saturday',
          selected: _scheduleChoice == _ScheduleChoice.monSat,
          onTap: () => setState(() => _scheduleChoice = _ScheduleChoice.monSat),
        ),
        _ChoiceTile(
          label: 'Custom working days',
          selected: _scheduleChoice == _ScheduleChoice.custom,
          onTap: () => setState(() => _scheduleChoice = _ScheduleChoice.custom),
        ),
        if (_scheduleChoice == _ScheduleChoice.custom) ...[
          const SizedBox(height: Gap.m),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
                  ),
                  selected: _customDays.contains(day),
                  onSelected: (on) => setState(() {
                    final next = {..._customDays};
                    on ? next.add(day) : next.remove(day);
                    _customDays = next;
                  }),
                ),
            ],
          ),
          if (_customDays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: Text(
                'Choose at least one working day.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ],
    );
  }

  Widget _prefsPage() {
    Widget sw(String title, String sub, bool value, void Function(bool) onChanged) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(sub),
        value: value,
        onChanged: (v) => setState(() => onChanged(v)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        _title('Which holidays count?', 'You can change this any time in Settings.'),
        sw('National holidays', 'Centrally gazetted holidays', _prefs.includeNational,
            (v) => _prefs = _copyPrefs(national: v)),
        sw('State holidays', 'For your selected region', _prefs.includeRegional,
            (v) => _prefs = _copyPrefs(regional: v)),
        sw('Religious holidays', 'Festival holidays outside the gazetted list',
            _prefs.includeReligious, (v) => _prefs = _copyPrefs(religious: v)),
        sw('Company holidays', 'The ones you add yourself', _prefs.includeCompany,
            (v) => _prefs = _copyPrefs(company: v)),
        sw('Optional holidays', 'Restricted holidays you may choose to take',
            _prefs.includeOptional, (v) => _prefs = _copyPrefs(optional: v)),
      ],
    );
  }

  HolidayPreferences _copyPrefs({
    bool? national,
    bool? regional,
    bool? religious,
    bool? company,
    bool? optional,
  }) {
    return HolidayPreferences(
      includeNational: national ?? _prefs.includeNational,
      includeRegional: regional ?? _prefs.includeRegional,
      includeReligious: religious ?? _prefs.includeReligious,
      includeCompany: company ?? _prefs.includeCompany,
      includeCustom: _prefs.includeCustom,
      includeOptional: optional ?? _prefs.includeOptional,
    );
  }

  Widget _leavePage() {
    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        _title(
          'Your leave entitlement',
          'Optional. Leave a row empty if it does not apply, or skip this step. '
              'It is only used to keep suggestions within what you have left.',
        ),
        for (final kind in _leaveKinds)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.m),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(kind.$2, style: Theme.of(context).textTheme.bodyLarge),
                ),
                const SizedBox(width: Gap.s),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _allocated[kind.$1],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Per year'),
                  ),
                ),
                const SizedBox(width: Gap.s),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _consumed[kind.$1],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Used'),
                  ),
                ),
              ],
            ),
          ),
        if (_leaveError != null)
          Text(
            _leaveError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _finalPage() {
    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        _title('You are all set', 'Here is what LeaveWise will and will not do.'),
        const _InfoRow(
          icon: Icons.phone_android,
          text: 'Everything stays on this device. There is no account and no cloud.',
        ),
        const _InfoRow(
          icon: Icons.notifications_off_outlined,
          text:
              'LeaveWise asks for no permissions today. If reminders are added, '
              'notification permission will be requested only when you turn them on.',
        ),
        const _InfoRow(
          icon: Icons.verified_outlined,
          text:
              'Dates marked tentative depend on moon sighting or government '
              'announcements. Confirm them with your employer.',
        ),
      ],
    );
  }
}

class _WelcomeDay extends StatelessWidget {
  const _WelcomeDay({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: Gap.m),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (selected) Icon(Icons.check_circle, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: Gap.m),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
