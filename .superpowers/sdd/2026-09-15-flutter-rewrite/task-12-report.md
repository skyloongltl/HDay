# Task 12 Report: Persisted Settings and Extensible Theme Selection

Base: `1857657`
Final implementation commit: `dbcb112`

## Implementation

- Added typed `SettingsController`, Riverpod providers, SQLite-backed settings state, committed/pending save state, failure rollback, retry, ordered rapid updates, and unknown-theme registry fallback.
- Added the `/settings` route and a real settings screen with persisted unit/rest/reminder/vibration/screen-awake/week-start/theme controls, loading/error/retry states, registry-only theme choices, live notification/exact-alarm projection, and gateway actions.
- Removed the persisted permission field from `AppSettings`; permission remains a live `RestEffectsStatus.permission` projection.
- Added initial permission refresh and retained `WorkoutController.refreshRestEffects()` after settings and permission actions.
- Theme retry no longer gates the entire Material shell on settings loading. The registry fallback theme keeps the app runnable; the settings page owns settings loading/error/retry.
- Week-start persistence is consumed by existing History/Today calendar computations and invalidated after a committed settings write; plan schedule and workout snapshots are not rewritten.

## TDD and verification

- Historical implementation was inherited uncommitted. The original focused settings run was RED: the rapid reminder/vibration widget interaction left `vibration=1` and emitted a SQLite lock warning because the second asynchronous write was discarded while `isSaving` was true.
- Fix-round RED was reproduced by the focused widget test; the controller-level `rapid independent changes are persisted in invocation order` regression was added before the queue implementation.
- Historical GREEN: the initial settings implementation passed 12 tests; the fix-round settings suite now passes 18 tests, including the new permission-state and visual-matrix coverage.
- Historical GREEN: the prior combined settings/rest-effects run passed 19 tests; the current combined run passes 24 tests.
- Historical broad run passed 313 tests before the final cross-task additions; the authoritative serial run below covers the complete suite.
- First full default run exposed two host SQLite/async failures (theme retry timeout and summary/history database lock). Theme retry was fixed; the lock is the known parallel SQLite runner instability.
- Serial verification: `flutter test -j 1 -r expanded` -> `380` tests passed.
- `flutter analyze` -> no errors; only 10 existing style `info` notices (directive ordering and trailing commas).

## Persistence and behavior proofs

- SQLite restart test covers every durable setting, including both reminders/vibration set to `00`/false.
- Triggered save failure proves committed values render again, intended values remain pending, and retry persists them after trigger removal.
- Active workout and plan schedule snapshots remain unchanged after default rest/unit updates.
- Corrupt persisted theme IDs resolve to the registry's single `breath-rhythm` definition without mutating unfinished or saved snapshots.
- Permission UI tests use fake gateways only through the real `RestEffectsController` action methods and cover granted, unavailable (`permission == null`), request failure, and timing-degraded projections.
- A failed permission gateway request is reconciled in `finally`, and the failure state exposes an explicit retry action instead of ordinary denial copy.
- Scheduled flags remain internal accepted scheduling state; no delivery receipt or native pending-alarm inventory is displayed.

## Visual evidence and limits

Host evidence: `.superpowers/sdd/2026-09-15-flutter-rewrite/task-12-ui/settings_{360,390,430}_{1.0,1.3}.png` (six captures, 800 logical px high). The matrix covers 360/390/430 logical px at text scales 1.0 and 1.3; settings controls and registry selection render without layout exceptions, and switch hit targets are at least 48 logical px. Tests load `C:/Windows/Fonts/NotoSansSC-VF.ttf` through `FontLoader` inside `tester.runAsync`, so Chinese glyphs are inspectable in the captures. These remain host screenshots, not device typography acceptance.

Evidence fix round 2 regenerated all six captures from one matrix test using the same default database, granted permission projection, font setup, capture order, and top scroll position. The matrix now asserts the settings list remains at the top (`dy < 100`) before each capture; the persistence test no longer overwrites `settings_360_1.3.png` with a different state.

No physical Android device was available. This task does not claim tactile vibration, lock-screen/background behavior, native delivery receipts, release APK, installation, or final Android visual acceptance; those remain Task 14 gates.

## Scope and review package

Only Task 12 files were staged. Existing direct Task 10 rest-effects composition changes are included because settings permission actions depend on those interfaces. `progress.md` was not modified.

Fix-round RED/GREEN evidence: the AppBar geometry test was first run RED against the old left-aligned AppBar (`centerTitle` was null), then GREEN after the centered circular affordance implementation. Permission unavailable/failure/degraded tests were added alongside the state branches and pass in the focused run. Evidence fix round 2 first exposed the duplicate 360/1.3 mismatch, then passed after the single-state matrix assertion and regenerated capture.

Verification logs:

- `task-12-full-serial-fix1.log`: `flutter test -j 1 -r expanded` -> 380 passed.
- `task-12-focused-task10.log`: `flutter test -j 1 test/features/workout` -> 200 passed.
- `task-12-focused-task11.log`: `flutter test -j 1 test/features/history` -> 40 passed.
- `task-12-focused-task9.log`: `flutter test -j 1 test/features/plans test/features/today` -> 61 passed.
- `task-12-analyze-fix1.log`: no errors; only 10 pre-existing style `info` notices outside the changed production paths.
- Latest focused settings verification: `flutter test test/features/settings -r expanded` -> 18 passed after evidence normalization.

Review package: `review-1857657..HEAD.diff` (generated after the final report commit).
