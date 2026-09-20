param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$globalHexLease = Enter-FluxEngineRun 'profile-global-hex'
$globalHexSavedRoaming = $env:APPDATA
$globalHexRepo = Get-FluxRepoRoot
$globalHexOutput = Join-Path $globalHexRepo ".godot/global-hex-profile-$RunId.json"
$globalHexLogs = Join-Path $globalHexRepo ".godot/global-hex-profile-$RunId-logs"
try {
    if ((Test-Path -LiteralPath $globalHexOutput) -or (Test-Path -LiteralPath $globalHexLogs)) { throw 'Fresh RunId required' }
    New-Item -ItemType Directory -Path $globalHexLogs | Out-Null
    $env:APPDATA = Join-Path $globalHexLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content -LiteralPath (Join-Path $globalHexLogs 'identity.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless', '--path', $globalHexRepo, '--script', 'res://tests/performance/profile_global_hex.gd', '--', "--output=res://.godot/global-hex-profile-$RunId.json") (Join-Path $globalHexLogs 'profile.log') -RejectWarnings -TimeoutSeconds 900
    $globalHexReceipt = Get-Content -LiteralPath $globalHexOutput -Raw | ConvertFrom-Json
    if ($globalHexReceipt.status -ne 'passed' -or $globalHexReceipt.failures -ne 0 -or @($globalHexReceipt.runs).Count -ne 1) { throw 'Dense probe accounting failed' }
    [pscustomobject]@{status='passed'; receipt=$globalHexOutput; assertions=$globalHexReceipt.assertions; logs=$globalHexLogs}
} finally {
    $env:APPDATA = $globalHexSavedRoaming
    Exit-FluxEngineRun $globalHexLease
}
