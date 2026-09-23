# Flutter Rewrite Acceptance Evidence

Date: 2026-09-18
Worktree: `C:/Code/HDay/.worktrees/flutter-rewrite-20260915`
Branch: `codex/flutter-rewrite-20260915`
Task 14 BASE: `e77f599db68e496df5729d5d703bd65cd72b157d`

This document is Task 14 evidence. It does not declare the Flutter rewrite plan
complete while the physical-device gates remain unverified.

## Command Results

Commands were run serially from `app/`. Fix-round raw logs are retained under
`.superpowers/sdd/2026-09-15-flutter-rewrite/`.

| Command | Result | Evidence/log |
|---|---|---|
| `dart format integration_test` | PASS, 8 files formatted | `task-14-fix1-harness-contract-green.log` |
| `flutter analyze` | PASS, No issues found, exit 0 | `task-14-fix1-harness-contract-green.log` |
| `flutter test --concurrency=1 -r expanded` | PASS, 601 tests, exit 0 | `task-14-fix1-full-flutter-test.log` |
| `flutter test integration_test -d emulator-5554 -r expanded` | BLOCKED, runner WebSocket closed before tests started; debug APK assembled/installed | terminal transcript; `task-14-device/` |
| `run_android_workout_process_probe.ps1 -Device emulator-5554` | PASS, three verified PID reclaims and cold relaunches | `task-14-fix1-android-process-probe-final.log` |
| `flutter build apk --release` | PASS, exit 0 | `task-14-fix1-release-build.log` |
| `adb install -r app-release.apk` | PASS, streamed install success | `task-14-fix1-release-install-launch.log` |
| `adb shell am start -S -W -n com.example.fitness_counter/.MainActivity` | PASS, cold launch, `Status: ok`, `WaitTime: 2014` | `task-14-fix1-release-install-launch.log` |

The original analyzer RED before the first Task 14 GREEN was limited to new
integration-test code:
missing `SetStatus`/`PlanMode` imports and an incorrect `list()` repository
call. Its raw transcript was not retained and cannot be reconstructed; it remains
prose-only evidence. The fix round has a separately retained RED in
`task-14-fix1-harness-contract-red.log` for the missing adb process harness, plus
`task-14-fix1-format-analyze.log` for the initial lifecycle/lint failures. The
focused contract and analyzer then passed in
`task-14-fix1-harness-contract-green.log`.
The Windows integration preflight was not applicable because this project has no
Windows desktop target.

## Runtime Inventory

The observed Android runtime was `emulator-5554`, Google
`sdk_gphone16k_x86_64`, Android 17/API 37, physical size 1080x2400, density
420, system font scale 1.0. It was online for the release install and launch.
No physical Android device was attached. Earlier Task 14 startup observation
recorded the emulator as offline for a bounded 30-second launch; the later
integration command saw it online, but the Flutter VM-service WebSocket closed
before the first test body. `android_reminders_test.dart` and
`full_workout_flow_test.dart` both failed at loading with
`WebSocketChannelException: Connection closed before full header was received`.
The runner was stopped after the repeated same failure. No emulator/data wipe or
unknown-process termination was performed.

The two original WebSocket failure transcripts were not saved as files before
review. Their exact error and affected test names are retained in this document,
the report, and the round-1 re-review, but they are not represented as raw logs.
The runner was not started again during fix round 1 because the same loading
failure had already repeated and the bounded emulator instruction applies.

## Functional Coverage

The four new Android integration files use a uniquely named SQLite database,
the production `FitnessCounterApp`, production GoRouter/controllers/repositories,
real SQLite transactions, and Android platform gateways. They cover:

- Empty-database exercise creation, category/equipment/unit persistence, two
  mixed training/rest plans (infinite plus finite cycles), a cycle-length
  revision effective on the workout date and reset to D1, Today merging plan A
  and plan B, plan-driven preparation (`freeWorkout: false`), draft
  edit/add/delete/reorder without template mutation, explicit set start, rest
  ownership, completed-paused timing, temporary training, save, same-day second
  session, and distinct workout-day statistics.
- Stable plan identity, infinite/cycles modes, training/rest days, effective
  revision dates with D1 cycle restart, old-date schedule stability, and restart
  persistence.
- History actual correction, planned/unit/source snapshot preservation, source
  edit/delete independence, same-day statistics, final-record deletion refresh,
  week-start persistence, independent reminder/vibration switches, unknown-theme
  fallback, and settings restart persistence.
