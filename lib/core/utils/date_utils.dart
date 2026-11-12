// Calendar-day helpers.
//
// Every date in the domain layer is a calendar day normalised to UTC
// midnight, so day arithmetic never depends on time zones or daylight
// saving changes.

/// Drops the time-of-day and time zone, returning a UTC midnight date.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Returns true when [year] is a Gregorian leap year.
bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// Number of days in [month] (1..12) of [year].
int daysInMonth(int year, int month) {
  if (month < 1 || month > 12) {
    throw RangeError.range(month, 1, 12, 'month');
  }
  const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && isLeapYear(year)) return 29;
  return days[month - 1];
}

/// Builds a validated calendar date. Throws [ArgumentError] for dates that do
/// not exist, such as 30 February.
DateTime makeDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
    throw ArgumentError('Invalid calendar date: $year-$month-$day');
  }
  return DateTime.utc(year, month, day);
}

/// Adds [days] (may be negative) to a calendar date.
DateTime addDays(DateTime d, int days) =>
    DateTime.utc(d.year, d.month, d.day + days);

/// Whole days from [from] to [to]. Negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// True when both values fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Every calendar day from [start] to [end], inclusive. Empty if end < start.
Iterable<DateTime> eachDay(DateTime start, DateTime end) sync* {
  final last = dateOnly(end);
  var current = dateOnly(start);
  while (!current.isAfter(last)) {
    yield current;
    current = addDays(current, 1);
  }
}

/// Formats as yyyy-MM-dd.
String formatDateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

final RegExp _dateKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Strictly parses yyyy-MM-dd. Unlike [DateTime.parse], impossible dates such
/// as 2027-02-30 are rejected instead of rolling over into the next month.
DateTime parseDateKey(String source) {
  final match = _dateKeyPattern.firstMatch(source);
  if (match == null) {
    throw FormatException('Expected yyyy-MM-dd', source);
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
    throw FormatException('Date does not exist', source);
  }
  return DateTime.utc(year, month, day);
}

/// Adds [months] to a calendar date, clamping the day to the target month's
/// length (31 January plus one month is 28 or 29 February).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final maxDay = daysInMonth(year, month);
  return DateTime.utc(year, month, d.day > maxDay ? maxDay : d.day);
}
