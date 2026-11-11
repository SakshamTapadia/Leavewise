# LeaveWise progress

Status key: [x] written, [~] written but not yet run, [ ] not started.

Nothing in this repository has been compiled or tested yet. The workspace it was written in has no Dart or Flutter SDK. Run the GitHub Actions workflow (or `flutter analyze` and `flutter test` locally) and fix whatever it reports before building further.

## Phase 1: Planning
- [x] ARCHITECTURE.md
- [x] TODO.md

## Phase 2: Foundation
- [~] pubspec.yaml, analysis_options.yaml, CI workflow
- [~] Shell main.dart (placeholder only, not the real app)
- [ ] Generate android/ and ios/ (CI does this once; commit the result)
- [ ] Riverpod, GoRouter, Drift, theme, design tokens

## Phase 3: Core features
- [~] Calendar date utilities and work schedule (domain)
- [~] Holiday model, JSON import/export, filters (domain)
- [~] Leave optimizer: candidates, ranking, free stretches, annual plan (domain)
- [~] Leave balance rules (domain)
- [~] Holiday rule engine (fixed dates, Easter, tabular Islamic estimate) and year resolver, any year
- [~] India 2027 gazetted dataset from DoPT OM dated 16.07.2026 (assets/data/holidays/IN-2027.json)
- [ ] Datasets for other years: add one IN-<year>.json per year, or serve them from the remote update channel
- [ ] Restricted (optional) holidays and state-level holidays
- [ ] Onboarding, dashboard, calendar views, leave screens, saved plans

## Phase 4 to 7
- [ ] Notifications, sharing, settings, localization, privacy controls
- [ ] Supabase sync and RLS, admin dashboard
- [ ] Widget and integration tests, performance and accessibility audit
- [ ] Legal drafts, store listings, release checklist

## Holiday data rule
Holidays work for any year. Fixed-date holidays and Good Friday are computed exactly. Islamic holidays are estimated and always `tentative`. Lunisolar festivals (Holi, Diwali, Dussehra and similar) are never computed: they come from per-year dataset files taken from official notifications. A dataset record with a `ruleId` replaces the computed value for that year.

The 2027 file was transcribed from the DoPT notification as reproduced on staffnews.in. Spot-check it against the official PDF before release. It covers centrally gazetted holidays for Delhi/New Delhi offices only.
