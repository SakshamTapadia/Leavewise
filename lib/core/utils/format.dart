const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String monthName(int month) => _months[month - 1];
String monthShort(int month) => _months[month - 1].substring(0, 3);
String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1].substring(0, 3);
String weekdayLetter(int weekday) => _weekdays[weekday - 1].substring(0, 1);

String fmtDate(DateTime d) => '${d.day} ${monthShort(d.month)} ${d.year}';
String fmtShort(DateTime d) => '${d.day} ${monthShort(d.month)}';

/// "10 Mar to 23 Mar 2027", or with both years when they differ.
String fmtRange(DateTime a, DateTime b) {
  if (a == b) return fmtDate(a);
  if (a.year == b.year) return '${fmtShort(a)} to ${fmtDate(b)}';
  return '${fmtDate(a)} to ${fmtDate(b)}';
}

/// 12.0 becomes "12", 1.5 stays "1.5".
String fmtNum(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

String plural(num n, String one, [String? many]) {
  return '${fmtNum(n)} ${n == 1 ? one : (many ?? '${one}s')}';
}
