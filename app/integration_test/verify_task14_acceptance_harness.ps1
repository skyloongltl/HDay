param(
    [string]$AppRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Assert-FileContains {
    param(
        [string]$Path,
        [string[]]$Patterns
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required Task 14 harness file is missing: $Path"
    }
    $source = Get-Content -LiteralPath $Path -Raw
    foreach ($pattern in $Patterns) {
        if (-not $source.Contains($pattern)) {
            throw "Task 14 harness contract is missing '$pattern' in $Path"
        }
    }
}

$processTarget = Join-Path $AppRoot 'integration_test/android_workout_process_probe.dart'
$processDriver = Join-Path $AppRoot 'integration_test/run_android_workout_process_probe.ps1'
$fullFlow = Join-Path $AppRoot 'integration_test/full_workout_flow_test.dart'

Assert-FileContains $processTarget @(
    'ACTIVE_READY',
    'RESTING_READY',
    'COMPLETED_PAUSED_READY',
    'PROCESS_RECOVERY_PASS',
    'controller.restore()',
    'AndroidVibrationGateway'
)
Assert-FileContains $processDriver @(
    "'kill', '-9'",
    'PROCESS_RECLAIMED',
    'PROCESS_RECOVERY_PASS',
    'vibration_active'
)

$driverSource = Get-Content -LiteralPath $processDriver -Raw
if ($driverSource -match 'shell\s+am\s+force-stop') {
    throw 'The process-loss driver must not use adb force-stop.'
}

Assert-FileContains $fullFlow @(
    'Task 14 计划 A',
    'Task 14 计划 B',
    'freeWorkout: false',
    'sourceRevisionId',
    'PlanMode.cycles'
)

Write-Output 'PASS Task 14 acceptance harness contract'
