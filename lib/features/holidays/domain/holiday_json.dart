import 'dart:convert';

import 'package:leavewise/features/holidays/domain/holiday.dart';

const int holidayDatasetSchemaVersion = 1;

/// Serialises holidays to the portable dataset format used for import,
/// export and remote dataset updates.
String exportHolidaysJson(Iterable<Holiday> holidays) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert({
    'schemaVersion': holidayDatasetSchemaVersion,
    'holidays': holidays.map((h) => h.toJson()).toList(),
  });
}

/// Parses and validates a dataset. Throws [FormatException] when the document
/// is malformed, has an unsupported schema version, or repeats an id.
List<Holiday> importHolidaysJson(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    throw FormatException('Not valid JSON: ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Dataset must be a JSON object');
  }
  if (decoded['schemaVersion'] != holidayDatasetSchemaVersion) {
    throw FormatException(
      'Unsupported schemaVersion: ${decoded['schemaVersion']}',
    );
  }
  final list = decoded['holidays'];
  if (list is! List) {
    throw const FormatException('"holidays" must be a list');
  }
  final seen = <String>{};
  final result = <Holiday>[];
  for (final item in list) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Every holiday must be a JSON object');
    }
    final holiday = Holiday.fromJson(item);
    if (!seen.add(holiday.id)) {
      throw FormatException('Duplicate holiday id: ${holiday.id}');
    }
    result.add(holiday);
  }
  return result;
}
