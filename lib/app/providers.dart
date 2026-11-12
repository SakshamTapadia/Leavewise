import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leavewise/core/storage/app_store.dart';
import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/calendar/domain/work_schedule.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/holidays/domain/holiday_filter.dart';
import 'package:leavewise/features/holidays/domain/holiday_json.dart';
import 'package:leavewise/features/holidays/domain/holiday_rules.dart';
import 'package:leavewise/features/holidays/domain/india_rules.dart';
import 'package:leavewise/features/leave_balance/data/leave_json.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';
import 'package:leavewise/features/leave_optimizer/domain/leave_optimizer.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';
import 'package:leavewise/features/settings/domain/app_settings.dart';
import 'package:leavewise/features/vacation_plans/domain/saved_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- storage

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPrefsProvider in main()'),
);

final storeProvider = Provider<AppStore>(
  (ref) => AppStore(ref.watch(sharedPrefsProvider)),
);

/// Today's date. Overridable in tests.
final todayProvider = Provider<DateTime>((ref) => dateOnly(DateTime.now()));

// --------------------------------------------------------------- settings

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final raw = ref.read(storeProvider).read(StoreKeys.settings);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
    } on FormatException {
      return const AppSettings();
    }
    return const AppSettings();
  }

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    state = change(state);
    await ref
        .read(storeProvider)
        .write(StoreKeys.settings, jsonEncode(state.toJson()));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ------------------------------------------------------- generic JSON list

abstract class JsonListNotifier<T> extends Notifier<List<T>> {
  String get storeKey;
  T decode(Map<String, dynamic> json);
  Map<String, dynamic> encode(T item);

  @override
  List<T> build() {
    final raw = ref.read(storeProvider).read(storeKey);
    if (raw == null) return <T>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return <T>[];
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) decode(item),
      ];
    } on Object {
      return <T>[];
    }
  }

  Future<void> setAll(List<T> items) async {
    state = List<T>.unmodifiable(items);
    await ref
        .read(storeProvider)
        .write(storeKey, jsonEncode(state.map(encode).toList()));
  }
}

// ------------------------------------------------------------ leave types

class LeaveTypesNotifier extends JsonListNotifier<LeaveType> {
  @override
  String get storeKey => StoreKeys.leaveTypes;
  @override
  LeaveType decode(Map<String, dynamic> json) => leaveTypeFromJson(json);
  @override
  Map<String, dynamic> encode(LeaveType item) => leaveTypeToJson(item);

  Future<void> upsert(LeaveType type) {
    final next = [...state];
    final i = next.indexWhere((t) => t.id == type.id);
    if (i >= 0) {
      next[i] = type;
    } else {
      next.add(type);
    }
    return setAll(next);
  }

  Future<void> remove(String id) => setAll(state.where((t) => t.id != id).toList());
}

final leaveTypesProvider =
    NotifierProvider<LeaveTypesNotifier, List<LeaveType>>(LeaveTypesNotifier.new);

const LeaveType generalLeaveType =
    LeaveType(id: 'general', name: 'Leave', allocated: 0);

/// The configured types, or one generic type when the user skipped setup.
final effectiveLeaveTypesProvider = Provider<List<LeaveType>>((ref) {
  final types = ref.watch(leaveTypesProvider);
  return types.isEmpty ? const [generalLeaveType] : types;
});

/// True when the user entered a real entitlement.
final hasEntitlementProvider = Provider<bool>(
  (ref) => ref.watch(leaveTypesProvider).any((t) => t.allocated > 0),
);

// ---------------------------------------------------------- leave entries

class LeaveEntriesNotifier extends JsonListNotifier<LeaveEntry> {
  @override
  String get storeKey => StoreKeys.leaveEntries;
  @override
  LeaveEntry decode(Map<String, dynamic> json) => leaveEntryFromJson(json);
  @override
  Map<String, dynamic> encode(LeaveEntry item) => leaveEntryToJson(item);

  Future<void> add(LeaveEntry entry) => setAll([...state, entry]);

  Future<void> replace(LeaveEntry entry) =>
      setAll([for (final e in state) e.id == entry.id ? entry : e]);

  Future<void> remove(String id) => setAll(state.where((e) => e.id != id).toList());

  Future<void> replaceForPlan(String planId, List<LeaveEntry> entries) =>
      setAll([...state.where((e) => e.planId != planId), ...entries]);

  Future<void> removeForPlan(String planId) =>
      setAll(state.where((e) => e.planId != planId).toList());

