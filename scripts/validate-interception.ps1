param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,55}$')][string]$RunId,
    [ValidateSet('Playthrough','Capture')][string]$Mode = 'Playthrough',
    [string]$CommandsPath = '',
    [string]$SelectionPath = '',
    [string]$ProjectPath = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$lease = Enter-FluxEngineRun "interception-$Mode"
$savedShowcaseRoaming = $env:APPDATA
$repo = Get-FluxRepoRoot
$logs = Join-Path $repo ".godot/interception-$RunId-logs"
$profilePath = Join-Path $savedShowcaseRoaming 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
$profileBefore = if (Test-Path -LiteralPath $profilePath) { (Get-FileHash -LiteralPath $profilePath).Hash } else { 'absent' }
try {
    if (Test-Path -LiteralPath $logs) { throw 'Choose a fresh RunId; previous evidence is retained.' }
    New-Item -ItemType Directory -Path $logs | Out-Null
    $env:APPDATA = Join-Path $logs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $project = if ($ProjectPath) { (Resolve-Path -LiteralPath $ProjectPath).Path } else { $repo }
    if ($ProjectPath -and -not $project.StartsWith((Join-Path $repo '.godot/interception-before-'), [StringComparison]::OrdinalIgnoreCase)) { throw 'An alternate project must be an owned interception-before stage.' }
    & (Join-Path $project 'scripts/runtime-build-identity.ps1') -Mode Check -Json | Set-Content -LiteralPath (Join-Path $logs 'identity.json')
    $script = if ($Mode -eq 'Capture') { 'res://tests/visual/capture_interception_showcase.gd' } else { 'res://tests/scenarios/interception_playthrough.gd' }
    $output = if ($Mode -eq 'Capture') { "res://.godot/warm-style-trails-render-showcase-$RunId" } else { "res://.godot/interception-playthrough-$RunId.json" }
    $arguments = @('--path',$project,'--script',$script,'--',"--output=$output")
    if ($Mode -eq 'Playthrough') { $arguments = @('--headless') + $arguments }
    if ($CommandsPath) { $arguments += "--commands=$((Resolve-Path -LiteralPath $CommandsPath).Path.Replace('\','/'))" }
    if ($SelectionPath) { $arguments += "--selection=$((Resolve-Path -LiteralPath $SelectionPath).Path.Replace('\','/'))" }
    Invoke-FluxGodotChecked (Get-FluxGodot) $arguments (Join-Path $logs 'run.log') -RejectWarnings
} finally {
    try {
        $env:APPDATA = $savedShowcaseRoaming
        $after = if (Test-Path -LiteralPath $profilePath) { (Get-FileHash -LiteralPath $profilePath).Hash } else { 'absent' }
        if (Test-Path -LiteralPath $logs) {
            [ordered]@{before=$profileBefore;after=$after;unchanged=($profileBefore -ceq $after);appdata_restored=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'profile-guard.json')
        }
        if ($profileBefore -cne $after) { throw 'Personal profile changed; quarantine this run.' }
    } finally { Exit-FluxEngineRun $lease }
}
