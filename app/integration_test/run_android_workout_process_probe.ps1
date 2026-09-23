param(
    [string]$Device = 'emulator-5554',
    [string]$ProbeId = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString())
)

$ErrorActionPreference = 'Stop'
$package = 'com.example.fitness_counter'
$activity = "$package/.MainActivity"
$marker = "files/task14_workout_process_$ProbeId.json"
$apk = 'build/app/outputs/flutter-apk/app-debug.apk'

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & adb -s $Device @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb command failed: adb -s $Device $($Arguments -join ' ')"
    }
}

function Read-Marker {
    $text = (& adb -s $Device shell run-as $package cat $marker 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    return $text | ConvertFrom-Json
}

function Wait-Stage {
    param([string]$Stage, [int]$TimeoutSeconds = 30)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 250
        $state = Read-Marker
        if ($state.stage -eq 'PROCESS_RECOVERY_FAILED') {
            throw "Workout process probe failed: $($state.error)"
        }
        if ($state.stage -eq $Stage) {
            Write-Host "STAGE $Stage $($state | ConvertTo-Json -Compress)"
            return $state
        }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for process probe stage $Stage"
}

function Reclaim-And-Relaunch {
    $pidOutput = & adb -s $Device shell pidof $package
    $appProcessId = if ($null -eq $pidOutput) { '' } else { ([string]$pidOutput).Trim() }
    if ($appProcessId -notmatch '^\d+$') {
        throw "Expected exactly one task app process, got '$appProcessId'"
    }
    # Kill only the verified task package PID. This is ordinary process loss,
    # not adb force-stop, so Android alarm registrations remain intact.
    Invoke-Adb -Arguments @(
        'shell', 'run-as', $package, 'kill', '-9', $appProcessId
    )
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 200
        $remainingOutput = & adb -s $Device shell pidof $package
        $remaining = if ($null -eq $remainingOutput) { '' } else { ([string]$remainingOutput).Trim() }
    } while ($remaining -and [DateTime]::UtcNow -lt $deadline)
    if ($remaining) {
        throw "Task process survived reclamation: $remaining"
    }
    Write-Output "PROCESS_RECLAIMED pid=$appProcessId; SQLite and alarms retained"
    Invoke-Adb -Arguments @('shell', 'am', 'start', '-W', '-n', $activity)
}

Write-Output "DEVICE=$Device PROBE_ID=$ProbeId START=$([DateTime]::UtcNow.ToString('o'))"
& flutter build apk --debug `
    --target integration_test/android_workout_process_probe.dart `
    --dart-define "TASK14_PROCESS_PROBE_ID=$ProbeId"
if ($LASTEXITCODE -ne 0) { throw 'Workout process probe APK build failed' }
Invoke-Adb -Arguments @('install', '-r', $apk)
Invoke-Adb -Arguments @('shell', 'input', 'keyevent', '224')
Invoke-Adb -Arguments @('shell', 'wm', 'dismiss-keyguard')
Invoke-Adb -Arguments @('shell', 'am', 'start', '-W', '-n', $activity)

$active = Wait-Stage 'ACTIVE_READY'
Reclaim-And-Relaunch
$resting = Wait-Stage 'RESTING_READY'

[xml]$effects = (& adb -s $Device shell run-as $package cat shared_prefs/rest_effects.xml) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot read native rest effect state' }
$native = @{}
foreach ($entry in $effects.map.string) { $native[$entry.name] = $entry.InnerText }
if ($resting.vibrationScheduled -and $native['vibration_active'] -ne $resting.restId) {
    throw 'Native vibration alarm was not retained before process loss'
}
if ($resting.notificationScheduled -and $native['notification_active'] -ne $resting.restId) {
    throw 'Native notification alarm was not retained before process loss'
}

Reclaim-And-Relaunch
$paused = Wait-Stage 'COMPLETED_PAUSED_READY'

[xml]$effects = (& adb -s $Device shell run-as $package cat shared_prefs/rest_effects.xml) -join "`n"
$native = @{}
foreach ($entry in $effects.map.string) { $native[$entry.name] = $entry.InnerText }
if ($native['vibration_active'] -eq $paused.restId -or $native['notification_active'] -eq $paused.restId) {
    throw 'Obsolete rest alarm remained active after leaving rest'
}

Reclaim-And-Relaunch
$passed = Wait-Stage 'PROCESS_RECOVERY_PASS'
Write-Output "PROCESS_RECOVERY_PASS session=$($passed.sessionId) frozenSeconds=$($passed.frozenSeconds)"
Write-Output "END=$([DateTime]::UtcNow.ToString('o'))"
