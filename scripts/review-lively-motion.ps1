param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$motionLease = Enter-FluxEngineRun 'review-lively-motion'
$savedMotionRoaming = $env:APPDATA
try {
    $motionRoot = Get-FluxRepoRoot
    $motionOutput = Join-Path $motionRoot ".godot/lively-motion-$RunId"
    if (Test-Path -LiteralPath $motionOutput) { throw 'Fresh motion review RunId required' }
    New-Item -ItemType Directory -Path $motionOutput | Out-Null
    $env:APPDATA = Join-Path $motionOutput 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check
    $motionGodot = Get-FluxGodot
    foreach ($effects in @('normal', 'reduced')) {
        $motionArguments = @('--path', $motionRoot, '--script', 'res://tests/visual/capture_fluid_motion.gd', '--', "--output=res://.godot/fluid-motion-$RunId-$effects", '--refined')
        if ($effects -eq 'reduced') { $motionArguments += '--reduced' }
        Invoke-FluxGodotChecked $motionGodot $motionArguments (Join-Path $motionOutput "$effects.log") -RejectWarnings -TimeoutSeconds 300
    }
    Invoke-FluxGodotChecked $motionGodot @('--path', $motionRoot, '--script', 'res://tests/visual/capture_fullbody_cast.gd', '--', "--output=res://.godot/fullbody-capture-$RunId") (Join-Path $motionOutput 'roster.log') -RejectWarnings -TimeoutSeconds 300
    # CPU pose submission only, explicitly not GPU/rendered or whole-game timing.
    Invoke-FluxGodotChecked $motionGodot @('--headless', '--path', $motionRoot, '--script', 'res://tests/performance/profile_character_stream.gd', '--', "--output=res://.godot/character-stream-$RunId.json", '--dynamic') (Join-Path $motionOutput 'pose-cpu.log') -RejectWarnings -TimeoutSeconds 300
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check
} finally {
    $env:APPDATA = $savedMotionRoaming
    Exit-FluxEngineRun $motionLease
}
