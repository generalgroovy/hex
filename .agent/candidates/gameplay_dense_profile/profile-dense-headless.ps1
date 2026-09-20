param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,60}$')][string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonCandidates = @(
    (Join-Path $PSScriptRoot '..\..\..\scripts\flux2-common.ps1'),
    (Join-Path $PSScriptRoot 'flux2-common.ps1')
)
$commonPath = $commonCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $commonPath) { throw 'Cannot locate scripts/flux2-common.ps1 from the candidate or promoted wrapper location.' }
. $commonPath

$lease = Enter-FluxEngineRun 'profile-dense-headless'
$hadAppData = Test-Path Env:APPDATA
$savedAppData = $env:APPDATA
$repo = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $commonPath) '..'))
$output = Join-Path $repo ".godot/dense-headless-$RunId.json"
$logs = Join-Path $repo ".godot/dense-headless-$RunId-logs"
$logsReady = $false
$personalProfilePath = $null
$personalProfileBefore = 'appdata-unavailable'
try {
    if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $logs)) {
        throw 'Choose a fresh RunId; retained profile runs are immutable.'
    }
    New-Item -ItemType Directory -Path $logs | Out-Null
    $logsReady = $true
    if ($hadAppData) {
        $personalProfilePath = Join-Path $savedAppData 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
        $personalProfileBefore = if (Test-Path -LiteralPath $personalProfilePath -PathType Leaf) { (Get-FileHash -LiteralPath $personalProfilePath).Hash } else { 'absent' }
    }
    $env:APPDATA = Join-Path $logs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $repo 'scripts/runtime-build-identity.ps1') -Mode Check -Json | Set-Content -LiteralPath (Join-Path $logs 'identity-check.json')
    & (Join-Path $repo 'scripts/check-script-class-cache.ps1') -Json | Set-Content -LiteralPath (Join-Path $logs 'class-cache.json')
    Get-CimInstance Win32_Processor |
        Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $logs 'hardware.json')
    [ordered]@{
        run_id = $RunId
        kind = 'local-headless-dense-profile'
        godot_binary_sha256 = Get-FluxFileSha256 (Get-FluxGodot)
        wrapper_sha256 = Get-FluxFileSha256 $PSCommandPath
        output = [IO.Path]::GetRelativePath($repo, $output).Replace('\', '/')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'invocation.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @(
        '--headless',
        '--path', $repo,
        '--script', 'res://tests/performance/profile_dense_headless.gd',
        '--',
        "--output=res://.godot/dense-headless-$RunId.json"
    ) (Join-Path $logs 'profile.log') -RejectWarnings -TimeoutSeconds 180
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw 'Dense headless profiler exited without its scoped JSON receipt.'
    }
    $receipt = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    $ordinaryRuns = @($receipt.results | Where-Object { $_.variant -eq 'ordinary' })
    $hexRuns = @($receipt.results | Where-Object { $_.variant -eq 'hex' })
    if ([int]$receipt.failures -ne 0 -or [int]$receipt.settings.warmup_ticks_excluded -ne 240 -or [int]$receipt.settings.sample_ticks_per_run -ne 2400 -or [int]$receipt.settings.repetitions -ne 3 -or $ordinaryRuns.Count -ne 3 -or $hexRuns.Count -ne 3) {
        throw 'Dense headless receipt failed its bounded matched-workload contract.'
    }
}
finally {
    try {
        if ($hadAppData) { $env:APPDATA = $savedAppData }
        else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
        $personalProfileAfter = if ($personalProfilePath -and (Test-Path -LiteralPath $personalProfilePath -PathType Leaf)) { (Get-FileHash -LiteralPath $personalProfilePath).Hash } elseif ($personalProfilePath) { 'absent' } else { 'appdata-unavailable' }
        if ($logsReady) {
            [ordered]@{
                before = $personalProfileBefore
                after = $personalProfileAfter
                unchanged = ($personalProfileBefore -ceq $personalProfileAfter)
                appdata_restored = ((Test-Path Env:APPDATA) -eq $hadAppData) -and (-not $hadAppData -or $env:APPDATA -ceq $savedAppData)
            } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'profile-guard.json')
        }
        if ($personalProfileBefore -cne $personalProfileAfter) {
            throw 'Personal profile changed; quarantine this measurement and inspect profile-guard.json.'
        }
    }
    finally {
        Exit-FluxEngineRun $lease
    }
}