  /// Takes one calendar day out of any active leave that covers it, splitting
  /// a longer leave in two when the day is in the middle.
  Future<void> removeDate(
    DateTime date,
    WorkSchedule schedule,
    Set<DateTime> holidayDates,
  ) {
    double days(DateTime a, DateTime b) => chargeableDays(
          start: a,
          end: b,
          schedule: schedule,
          holidayDates: holidayDates,
        );
    final next = <LeaveEntry>[];
    for (final e in state) {
      final covers = activeLeaveStatuses.contains(e.status) &&
          !date.isBefore(e.start) &&
          !date.isAfter(e.end);
      if (!covers) {
        next.add(e);
        continue;
      }
      if (e.start == e.end) continue;
      if (date == e.start) {
        final s = addDays(e.start, 1);
        next.add(e.copyWith(start: s, days: days(s, e.end)));
      } else if (date == e.end) {
        final t = addDays(e.end, -1);
        next.add(e.copyWith(end: t, days: days(e.start, t)));
      } else {
        final leftEnd = addDays(date, -1);
        final rightStart = addDays(date, 1);
        next.add(
          e.copyWith(
            id: '${e.id}-a',
            end: leftEnd,
            days: days(e.start, leftEnd),
          ),
        );
        next.add(
          e.copyWith(
            id: '${e.id}-b',
            start: rightStart,
            days: days(rightStart, e.end),
          ),
        );
      }
    }
    return setAll(next);
  }
}

final leaveEntriesProvider =
    NotifierProvider<LeaveEntriesNotifier, List<LeaveEntry>>(
  LeaveEntriesNotifier.new,
);

/// Entries whose type no longer exists are shown under the first type.
final normalizedEntriesProvider = Provider<List<LeaveEntry>>((ref) {
  final types = ref.watch(effectiveLeaveTypesProvider);
  final ids = types.map((t) => t.id).toSet();
  return [
    for (final e in ref.watch(leaveEntriesProvider))
      ids.contains(e.typeId) ? e : e.copyWith(typeId: types.first.id),
  ];
});

final balancesProvider = Provider<List<LeaveBalanceSummary>>((ref) {
  return computeBalances(
    types: ref.watch(effectiveLeaveTypesProvider),
    entries: ref.watch(normalizedEntriesProvider),
  );
});

/// Whole leave days left across all types, or null when no entitlement was set
/// (the optimizer then treats the balance as unlimited).
final availableBalanceProvider = Provider<int?>((ref) {
  if (!ref.watch(hasEntitlementProvider)) return null;
  final remaining = ref
      .watch(balancesProvider)
      .fold<double>(0, (sum, b) => sum + b.remaining);
  return remaining <= 0 ? 0 : remaining.floor();
});

// -------------------------------------------------------- custom holidays

class CustomHolidaysNotifier extends JsonListNotifier<Holiday> {
  @override
  String get storeKey => StoreKeys.customHolidays;
  @override
  Holiday decode(Map<String, dynamic> json) => Holiday.fromJson(json);
  @override
  Map<String, dynamic> encode(Holiday item) => item.toJson();

  Future<void> add(Holiday h) => setAll([...state, h]);
  Future<void> replace(Holiday h) =>
      setAll([for (final x in state) x.id == h.id ? h : x]);
  Future<void> remove(String id) => setAll(state.where((h) => h.id != id).toList());
}

final customHolidaysProvider =
    NotifierProvider<CustomHolidaysNotifier, List<Holiday>>(
  CustomHolidaysNotifier.new,
);

bool isUserHoliday(Holiday h) => h.id.startsWith('custom-');

// ----------------------------------------------------------- saved plans

class PlansNotifier extends JsonListNotifier<SavedPlan> {
  @override
  String get storeKey => StoreKeys.plans;
  @override
  SavedPlan decode(Map<String, dynamic> json) => SavedPlan.fromJson(json);
  @override
  Map<String, dynamic> encode(SavedPlan item) => item.toJson();

  Future<void> add(SavedPlan p) => setAll([p, ...state]);

  /// Saves [plan] and keeps its linked leave entries in step. A plan that is
  /// only suggested creates no entries, so saving a recommendation never
  /// touches any balance.
  Future<void> save(SavedPlan plan) async {
    final exists = state.any((p) => p.id == plan.id);
    await setAll(
      exists ? [for (final p in state) p.id == plan.id ? plan : p] : [plan, ...state],
    );
    final entries = ref.read(leaveEntriesProvider.notifier);
    if (plan.status == LeaveStatus.suggested) {
      await entries.removeForPlan(plan.id);
    } else {
      final typeId = ref.read(effectiveLeaveTypesProvider).first.id;
      await entries.replaceForPlan(plan.id, leaveEntriesForPlan(plan, typeId));
    }
  }

