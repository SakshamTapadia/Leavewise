import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/holidays/domain/holiday_filter.dart';
import 'package:leavewise/features/holidays/domain/holiday_json.dart';

Holiday make(
  String id, {
  DateTime? date,
  String country = 'IN',
  String? region,
  HolidayCategory category = HolidayCategory.national,
  bool optional = false,
}) {
  return Holiday(
    id: id,
    name: id,
    date: date ?? DateTime.utc(2027, 1, 26),
    countryCode: country,
    regionCode: region,
    category: category,
    isOptional: optional,
  );
}

void main() {
  group('JSON import and export', () {
    test('round trips every field', () {
      final original = [
        Holiday(
          id: 'in-2027-republic-day',
          name: 'Republic Day',
          date: DateTime.utc(2027, 1, 26),
          countryCode: 'IN',
          category: HolidayCategory.national,
          description: 'National holiday',
          source: 'Test source',
          verification: VerificationStatus.verified,
          recurrence: HolidayRecurrence.yearlyFixedDate,
        ),
        Holiday(
          id: 'in-ka-2027-x',
          name: 'Regional example',
          date: DateTime.utc(2027, 3, 9),
          countryCode: 'IN',
          regionCode: 'KA',
          category: HolidayCategory.regional,
          verification: VerificationStatus.tentative,
          isOptional: true,
          recurrence: HolidayRecurrence.lunar,
        ),
      ];
      final decoded = importHolidaysJson(exportHolidaysJson(original));
      expect(decoded.length, 2);
      for (var i = 0; i < original.length; i++) {
        expect(decoded[i].toJson(), original[i].toJson());
      }
      expect(decoded[1].verification, VerificationStatus.tentative);
      expect(decoded[1].isOptional, isTrue);
      expect(decoded[1].regionCode, 'KA');
    });

    test('rejects invalid documents', () {
      expect(() => importHolidaysJson('nope'), throwsFormatException);
      expect(() => importHolidaysJson('[]'), throwsFormatException);
      expect(
        () => importHolidaysJson('{"schemaVersion": 99, "holidays": []}'),
        throwsFormatException,
      );
      expect(
        () => importHolidaysJson('{"schemaVersion": 1}'),
        throwsFormatException,
      );
    });

    test('rejects an impossible date and unknown category', () {
      String doc(String date, String category) => jsonEncode({
            'schemaVersion': 1,
            'holidays': [
              {
                'id': 'a',
                'name': 'A',
                'date': date,
                'country': 'IN',
                'category': category,
              },
            ],
          });
      expect(
        () => importHolidaysJson(doc('2027-02-30', 'national')),
        throwsFormatException,
      );
      expect(
        () => importHolidaysJson(doc('2027-02-20', 'bogus')),
        throwsFormatException,
      );
      expect(importHolidaysJson(doc('2027-02-20', 'national')).length, 1);
    });

    test('rejects duplicate ids', () {
      final record = {
        'id': 'dup',
        'name': 'A',
        'date': '2027-01-01',
        'country': 'IN',
        'category': 'national',
      };
      final source = jsonEncode({
        'schemaVersion': 1,
        'holidays': [record, record],
      });
      expect(() => importHolidaysJson(source), throwsFormatException);
    });

    test('defaults verification to unverified when absent', () {
      final source = jsonEncode({
        'schemaVersion': 1,
        'holidays': [
          {
            'id': 'a',
            'name': 'A',
            'date': '2027-01-01',
            'country': 'in',
            'category': 'national',
          },
        ],
      });
      final h = importHolidaysJson(source).single;
      expect(h.verification, VerificationStatus.unverified);
      expect(h.countryCode, 'IN');
    });
  });

  group('filterHolidays', () {
    final all = [
      make('national'),
      make('regional-ka', region: 'KA', category: HolidayCategory.regional),
      make('regional-mh', region: 'MH', category: HolidayCategory.regional),
      make('religious', category: HolidayCategory.religious),
      make('company', category: HolidayCategory.company),
      make('custom', category: HolidayCategory.custom),
      make('optional', optional: true, category: HolidayCategory.religious),
      make('us-holiday', country: 'US'),
    ];

    List<String> ids(HolidayPreferences prefs, {String? region = 'KA'}) =>
        filterHolidays(
          all,
          countryCode: 'IN',
          regionCode: region,
          prefs: prefs,
        ).map((h) => h.id).toList();

    test('defaults include everything except optional holidays', () {
      expect(
        ids(const HolidayPreferences()),
        ['national', 'regional-ka', 'religious', 'company', 'custom'],
      );
    });

    test('optional holidays only appear when enabled', () {
      expect(ids(const HolidayPreferences()), isNot(contains('optional')));
      expect(
        ids(const HolidayPreferences(includeOptional: true)),
        contains('optional'),
      );
    });

    test('category switches are honoured', () {
      expect(
        ids(const HolidayPreferences(includeReligious: false)),
        isNot(contains('religious')),
      );
      expect(
        ids(const HolidayPreferences(includeRegional: false)),
        isNot(contains('regional-ka')),
      );
      expect(
        ids(const HolidayPreferences(includeCompany: false)),
        isNot(contains('company')),
      );
    });

    test('region and country are respected', () {
      expect(ids(const HolidayPreferences()), isNot(contains('regional-mh')));
      expect(
        ids(const HolidayPreferences(), region: 'MH'),
        contains('regional-mh'),
      );
      expect(
        ids(const HolidayPreferences(), region: null),
        isNot(contains('regional-ka')),
      );
      expect(ids(const HolidayPreferences()), isNot(contains('us-holiday')));
    });
  });
}
