import 'package:leavewise/features/holidays/domain/holiday.dart';

/// Which kinds of holidays the user wants counted.
class HolidayPreferences {
  const HolidayPreferences({
    this.includeNational = true,
    this.includeRegional = true,
    this.includeReligious = true,
    this.includeCompany = true,
    this.includeCustom = true,
    this.includeOptional = false,
  });

  final bool includeNational;
  final bool includeRegional;
  final bool includeReligious;
  final bool includeCompany;
  final bool includeCustom;

  /// Optional (restricted) holidays are counted only when this is true.
  final bool includeOptional;

  bool includesCategory(HolidayCategory category) {
    switch (category) {
      case HolidayCategory.national:
        return includeNational;
      case HolidayCategory.regional:
        return includeRegional;
      case HolidayCategory.religious:
        return includeReligious;
      case HolidayCategory.company:
        return includeCompany;
      case HolidayCategory.custom:
        return includeCustom;
    }
  }
}

/// Returns the holidays that apply to a user in [countryCode] / [regionCode]
/// under [prefs]. Region-specific holidays match only their own region.
List<Holiday> filterHolidays(
  Iterable<Holiday> all, {
  required String countryCode,
  String? regionCode,
  HolidayPreferences prefs = const HolidayPreferences(),
}) {
  final country = countryCode.toUpperCase();
  final region = regionCode?.toUpperCase();
  return all.where((h) {
    if (h.countryCode != country) return false;
    if (h.regionCode != null && h.regionCode != region) return false;
    if (h.isOptional && !prefs.includeOptional) return false;
    return prefs.includesCategory(h.category);
  }).toList();
}
