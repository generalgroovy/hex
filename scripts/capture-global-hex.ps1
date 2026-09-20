param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$globalHexLease = Enter-FluxEngineRun 'capture-global-hex'
$globalHexSavedRoaming = $env:APPDATA
$globalHexRepo = Get-FluxRepoRoot
$globalHexOutput = Join-Path $globalHexRepo ".godot/global-hex-$RunId"
$globalHexLogs = Join-Path $globalHexRepo ".godot/global-hex-$RunId-logs"
try {
    if ((Test-Path -LiteralPath $globalHexOutput) -or (Test-Path -LiteralPath $globalHexLogs)) { throw 'Fresh RunId required' }
    New-Item -ItemType Directory -Path $globalHexLogs | Out-Null
    $env:APPDATA = Join-Path $globalHexLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content -LiteralPath (Join-Path $globalHexLogs 'identity.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--path', $globalHexRepo, '--windowed', '--resolution', '1280x720', '--fixed-fps', '120', '--script', 'res://tests/visual/capture_global_hex.gd', '--', "--output=res://.godot/global-hex-$RunId", '--tick-rate=120', '--no-lan-discovery') (Join-Path $globalHexLogs 'capture.log') -RejectWarnings -TimeoutSeconds 240
    $globalHexReceipt = Get-Content -LiteralPath (Join-Path $globalHexOutput 'receipt.json') -Raw | ConvertFrom-Json
    if ($globalHexReceipt.status -ne 'passed' -or @($globalHexReceipt.frames).Count -ne 7 -or $globalHexReceipt.display -eq 'headless') { throw 'Incomplete native evidence' }
    $globalHexReceipt | ConvertTo-Json -Depth 30
} finally {
    $env:APPDATA = $globalHexSavedRoaming
    Exit-FluxEngineRun $globalHexLease
}
