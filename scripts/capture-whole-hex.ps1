param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$whLease = Enter-FluxEngineRun 'capture-whole-hex'
$whSavedRoaming = $env:APPDATA
$whRepo = Get-FluxRepoRoot
$whLogs = Join-Path $whRepo ".godot/whole-hex-$RunId-logs"
$whPersonal = Join-Path $whSavedRoaming 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
$whProfileBefore = if (Test-Path -LiteralPath $whPersonal) { Get-FluxFileSha256 $whPersonal } else { '' }
try {
    if (Test-Path -LiteralPath $whLogs) { throw 'Fresh capture RunId required' }
    New-Item -ItemType Directory -Path $whLogs | Out-Null
    $env:APPDATA = Join-Path $whLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content (Join-Path $whLogs 'identity.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--path', $whRepo, '--script', 'res://tests/visual/capture_whole_hex.gd', '--', "--output=res://.godot/whole-hex-$RunId") (Join-Path $whLogs 'capture.log') -RejectWarnings
} finally {
    $env:APPDATA = $whSavedRoaming
    Exit-FluxEngineRun $whLease
    $whProfileAfter = if (Test-Path -LiteralPath $whPersonal) { Get-FluxFileSha256 $whPersonal } else { '' }
    if ($whProfileAfter -cne $whProfileBefore) { throw 'Personal profile changed during isolated UI capture' }
}
