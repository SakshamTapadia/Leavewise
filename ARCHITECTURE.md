# LeaveWise architecture

## Layers
Feature-first Clean Architecture. Each feature folder has `domain/` (pure Dart, no Flutter), `data/` (Drift, JSON assets, Supabase) and `presentation/` (widgets, Riverpod providers). Only `domain/` exists so far.

## Local-only by design
There is no backend, account, cloud sync, remote dataset update, admin dashboard or analytics SDK. Everything runs on the device and works offline. Consequences:
- Data lives in simple repositories over `shared_preferences` (JSON), which works on Android, iOS and web. Drift/SQLite is not used.
- Holiday data ships inside the app as `assets/data/holidays/<country>-<year>.json`. New years arrive with app updates, or the user can import a JSON file in Settings.
- Backup and moving to a new phone use JSON export and import.
- No account means nothing to delete in the cloud: "delete my data" only clears local storage.

## Domain modules written so far
- `core/utils/date_utils.dart`: all dates are UTC-midnight calendar days, so arithmetic ignores time zones and daylight saving. Strict date parsing rejects impossible dates such as 30 February.
- `features/calendar/domain/work_schedule.dart`: working weekdays (Monday = 1 ... Sunday = 7).
- `features/holidays/domain`: `Holiday` record, JSON import/export with schema version and validation, preference-based filtering.
- `features/leave_balance/domain`: statuses, deduction rules, balance summaries. Suggested, rejected and cancelled entries never deduct.
- `features/leave_optimizer/domain`: the optimizer.

## Holidays for any year
`holiday_rules.dart` generates holidays from rules for any year: fixed Gregorian dates, Easter-relative dates (exact), and Islamic dates (tabular estimate, always tentative, since real dates follow moon sighting). `resolveHolidaysForYear` merges these with per-year dataset records. A record carrying a `ruleId` replaces what that rule would generate, so official dates beat estimates. Festivals that follow a lunisolar panchang have no rule and appear only when a dataset provides them. Category `national` means centrally gazetted, so turning off the religious preference does not hide gazetted festivals.

## Optimizer
Each day in the planning horizon is free (holiday, non-working weekday, or already-planned leave) or costly (needs one new leave). A recommendation is a contiguous window with exactly c costly days that cannot be extended on either side without another leave. All such windows are enumerated for c = 1..budget, so results are exhaustive and every duration is read from the calendar. Day kinds are exclusive, with holiday taking precedence over weekend over existing leave.

- `recommend()` ranks by max days, min leaves, efficiency (compared by cross-multiplication, no float error) or earliest date, removes overlaps, and keeps the combined leaves within the balance.
- `freeStretches()` finds zero-leave long weekends.
- `planAnnual()` chooses non-overlapping breaks for a total leave budget using exact dynamic programming.

Limits: breaks never extend past the planning horizon, so a horizon that ends mid-break can understate a break but never overstate it.

## Testing
`test/` mirrors `lib/`. Optimizer expectations for fixed 2027 and 2028 scenarios were confirmed against an independent brute-force model, and property tests re-check every candidate against a separate calendar oracle.
