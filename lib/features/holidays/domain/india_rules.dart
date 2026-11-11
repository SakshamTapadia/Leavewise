import 'package:leavewise/features/holidays/domain/holiday.dart';
import 'package:leavewise/features/holidays/domain/holiday_rules.dart';

/// Rules for centrally gazetted holidays in India that can be computed for any
/// year. Category national means gazetted by the Government of India, so the
/// religious preference switch does not remove them.
///
/// Holi, Ram Navami, Mahavir Jayanti, Buddha Purnima, Janmashtami, Dussehra,
/// Diwali and Guru Nanak's Birthday follow the lunisolar calendar and have no
/// rule here. They are supplied by the per-year dataset files.
const List<HolidayRule> indiaNationalRules = [
  HolidayRule(
    id: 'in-republic-day',
    name: 'Republic Day',
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.fixedDate,
    month: 1,
    day: 26,
  ),
  HolidayRule(
    id: 'in-independence-day',
    name: 'Independence Day',
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.fixedDate,
    month: 8,
    day: 15,
  ),
  HolidayRule(
    id: 'in-gandhi-jayanti',
    name: "Mahatma Gandhi's Birthday",
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.fixedDate,
    month: 10,
    day: 2,
  ),
  HolidayRule(
    id: 'in-christmas',
    name: 'Christmas Day',
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.fixedDate,
    month: 12,
    day: 25,
  ),
  HolidayRule(
    id: 'in-good-friday',
    name: 'Good Friday',
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.easterOffset,
    offsetDays: -2,
  ),
  HolidayRule(
    id: 'in-id-ul-fitr',
    name: 'Id-ul-Fitr',
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.islamic,
    month: 10,
    day: 1,
  ),
  HolidayRule(
    id: 'in-id-ul-zuha',
    name: 'Id-ul-Zuha (Bakrid)',
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.islamic,
    month: 12,
    day: 10,
  ),
  HolidayRule(
    id: 'in-muharram',
    name: 'Muharram',
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.islamic,
    month: 1,
    day: 10,
  ),
  HolidayRule(
    id: 'in-milad-un-nabi',
    name: "Milad-un-Nabi (Prophet Mohammad's Birthday)",
    countryCode: 'IN',
    category: HolidayCategory.national,
    kind: HolidayRuleKind.islamic,
    month: 3,
    day: 12,
  ),
];
