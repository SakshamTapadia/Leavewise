# LeaveWise progress

Status: [x] done and passing CI (analyzer, tests, Android release build), [ ] not started.
CI pins Flutter 3.47.9. Newer Flutter versions deprecate the material.dart import, so migrate before upgrading.

## Built
- [x] Date utilities, work schedules, leave balance rules
- [x] Holiday model, JSON import/export, filters, rule engine (fixed, Easter, Islamic estimate)
- [x] India 2027 gazetted dataset (DoPT OM 16.07.2026, via a website copy; verify against the official PDF)
- [x] Leave optimizer: candidates, four sort orders, no-overlap, balance cap, free stretches, annual plan
- [x] Local storage (shared_preferences JSON), Riverpod providers, GoRouter shell
- [x] Light and dark theme, design tokens, accessible calendar markers (H, L, O letters)
- [x] Onboarding (7 steps, leave step skippable)
- [x] Home dashboard, calendar (month, year, agenda, day sheet, custom holidays)
- [x] Breaks screen (budget presets and custom, sorting, horizon, overlap toggle)
- [x] Leaves screen (balances, add, edit, delete, types, statuses, history)
- [x] Saved plans (edit, duplicate, status changes, export, share as text, delete)
- [x] Settings (location, schedule, holiday filters, theme, export, delete all data)
- [x] Privacy and terms drafts, about page, licenses page
- [x] Tests: domain, rules, plans, and an app flow test (onboarding to dashboard)

## Not done yet, needed before store release
- [ ] Look at the app on a real device or emulator. Layout has never been seen, only tested.
- [ ] Generate android/ and ios/ folders and commit them (CI regenerates them each run today)
- [ ] App icon, splash screen, store screenshots and feature graphic
- [ ] Release signing: Android upload keystore and CI secrets, iOS certificates and provisioning
- [ ] Application ID and bundle ID check (com.leavewise.app is assumed, confirm availability)
- [ ] Contact support email and privacy policy URL (stores require a public URL)
- [ ] Local notifications and quiet hours
- [ ] Shareable image cards (text sharing exists)
- [ ] Hindi localization
- [ ] Import data from a backup file
- [ ] State holidays and restricted (optional) holidays dataset
- [ ] Holiday data for years other than 2027 (festival dates need official sources)
- [ ] Hardware keyboard focus pass, TalkBack and VoiceOver pass, high contrast mode
- [ ] Integration tests on devices, performance profiling
- [ ] docs/legal, Play Data Safety and App Privacy answers, RELEASE_CHECKLIST.md, store guides

## Dropped by decision
Supabase, accounts, sync, remote updates, admin dashboard, analytics. The app is local-only.
