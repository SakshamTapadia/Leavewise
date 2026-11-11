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
- [ ] India 2027 holiday dataset (must come from official sources, see below)
- [ ] Onboarding, dashboard, calendar views, leave screens, saved plans

## Phase 4 to 7
- [ ] Notifications, sharing, settings, localization, privacy controls
- [ ] Supabase sync and RLS, admin dashboard
- [ ] Widget and integration tests, performance and accessibility audit
- [ ] Legal drafts, store listings, release checklist

## Holiday data rule
No dates are included yet. The 2027 India list has to be copied from the official Government of India gazetted holiday notification, with lunar-dependent dates marked `tentative` until confirmed.
