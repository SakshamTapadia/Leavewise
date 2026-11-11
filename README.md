# LeaveWise

Work smarter. Take better breaks. A holiday and leave planner for Android and iOS built with Flutter.

## Current state
Only the domain logic (dates, holidays, leave optimizer, leave balances) and its tests exist, plus a shell app. See TODO.md.

## Run the checks
Locally:

    flutter create --platforms=android,ios --org com.leavewise --project-name leavewise .
    rm -f test/widget_test.dart
    flutter pub get
    flutter analyze
    flutter test

Without a computer: push this folder to a GitHub repository. The CI workflow in `.github/workflows/ci.yml` runs the analyzer and tests, then builds a release APK and attaches it to the run.

## Release
Signing keys and store accounts are yours to create. Nothing here contains credentials.