  Future<void> delete(String id) async {
    await setAll(state.where((p) => p.id != id).toList());
    await ref.read(leaveEntriesProvider.notifier).removeForPlan(id);
  }
}

final plansProvider =
    NotifierProvider<PlansNotifier, List<SavedPlan>>(PlansNotifier.new);

// ---------------------------------------------------------------- holidays

/// Every holiday dataset bundled in assets/data/holidays.
final holidayDatasetProvider = FutureProvider<List<Holiday>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((p) => p.startsWith('assets/data/holidays/') && p.endsWith('.json'));
  final result = <Holiday>[];
  for (final path in paths) {
    try {
      result.addAll(importHolidaysJson(await rootBundle.loadString(path)));
    } on FormatException {
      continue;
    }
  }
  return result;
});

/// Holidays that apply to the user, already filtered by their preferences.
final holidaysProvider = Provider<AsyncValue<List<Holiday>>>((ref) {
  final dataset = ref.watch(holidayDatasetProvider);
  final settings = ref.watch(settingsProvider);
  final custom = ref.watch(customHolidaysProvider);
  final today = ref.watch(todayProvider);
  return dataset.whenData((records) {
    final rules =
        settings.countryCode == 'IN' ? indiaNationalRules : <HolidayRule>[];
    final resolved = resolveHolidaysForRange(
      firstYear: today.year - 1,
      lastYear: today.year + 3,
      countryCode: settings.countryCode,
      regionCode: settings.regionCode,
      rules: rules,
      records: records,
    );
    final filtered = filterHolidays(
      [...resolved, ...custom],
      countryCode: settings.countryCode,
      regionCode: settings.regionCode,
      prefs: settings.holidayPrefs,
    );
    filtered.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.name.compareTo(b.name);
    });
    return filtered;
  });
});

final holidaysByDateProvider = Provider<Map<DateTime, List<Holiday>>>((ref) {
  final map = <DateTime, List<Holiday>>{};
  for (final h in ref.watch(holidaysProvider).valueOrNull ?? const <Holiday>[]) {
    map.putIfAbsent(h.date, () => []).add(h);
  }
  return map;
});

/// Working days covered by active leave, with the entries that cover them.
final leaveDayMapProvider = Provider<Map<DateTime, List<LeaveEntry>>>((ref) {
  final schedule = ref.watch(settingsProvider).schedule;
  final holidays = ref.watch(holidaysByDateProvider);
  final map = <DateTime, List<LeaveEntry>>{};
  for (final e in ref.watch(normalizedEntriesProvider)) {
    if (!activeLeaveStatuses.contains(e.status)) continue;
    for (final day in eachDay(e.start, e.end)) {
      if (schedule.isWorkingDay(day) && !holidays.containsKey(day)) {
        map.putIfAbsent(day, () => []).add(e);
      }
    }
  }
  return map;
});

// --------------------------------------------------------------- optimizer

typedef RecArgs = ({
  int budget,
  int minDays,
  int horizonMonths,
  RecommendationSort sort,
  bool allowOverlap,
  int limit,
});

final optimizerInputProvider =
    Provider.family<OptimizerInput?, ({int budget, int minDays, int horizonMonths})>(
  (ref, args) {
    final holidays = ref.watch(holidaysProvider).valueOrNull;
    if (holidays == null) return null;
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayProvider);
    return OptimizerInput(
      horizonStart: today,
      horizonEnd: addDays(addMonths(today, args.horizonMonths), -1),
      schedule: settings.schedule,
      holidays: holidays,
      existingLeaveDays: ref.watch(leaveDayMapProvider).keys,
      leaveBudget: args.budget,
      availableBalance: ref.watch(availableBalanceProvider),
      minimumDaysOff: args.minDays,
    );
  },
);

final recommendationsProvider =
    Provider.family<List<LeaveRecommendation>?, RecArgs>((ref, args) {
  final input = ref.watch(
    optimizerInputProvider(
      (budget: args.budget, minDays: args.minDays, horizonMonths: args.horizonMonths),
    ),
  );
  if (input == null) return null;
  return const LeaveOptimizer().recommend(
    input,
    sort: args.sort,
    limit: args.limit,
    allowOverlap: args.allowOverlap,
  );
});

final freeStretchesProvider = Provider<List<FreeStretch>?>((ref) {
  final input = ref.watch(
    optimizerInputProvider((budget: 1, minDays: 3, horizonMonths: 12)),
  );
  if (input == null) return null;
  return const LeaveOptimizer().freeStretches(input);
});
