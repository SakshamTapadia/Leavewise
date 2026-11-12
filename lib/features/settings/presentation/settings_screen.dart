import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/core/constants/regions.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/features/calendar/domain/work_schedule.dart';
import 'package:leavewise/features/holidays/domain/holiday_filter.dart';
import 'package:leavewise/features/leave_balance/data/leave_json.dart';
import 'package:leavewise/features/settings/domain/app_settings.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final prefs = s.holidayPrefs;

    Widget sw(String title, bool value, HolidayPreferences Function(bool) change) {
      return SwitchListTile.adaptive(
        title: Text(title),
        value: value,
        onChanged: (v) => notifier.update((cur) => cur.copyWith(holidayPrefs: change(v))),
      );
    }

    HolidayPreferences copy({
      bool? national,
      bool? regional,
      bool? religious,
      bool? company,
      bool? custom,
      bool? optional,
    }) {
      return HolidayPreferences(
        includeNational: national ?? prefs.includeNational,
        includeRegional: regional ?? prefs.includeRegional,
        includeReligious: religious ?? prefs.includeReligious,
        includeCompany: company ?? prefs.includeCompany,
        includeCustom: custom ?? prefs.includeCustom,
        includeOptional: optional ?? prefs.includeOptional,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          const _Group('Location'),
          ListTile(
            title: const Text('Country'),
            subtitle: Text(supportedCountries[s.countryCode] ?? s.countryCode),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickCountry(context, ref),
          ),
          if (s.countryCode == 'IN')
            ListTile(
              title: const Text('State or union territory'),
              subtitle: Text(indiaRegions[s.regionCode] ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickRegion(context, ref),
            ),
          if (!countriesWithHolidayData.contains(s.countryCode))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.m),
              child: Text(
                'Holiday data for this country is not included yet. Add your own '
                'holidays from the calendar.',
                style: TextStyle(color: mutedColor(context)),
              ),
            ),
          const _Group('Work schedule'),
          ListTile(
            title: const Text('Working days'),
            subtitle: Text(_scheduleLabel(s.schedule)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickSchedule(context, ref),
          ),
          const _Group('Holidays to include'),
          sw('National', prefs.includeNational, (v) => copy(national: v)),
          sw('State or regional', prefs.includeRegional, (v) => copy(regional: v)),
          sw('Religious', prefs.includeReligious, (v) => copy(religious: v)),
          sw('Company', prefs.includeCompany, (v) => copy(company: v)),
          sw('Personal', prefs.includeCustom, (v) => copy(custom: v)),
          sw('Optional', prefs.includeOptional, (v) => copy(optional: v)),
          const _Group('Planning'),
          ListTile(
            title: const Text('Default leave budget'),
            subtitle: Text('${s.planningLeaves} leave days per break on the home screen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickBudget(context, ref),
          ),
          const _Group('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            child: SegmentedButton<ThemeChoice>(
              segments: const [
                ButtonSegment(value: ThemeChoice.system, label: Text('System')),
                ButtonSegment(value: ThemeChoice.light, label: Text('Light')),
                ButtonSegment(value: ThemeChoice.dark, label: Text('Dark')),
              ],
              selected: {s.theme},
              onSelectionChanged: (c) =>
                  notifier.update((cur) => cur.copyWith(theme: c.first)),
            ),
          ),
          const _Group('Your data'),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export my data'),
            subtitle: const Text('Share a JSON backup of your settings, leave and plans'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
            title: const Text('Delete all my data'),
            subtitle: const Text('Clears everything stored on this device'),
            onTap: () => _confirmDelete(context, ref),
          ),
          const _Group('About'),
          ListTile(
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            title: const Text('Terms of service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/terms'),
          ),
          ListTile(
            title: const Text('About LeaveWise'),
            subtitle: const Text('Version $appVersion'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }

  String _scheduleLabel(WorkSchedule schedule) {
    if (schedule == WorkSchedule.mondayToFriday) return 'Monday to Friday';
    if (schedule == WorkSchedule.mondayToSaturday) return 'Monday to Saturday';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return schedule.toJson().map((d) => names[d - 1]).join(', ');
  }

  Future<void> _pickCountry(BuildContext context, WidgetRef ref) async {
    final code = await _chooser<String>(
      context,
      title: 'Country',
      options: supportedCountries,
      selected: ref.read(settingsProvider).countryCode,
    );
    if (code == null) return;
    await ref.read(settingsProvider.notifier).update(
          (s) => s.copyWith(countryCode: code, clearRegion: code != s.countryCode),
        );
  }

  Future<void> _pickRegion(BuildContext context, WidgetRef ref) async {
    final code = await _chooser<String>(
      context,
      title: 'State or union territory',
      options: {'': 'Not set', ...indiaRegions},
      selected: ref.read(settingsProvider).regionCode ?? '',
    );
    if (code == null) return;
    await ref.read(settingsProvider.notifier).update(
          (s) => code.isEmpty ? s.copyWith(clearRegion: true) : s.copyWith(regionCode: code),
        );
  }

  Future<void> _pickBudget(BuildContext context, WidgetRef ref) async {
    final value = await _chooser<int>(
      context,
      title: 'Default leave budget',
      options: {for (final n in [1, 2, 3, 5, 7, 10]) n: '$n leave days'},
      selected: ref.read(settingsProvider).planningLeaves,
    );
    if (value == null) return;
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(planningLeaves: value));
  }

  Future<void> _pickSchedule(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<WorkSchedule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleSheet(initial: ref.read(settingsProvider).schedule),
    );
    if (result == null) return;
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(schedule: result));
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final data = {
      'app': 'LeaveWise',
      'version': appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': ref.read(settingsProvider).toJson(),
      'leaveTypes': ref.read(leaveTypesProvider).map(leaveTypeToJson).toList(),
      'leaveEntries': ref.read(leaveEntriesProvider).map(leaveEntryToJson).toList(),
      'customHolidays': ref.read(customHolidaysProvider).map((h) => h.toJson()).toList(),
      'plans': ref.read(plansProvider).map((p) => p.toJson()).toList(),
    };
    await Share.share(
      const JsonEncoder.withIndent('  ').convert(data),
      subject: 'LeaveWise data export',
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete all data?'),
        content: const Text(
          'This removes your settings, leave, plans and custom holidays from this '
          'device and cannot be undone. Export a backup first if you want one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(storeProvider).clearAll();
    ref.invalidate(settingsProvider);
    ref.invalidate(leaveTypesProvider);
    ref.invalidate(leaveEntriesProvider);
    ref.invalidate(customHolidaysProvider);
    ref.invalidate(plansProvider);
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.m, Gap.l, Gap.m, Gap.xs),
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
    );
  }
}

Future<T?> _chooser<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final entry in options.entries)
              ListTile(
                title: Text(entry.value),
                selected: entry.key == selected,
                trailing: entry.key == selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initial});

  final WorkSchedule initial;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late Set<int> _days = {...widget.initial.workingWeekdays};

  @override
  Widget build(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Working days', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Gap.s),
            Wrap(
              spacing: Gap.s,
              children: [
                ActionChip(
                  label: const Text('Mon to Fri'),
                  onPressed: () => setState(() => _days = {1, 2, 3, 4, 5}),
                ),
                ActionChip(
                  label: const Text('Mon to Sat'),
                  onPressed: () => setState(() => _days = {1, 2, 3, 4, 5, 6}),
                ),
              ],
            ),
            const SizedBox(height: Gap.s),
            Wrap(
              spacing: Gap.s,
              runSpacing: Gap.s,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(names[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (on) => setState(() {
                      final next = {..._days};
                      on ? next.add(d) : next.remove(d);
                      _days = next;
                    }),
                  ),
              ],
            ),
            if (_days.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Gap.s),
                child: Text(
                  'Choose at least one working day.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: Gap.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _days.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(WorkSchedule(_days)),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
