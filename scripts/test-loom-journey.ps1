param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId, [string]$PackPath = '', [switch]$Restart)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$loomLease = Enter-FluxEngineRun 'loom-player-journey'
$loomSavedAppData = $env:APPDATA
try {
    $loomRoot = Get-FluxRepoRoot
    $loomOutput = Join-Path $loomRoot "docs/verification/hex-acceptance-20260921/$RunId"
    if (Test-Path -LiteralPath $loomOutput) { throw 'Fresh RunId required' }
    New-Item -ItemType Directory -Path $loomOutput | Out-Null
    $env:APPDATA = Join-Path $loomRoot ".godot/loom-journey-$RunId/isolated-roaming"
    if (Test-Path -LiteralPath $env:APPDATA) { throw 'Fresh isolated profile required' }
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $loomScript = Join-Path $loomRoot 'tests/diagnostics/loom_player_journey.gd'
    $loomBin = Get-FluxGodot
    $loomArgs = @('--path', $loomRoot, '--script', $loomScript)
    if ($PackPath) {
        # Release EXEs disable script/path overrides; use the pinned engine for
        # instrumented PCK checks and open-native-acceptance for the actual EXE.
        $loomPack = (Resolve-Path -LiteralPath $PackPath).Path
        if ([IO.Path]::GetExtension($loomPack) -ne '.pck') { throw 'Expected a PCK' }
        $loomArgs = @('--main-pack', $loomPack, '--path', (Split-Path -Parent $loomPack), '--script', $loomScript)
    }
    $loomArgs += @('--windowed', '--resolution', '1280x720', '--fixed-fps', '120', '--', '--no-lan-discovery')
    Invoke-FluxGodotChecked $loomBin ($loomArgs + @("--output=$loomOutput/journey.json")) (Join-Path $loomOutput 'journey.log') -RejectWarnings -TimeoutSeconds 180
    if ($Restart) {
        Invoke-FluxGodotChecked $loomBin ($loomArgs + @("--output=$loomOutput/restart.json", "--resume=$loomOutput/journey.json")) (Join-Path $loomOutput 'restart.log') -RejectWarnings -TimeoutSeconds 180
    }
} finally { $env:APPDATA = $loomSavedAppData; Exit-FluxEngineRun $loomLease }
