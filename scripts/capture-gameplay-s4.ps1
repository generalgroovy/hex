param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$s4Lease = Enter-FluxEngineRun 'capture-gameplay-s4'
$s4SavedRoaming = $env:APPDATA
$s4Repo = Get-FluxRepoRoot
$s4Logs = Join-Path $s4Repo ".godot/gameplay-s4-ui-$RunId-logs"
$s4Personal = Join-Path $s4SavedRoaming 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
$s4ProfileBefore = if (Test-Path -LiteralPath $s4Personal) { Get-FluxFileSha256 $s4Personal } else { '' }
try {
    if (Test-Path -LiteralPath $s4Logs) { throw 'Fresh capture RunId required' }
    New-Item -ItemType Directory -Path $s4Logs | Out-Null
    $env:APPDATA = Join-Path $s4Logs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content (Join-Path $s4Logs 'identity.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--path', $s4Repo, '--script', 'res://tests/visual/capture_gameplay_s4.gd', '--', "--output=res://.godot/gameplay-s4-ui-$RunId") (Join-Path $s4Logs 'capture.log') -RejectWarnings
} finally {
    $env:APPDATA = $s4SavedRoaming
    Exit-FluxEngineRun $s4Lease
    $s4ProfileAfter = if (Test-Path -LiteralPath $s4Personal) { Get-FluxFileSha256 $s4Personal } else { '' }
    if ($s4ProfileAfter -cne $s4ProfileBefore) { throw 'Personal profile changed during isolated UI capture' }
}
