import 'package:leavewise/core/utils/date_utils.dart';

enum HolidayCategory { national, regional, religious, company, custom }

/// How certain we are about a date. Lunar or announcement-dependent holidays
/// stay [tentative] until confirmed by an official source.
enum VerificationStatus { verified, tentative, unverified }

enum HolidayRecurrence { none, yearlyFixedDate, lunar, ruleBased }

T _parseEnum<T extends Enum>(List<T> values, Object? raw, String field) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Invalid $field: $raw');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or empty "$key"');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('"$key" must be a string');
  return value.isEmpty ? null : value;
}

class Holiday {
  Holiday({
    required this.id,
    required this.name,
    required DateTime date,
    required this.countryCode,
    this.regionCode,
    required this.category,
    this.description = '',
    this.source = '',
    this.verification = VerificationStatus.unverified,
    this.isOptional = false,
    this.recurrence = HolidayRecurrence.none,
    this.ruleId,
  }) : date = dateOnly(date);

  final String id;
  final String name;
  final DateTime date;

  /// ISO 3166-1 alpha-2 code, for example IN.
  final String countryCode;

  /// ISO 3166-2 subdivision code without the country prefix, for example KA.
  /// Null means the holiday applies to the whole country.
  final String? regionCode;
  final HolidayCategory category;
  final String description;
  final String source;
  final VerificationStatus verification;
  final bool isOptional;
  final HolidayRecurrence recurrence;

  /// Id of the [HolidayRule] this record belongs to. A dataset record with a
  /// ruleId replaces the computed holiday from that rule for the same year.
  final String? ruleId;

  Holiday copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? countryCode,
    String? regionCode,
    HolidayCategory? category,
    String? description,
    String? source,
    VerificationStatus? verification,
    bool? isOptional,
    HolidayRecurrence? recurrence,
    String? ruleId,
  }) {
    return Holiday(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      countryCode: countryCode ?? this.countryCode,
      regionCode: regionCode ?? this.regionCode,
      category: category ?? this.category,
      description: description ?? this.description,
      source: source ?? this.source,
      verification: verification ?? this.verification,
      isOptional: isOptional ?? this.isOptional,
      recurrence: recurrence ?? this.recurrence,
      ruleId: ruleId ?? this.ruleId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': formatDateKey(date),
        'country': countryCode,
        if (regionCode != null) 'region': regionCode,
        'category': category.name,
        'description': description,
        'source': source,
        'verification': verification.name,
        'optional': isOptional,
        'recurrence': recurrence.name,
        if (ruleId != null) 'ruleId': ruleId,
      };

  /// Throws [FormatException] for malformed records.
  factory Holiday.fromJson(Map<String, dynamic> json) {
    final optional = json['optional'];
    if (optional != null && optional is! bool) {
      throw const FormatException('"optional" must be a boolean');
    }
    return Holiday(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      date: parseDateKey(_requiredString(json, 'date')),
      countryCode: _requiredString(json, 'country').toUpperCase(),
      regionCode: _optionalString(json, 'region')?.toUpperCase(),
      category: _parseEnum(HolidayCategory.values, json['category'], 'category'),
      description: _optionalString(json, 'description') ?? '',
      source: _optionalString(json, 'source') ?? '',
      verification: json['verification'] == null
          ? VerificationStatus.unverified
          : _parseEnum(
              VerificationStatus.values,
              json['verification'],
              'verification',
            ),
      isOptional: (optional as bool?) ?? false,
      ruleId: _optionalString(json, 'ruleId'),
      recurrence: json['recurrence'] == null
          ? HolidayRecurrence.none
          : _parseEnum(
              HolidayRecurrence.values,
              json['recurrence'],
              'recurrence',
            ),
    );
  }
}
