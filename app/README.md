# fitness_counter

Android-first fitness planning and workout tracking app. The production database
is SQLite (`fitness_counter_v2.db`) and is opened through `AppDatabase`; workout,
history, plan, exercise, and settings flows all use the production repositories.

## Run

From this directory, use `flutter run` for a connected Android device or an
online emulator. The app requests notification/exact-alarm permissions only
through the Settings permission actions. Rest reminders and vibration are
independent settings; changing either setting does not rewrite a workout or plan
snapshot.

Do not clear app data or delete the SQLite database when diagnosing a failed
write. Failed writes retain the user draft and expose a retry action.

## Verify

Run the serial host checks:

```powershell
flutter analyze
flutter test --concurrency=1 -r expanded
```

Android integration tests are under `integration_test/` and must run against an
observed online device ID. They create a uniquely named isolated database and do
not seed user-visible outcomes:

```powershell
adb devices -l
$env:HDAY_ANDROID_DEVICE_ID = 'the-observed-device-id'
flutter test integration_test -d $env:HDAY_ANDROID_DEVICE_ID -r expanded
```

If a test fails because the Flutter VM-service connection closes, record the
device state and exact error, then stop repeating the same launch attempt. Do not
set a proxy unless Flutter explicitly reports a dependency-download network
failure. For physical acceptance, verify tactile vibration, lock-screen and
background reminders, and screenshots at 360/390/430 logical widths including
1.3 font scale on actual hardware.

The Task 14 process-loss probe does not use the Flutter test VM-service. It
builds a dedicated debug test target, preserves app data, kills only the PID
returned for this package with `run-as ... kill -9`, and cold-launches between
the active, resting, and completed-paused checkpoints:

```powershell
powershell -ExecutionPolicy Bypass `
  -File integration_test/run_android_workout_process_probe.ps1 `
  -Device $env:HDAY_ANDROID_DEVICE_ID
```

This probe verifies Android SQLite/controller restoration and native rest-alarm
state. It is not a substitute for the complete integration suite or physical
vibration, lock-screen, background, and release-build acceptance.

## Release APK

Build with:

```powershell
flutter build apk --release
```

The artifact is `build/app/outputs/flutter-apk/app-release.apk`. Inspect it
without modifying it:

```powershell
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
(Get-Item build/app/outputs/flutter-apk/app-release.apk).Length
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -S -W -n com.example.fitness_counter/.MainActivity
```

The current local build is debug-signed for sideloading; it is not a
store-production signing configuration. Never uninstall the app or clear data to
resolve an install conflict; use a dedicated compatible runtime instead.

## Evidence

Task 14 acceptance status, APK facts, device inventory, and deferred physical
gates are recorded in
`docs/verification/2026-09-15-flutter-acceptance.md`.
