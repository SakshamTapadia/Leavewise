import 'package:leavewise/features/calendar/domain/work_schedule.dart';
import 'package:leavewise/features/holidays/domain/holiday_filter.dart';

enum ThemeChoice { system, light, dark }

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

WorkSchedule _scheduleOf(Object? raw) {
  if (raw is List) {
    try {
      return WorkSchedule.fromJson(raw);
    } on Object {
      return WorkSchedule.mondayToFriday;
    }
  }
  return WorkSchedule.mondayToFriday;
}

class AppSettings {
  const AppSettings({
    this.onboardingDone = false,
    this.countryCode = 'IN',
    this.regionCode,
    this.schedule = WorkSchedule.mondayToFriday,
    this.holidayPrefs = const HolidayPreferences(),
    this.theme = ThemeChoice.system,
    this.planningLeaves = 5,
  });

  final bool onboardingDone;
  final String countryCode;
  final String? regionCode;
  final WorkSchedule schedule;
  final HolidayPreferences holidayPrefs;
  final ThemeChoice theme;

  /// Default leave budget used for dashboard recommendations.
  final int planningLeaves;

  AppSettings copyWith({
    bool? onboardingDone,
    String? countryCode,
    String? regionCode,
    bool clearRegion = false,
    WorkSchedule? schedule,
    HolidayPreferences? holidayPrefs,
    ThemeChoice? theme,
    int? planningLeaves,
  }) {
    return AppSettings(
      onboardingDone: onboardingDone ?? this.onboardingDone,
      countryCode: countryCode ?? this.countryCode,
      regionCode: clearRegion ? null : (regionCode ?? this.regionCode),
      schedule: schedule ?? this.schedule,
      holidayPrefs: holidayPrefs ?? this.holidayPrefs,
      theme: theme ?? this.theme,
      planningLeaves: planningLeaves ?? this.planningLeaves,
    );
  }

  Map<String, dynamic> toJson() => {
        'onboardingDone': onboardingDone,
        'country': countryCode,
        if (regionCode != null) 'region': regionCode,
        'workDays': schedule.toJson(),
        'prefs': {
          'national': holidayPrefs.includeNational,
          'regional': holidayPrefs.includeRegional,
          'religious': holidayPrefs.includeReligious,
          'company': holidayPrefs.includeCompany,
          'custom': holidayPrefs.includeCustom,
          'optional': holidayPrefs.includeOptional,
        },
        'theme': theme.name,
        'planningLeaves': planningLeaves,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final prefsRaw = json['prefs'];
    final prefs = prefsRaw is Map<String, dynamic> ? prefsRaw : const <String, dynamic>{};
    final theme = ThemeChoice.values.where((t) => t.name == json['theme']);
    final leaves = json['planningLeaves'];
    final country = json['country'];
    final region = json['region'];
    return AppSettings(
      onboardingDone: _bool(json['onboardingDone'], false),
      countryCode: country is String && country.isNotEmpty ? country : 'IN',
      regionCode: region is String && region.isNotEmpty ? region : null,
      schedule: _scheduleOf(json['workDays']),
      holidayPrefs: HolidayPreferences(
        includeNational: _bool(prefs['national'], true),
        includeRegional: _bool(prefs['regional'], true),
        includeReligious: _bool(prefs['religious'], true),
        includeCompany: _bool(prefs['company'], true),
        includeCustom: _bool(prefs['custom'], true),
        includeOptional: _bool(prefs['optional'], false),
      ),
      theme: theme.isEmpty ? ThemeChoice.system : theme.first,
      planningLeaves: leaves is int && leaves >= 1 && leaves <= 60 ? leaves : 5,
    );
  }
}
