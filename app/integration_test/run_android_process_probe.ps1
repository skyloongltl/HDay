param([string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Stop'
$package = 'com.example.fitness_counter'
function Read-EffectState {
    [xml]$document = (& adb -s $Device shell run-as $package cat shared_prefs/rest_effects.xml) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read task app reminder state' }
    $state = @{}
    foreach ($entry in $document.map.string) { $state[$entry.name] = $entry.InnerText }
    return $state
}
& adb -s $Device install -r build/app/outputs/flutter-apk/app-debug.apk
if ($LASTEXITCODE -ne 0) { throw 'Probe APK installation failed' }
& adb -s $Device shell input keyevent 224
& adb -s $Device shell wm dismiss-keyguard
& adb -s $Device shell am start -n "$package/.MainActivity"
$readyDeadline = [DateTime]::UtcNow.AddSeconds(20)
do {
    Start-Sleep -Milliseconds 500
    $state = Read-EffectState
    $restIdentity = $state['vibration_active']
} until (($restIdentity -like 'process-*') -or [DateTime]::UtcNow -gt $readyDeadline)
if ($restIdentity -notlike 'process-*') { throw 'Probe failed to schedule' }
if ($state['notification_active'] -ne $restIdentity) { throw 'Both effects require granted permission for this probe' }
$appProcessId = (& adb -s $Device shell pidof $package).Trim()
if ($appProcessId -notmatch '^\d+$') { throw 'Expected exactly one task app process' }
Write-Output "SCHEDULED identity=$restIdentity process=$appProcessId"
& adb -s $Device shell input keyevent 3
& adb -s $Device shell input keyevent 223
# Kill only the verified task app process. No force-stop: alarms remain registered.
& adb -s $Device shell run-as $package kill -9 $appProcessId
Start-Sleep -Milliseconds 500
$remaining = & adb -s $Device shell pidof $package
if ($remaining) { throw "Task app process survived reclamation: $remaining" }
Write-Output 'PROCESS_RECLAIMED no app process; alarms retained'
$deliveryDeadline = [DateTime]::UtcNow.AddSeconds(60)
do {
    Start-Sleep -Milliseconds 500
    $state = Read-EffectState
} until (($state['vibration_delivered'] -eq $restIdentity -and $state['notification_delivered'] -eq $restIdentity) -or [DateTime]::UtcNow -gt $deliveryDeadline)
if ($state['vibration_delivered'] -ne $restIdentity -or $state['notification_delivered'] -ne $restIdentity) {
    throw 'Receivers did not deliver after process reclamation'
}
if ($state['notification_active'] -or $state['vibration_active']) { throw 'Delivered effects remain active' }
$notificationDump = (& adb -s $Device shell dumpsys notification --noredact) -join "`n"
if ($notificationDump -notmatch 'NotificationRecord\(.*pkg=com.example.fitness_counter') {
    throw 'NotificationManager contains no posted task app notification'
}
& adb -s $Device shell dumpsys power | Select-String 'mWakefulness='
Write-Output "PASS receiver delivery after process reclamation: $restIdentity"
Write-Output 'PASS cancelled identity was not delivered; both active identities cleared'
Write-Output 'PASS actual NotificationManager record present; tactile vibration is not measurable on emulator'
