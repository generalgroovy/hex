param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,60}$')][string]$RunId,
    [ValidateSet('all','campus-normal','open-pressure','corridor-pressure','cluster-pressure')][string]$Case = 'all',
    [ValidateSet(720,7200)][int]$Ticks = 720
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$lease = Enter-FluxEngineRun 'four-delivery-load'
$savedLoadRoaming = $env:APPDATA
$repo = Get-FluxRepoRoot
$output = Join-Path $repo ".godot/four-delivery-load-$RunId.json"
$logs = Join-Path $repo ".godot/four-delivery-load-$RunId-logs"
$loadProfilePath = $null
$loadProfileBefore = 'not_checked'
try {
    if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $logs)) { throw 'Choose a fresh RunId; retained runs are immutable.' }
    New-Item -ItemType Directory -Path $logs | Out-Null
    $loadProfilePath = Join-Path $savedLoadRoaming 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
    $loadProfileBefore = if (Test-Path -LiteralPath $loadProfilePath) { (Get-FileHash -LiteralPath $loadProfilePath).Hash } else { 'absent' }
    $env:APPDATA = Join-Path $logs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content -LiteralPath (Join-Path $logs 'identity-check.json')
    & (Join-Path $PSScriptRoot 'check-script-class-cache.ps1') -Json | Set-Content -LiteralPath (Join-Path $logs 'class-cache.json')
    Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'hardware.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$repo,'--script','res://tests/scenarios/four_delivery_load_probe.gd','--',"--case=$Case","--ticks=$Ticks","--output=res://.godot/four-delivery-load-$RunId.json") (Join-Path $logs 'probe.log') -RejectWarnings
} finally {
    try {
        $env:APPDATA = $savedLoadRoaming
        if ($loadProfilePath) {
            $loadProfileAfter = if (Test-Path -LiteralPath $loadProfilePath) { (Get-FileHash -LiteralPath $loadProfilePath).Hash } else { 'absent' }
            [ordered]@{before=$loadProfileBefore;after=$loadProfileAfter;unchanged=($loadProfileBefore -ceq $loadProfileAfter);appdata_restored=($env:APPDATA -ceq $savedLoadRoaming)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'profile-guard.json')
            if ($loadProfileBefore -cne $loadProfileAfter) { throw 'Personal profile changed: quarantine this measurement and inspect profile-guard.json.' }
        }
    } finally {
        Exit-FluxEngineRun $lease
    }
}
