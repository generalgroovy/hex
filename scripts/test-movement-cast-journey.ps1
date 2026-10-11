param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId, [string]$PackPath = '', [switch]$Advanced)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$movementLease = Enter-FluxEngineRun 'movement-cast-journey'
$movementSavedAppData = $env:APPDATA
try {
    $movementRoot = Get-FluxRepoRoot
    $movementPrefix = if ($Advanced) { 'movement-advanced' } else { 'movement-cast' }
    $movementOutput = Join-Path $movementRoot ".godot/$movementPrefix-$RunId"
    if (Test-Path -LiteralPath $movementOutput) { throw 'Fresh RunId required' }
    New-Item -ItemType Directory -Path $movementOutput | Out-Null
    $env:APPDATA = Join-Path $movementOutput 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $movementScript = Join-Path $movementRoot $(if ($Advanced) { 'tests/diagnostics/movement_advanced_journey.gd' } else { 'tests/diagnostics/movement_cast_journey.gd' })
    $movementArgs = @('--headless', '--path', $movementRoot, '--script', $movementScript)
    if ($PackPath) {
        $movementPack = (Resolve-Path -LiteralPath $PackPath -ErrorAction Stop).Path
        if ([IO.Path]::GetExtension($movementPack) -ne '.pck') { throw 'Expected a PCK' }
        $movementArgs = @('--headless', '--main-pack', $movementPack, '--path', (Split-Path -Parent $movementPack), '--script', $movementScript)
    }
    $movementArgs += @('--', '--no-lan-discovery', "--output=$movementOutput/receipt.json", "--isolated-root=$movementOutput")
    Invoke-FluxGodotChecked (Get-FluxGodot) $movementArgs (Join-Path $movementOutput 'journey.log') -RejectWarnings -TimeoutSeconds 300
} finally { $env:APPDATA = $movementSavedAppData; Exit-FluxEngineRun $movementLease }