- Active/resting/completedPaused/finishing process-recovery assertions and
  injected-clock rollback and greater-than-24-hour anomaly cases.

These cases are currently **UNVERIFIED on Android** because the test runner
could not keep its VM-service connection. Existing host coverage remains stage
evidence and does not substitute for Android integration execution.

The separate adb process probe did execute on Android without the Flutter test
runner. It used a unique SQLite file and production `WorkoutController`,
`SqliteWorkoutRepository`, notification gateway, and vibration gateway. Three
verified package PIDs were terminated with `run-as ... kill -9` rather than
force-stop. Cold relaunches restored active actuals/order/temporary rows and the
running segment; resting identity/selected set/timer without auto-start and the
scheduled vibration alarm; and completed-paused frozen time plus a temporary
pending set. Only explicitly starting that set resumed active timing. Obsolete
rest alarms were absent after rest ended. This is genuine Android process-loss
stage evidence on a dedicated debug target; it is not final release-process or
full UI integration evidence.

## Release APK

- Path: `app/build/app/outputs/flutter-apk/app-release.apk`
- Size: `55,283,486` bytes (`52.7 MB`)
- SHA256: `508F8B9EB68F174D44BCBD3597EE91456B4634139F4942E68AB91DE4D8798A57`
- Package: `com.example.fitness_counter`
- Activity: `com.example.fitness_counter.MainActivity`
- SDK: min 24, target/compile 36
- Signer: `C=US, O=Android, CN=Android Debug`; SHA-256 certificate
  `ff216cd44f660369237b1daeefe8202f6b66bd9c18596c6077bb35f8ebfc9c82`

This is a debug-signed local sideload build, not a production store-signed APK.
The APK installed with `adb install -r` without clearing data and cold-launched
successfully. The first screenshot,
`.superpowers/sdd/2026-09-15-flutter-rewrite/task-14-device/release-launch-emulator-1080x2400.png`,
is a uniform black image and is invalid evidence. The recapture at
`.superpowers/sdd/2026-09-15-flutter-rewrite/task-14-device/release-launch-emulator-recapture-1080x2400.png`
is 1080x2400, has 89 colors in a 20-pixel sampling grid, and visibly shows the
real release Today screen with Android system bars. It proves emulator rendering,
not physical-device acceptance.

## Reminders and Process Evidence

The Task 10 API 37 receiver evidence and the Task 14 adb process probe remain
stage evidence for notification/vibration scheduling, cancellation,
deduplication, and controlled non-force-stop process loss. Task 14 did not
reclassify that evidence as physical behavior. Physical tactile vibration,
lock-screen/background reminder behavior, permission matrix observation on
hardware, and ordinary process-loss evidence on the final release build are
**UNVERIFIED/BLOCKED** here.

## Visual Matrix

Task 13's 74 host goldens and six-pair responsive matrix remain host-only stage
evidence. No final Android screenshot matrix at 360/390/430 logical widths or
1.3 font scale was obtained. The release launch screenshot proves installation
and nonblank rendering only; it is not a Figma comparison. Final same-state React/Figma
versus Flutter comparison on physical hardware is **UNVERIFIED**.

The full host suite regenerates six tracked Task 12 Settings captures. They were
already dirty before fix round 1 and were deterministically regenerated again at
12:40 on 2026-09-18. They are outside the Task 14 commit/package and remain
unstaged rather than being silently restored or attributed to product changes.
Their exact HEAD/working blob hashes are recorded in
`task-14-fix1-working-tree-artifacts.txt`.

## Carry-Forward Disposition

The Task 10 deferred gates are carried unchanged: tactile vibration, physical
lock-screen/background reminders, release APK build/install/launch (now PASS on
the API 37 emulator), and physical visual acceptance (still BLOCKED). Task 13's
preparation AppBar and Rest border items remain host-passed but Android-unverified.
The ledger's other Task 13 deferred items remain carried into the coordinator's
final review; none is silently discarded here.

## Final Boundary

Source HEAD before Task 14 implementation: `e77f599db68e496df5729d5d703bd65cd72b157d`.
The Task 14 implementation commit and review package are recorded in
`task-14-report.md`. The plan must not be announced complete until the missing
Android integration execution and all physical-device gates have actual evidence.
