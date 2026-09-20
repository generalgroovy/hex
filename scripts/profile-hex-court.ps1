param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,60}$')][string]$RunId
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$lease = Enter-FluxEngineRun 'profile-hex-court'
$hadHexProfileAppData = Test-Path Env:APPDATA
$savedHexProfileAppData = $env:APPDATA
$repo = Get-FluxRepoRoot
$output = Join-Path $repo ".godot/hex-profile-$RunId.json"
$logs = Join-Path $repo ".godot/hex-profile-$RunId-logs"
$personalProfilePath = $null
$personalProfileBefore = 'appdata-unavailable'
try {
    if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $logs)) {
        throw 'Choose a fresh RunId; retained profile runs are immutable.'
    }
    New-Item -ItemType Directory -Path $logs | Out-Null
    if ($hadHexProfileAppData) {
        $personalProfilePath = Join-Path $savedHexProfileAppData 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
        $personalProfileBefore = if (Test-Path -LiteralPath $personalProfilePath) { (Get-FileHash -LiteralPath $personalProfilePath).Hash } else { 'absent' }
    }
    $env:APPDATA = Join-Path $logs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content -LiteralPath (Join-Path $logs 'identity-check.json')
    Get-CimInstance Win32_Processor |
        Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $logs 'hardware.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @(
        '--headless',
        '--path', $repo,
        '--script', 'res://tests/performance/profile_hex_court.gd',
        '--',
        "--output=res://.godot/hex-profile-$RunId.json"
    ) (Join-Path $logs 'profile.log') -RejectWarnings -TimeoutSeconds 180
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw 'Hex court profiler exited without its scoped JSON receipt.'
    }
    $receipt = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    if ([int]$receipt.failures -ne 0 -or [int]$receipt.settings.sample_ticks_per_variant_run -lt 2400 -or [int]$receipt.settings.repetitions_per_variant -ne 3) {
        throw 'Hex court profile receipt failed its bounded workload contract.'
    }
}
finally {
    try {
        if ($hadHexProfileAppData) {
            $env:APPDATA = $savedHexProfileAppData
        }
        else {
            Remove-Item Env:APPDATA -ErrorAction SilentlyContinue
        }
        $personalProfileAfter = if ($personalProfilePath -and (Test-Path -LiteralPath $personalProfilePath)) { (Get-FileHash -LiteralPath $personalProfilePath).Hash } elseif ($personalProfilePath) { 'absent' } else { 'appdata-unavailable' }
        [ordered]@{
            before = $personalProfileBefore
            after = $personalProfileAfter
            unchanged = ($personalProfileBefore -ceq $personalProfileAfter)
            appdata_restored = ((Test-Path Env:APPDATA) -eq $hadHexProfileAppData) -and (-not $hadHexProfileAppData -or $env:APPDATA -ceq $savedHexProfileAppData)
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'profile-guard.json')
        if ($personalProfileBefore -cne $personalProfileAfter) {
            throw 'Personal profile changed; quarantine this measurement and inspect profile-guard.json.'
        }
    }
    finally {
        Exit-FluxEngineRun $lease
    }
}
