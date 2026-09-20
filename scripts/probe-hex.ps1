param([Parameter(Mandatory)][string]$RunId, [string]$Script = 'res://tests/performance/profile_hex_snapshot_stages.gd', [string[]]$ExtraArguments = @(), [switch]$Rendered, [string]$Output = '', [string]$PackPath = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$hexLease = Enter-FluxEngineRun 'hex-probe'
$hexSavedAppData = $env:APPDATA
try {
    $hexRoot = Get-FluxRepoRoot
    $hexLogs = Join-Path $hexRoot ".godot/hex-probe-$RunId"
    if (Test-Path -LiteralPath $hexLogs) { throw 'Use a fresh RunId' }
    New-Item -ItemType Directory -Path $hexLogs | Out-Null
    $env:APPDATA = Join-Path $hexLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $hexArgs = @('--path', $hexRoot, '--script', $Script)
    if ($PackPath) {
        $hexPack = (Resolve-Path -LiteralPath $PackPath -ErrorAction Stop).Path
        if (-not (Test-Path -LiteralPath $hexPack -PathType Leaf) -or [IO.Path]::GetExtension($hexPack) -ne '.pck') { throw 'Expected an existing PCK' }
        if (-not [IO.Path]::IsPathRooted($Script)) { throw 'Mounted historical PCK requires an external absolute capture script' }
        $hexArgs = @('--main-pack', $hexPack, '--path', (Split-Path -Parent $hexPack), '--script', $Script)
    }
    if (-not $Rendered) { $hexArgs += '--headless' } else { $hexArgs += @('--windowed','--resolution','1280x720','--fixed-fps','120') }
    if (-not $Output) { $Output = "res://.godot/hex-snapshot-stages-$RunId.json" }; $hexArgs += @('--', "--output=$Output") + $ExtraArguments
    Invoke-FluxGodotChecked (Get-FluxGodot) $hexArgs (Join-Path $hexLogs 'probe.log') -RejectWarnings -TimeoutSeconds 900
} finally { $env:APPDATA = $hexSavedAppData; Exit-FluxEngineRun $hexLease }

