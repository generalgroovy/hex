param(
    [string]$Manifest = 'res://art_batches/character_motion_v1/output/motion-common-heads-v3/manifest.json',
    [switch]$Validate,
    [string]$Capture = '',
    [int]$TimeoutSeconds = 0
)
$ErrorActionPreference = 'Stop'
$motionRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $motionRepo 'scripts/flux2-common.ps1')
if ((Get-FluxRepoRoot) -ne $motionRepo -or (& git -C $motionRepo remote get-url origin).Trim() -ne 'https://github.com/generalgroovy/hex.git') { throw 'Wrong H.E.X. checkout' }
foreach ($motionPath in @($Manifest,$Capture) | Where-Object { $_ }) {
    if ($motionPath -notmatch '^res://art_batches/character_motion_v1/output/' -or $motionPath.Contains('..') -or $motionPath.Contains('\')) { throw 'Candidate path outside contained artwork output' }
}
if ($Validate -and $Capture) { throw 'Validation and capture are separate modes' }
if ($TimeoutSeconds -eq 0) { $TimeoutSeconds = if ($Validate -or $Capture) { 180 } else { 1800 } }
$motionLease = Enter-FluxEngineRun 'full-body-motion-candidate'
$motionSavedData = $env:APPDATA
$motionProcess = $null
try {
    $motionEngine = Get-FluxGodot
    Assert-FluxGodotVersion $motionEngine | Out-Null
    $motionRun = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $motionLogs = Join-Path $motionRepo ".godot/character-motion/$motionRun"
    New-Item -ItemType Directory -Path $motionLogs | Out-Null
    $env:APPDATA = Join-Path $motionLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $motionArgs = @('--path',$motionRepo,'--script','res://art_batches/character_motion_v1/preview.gd')
    if ($Validate) { $motionArgs += '--headless' } else { $motionArgs += @('--windowed','--resolution','1280x720') }
    $motionArgs += @('--',"--manifest=$Manifest")
    if ($Validate) { $motionArgs += '--validate' }
    if ($Capture) { $motionArgs += "--capture=$Capture" }
    $motionQuoted = $motionArgs | ForEach-Object { '"'+$_.Replace('"','\"')+'"' }
    $motionStyle = if ($Validate -or $Capture) { 'Hidden' } else { 'Normal' }
    $motionProcess = Start-FluxOwnedProcess @{FilePath=$motionEngine;ArgumentList=$motionQuoted;WindowStyle=$motionStyle;RedirectStandardOutput=(Join-Path $motionLogs 'preview.log');RedirectStandardError=(Join-Path $motionLogs 'preview.err')}
    $motionDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $motionProcess.WaitForExit(250) -and [DateTime]::UtcNow -lt $motionDeadline) {
        foreach ($motionStream in @('preview.log','preview.err')) {
            $motionRecent = Get-Content (Join-Path $motionLogs $motionStream) -Tail 50 -ErrorAction SilentlyContinue
            if ($motionRecent -match 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|^ERROR:') { throw "Engine error: $motionLogs" }
        }
    }
    if (-not $motionProcess.HasExited) { throw "Motion preview timeout: $motionLogs" }
    $motionProcess.WaitForExit()
    $motionProcess.Refresh()
    $motionOutput = Get-Content (Join-Path $motionLogs 'preview.log') -Raw
    $motionError = Get-Content (Join-Path $motionLogs 'preview.err') -Raw
    Write-Output $motionOutput
    if ($motionError -or ($null -ne $motionProcess.ExitCode -and $motionProcess.ExitCode -ne 0)) { throw "Motion preview failed: $motionLogs" }
    if (($Validate -or $Capture) -and $motionOutput -notmatch 'PASS:') { throw 'Missing explicit motion preview completion' }
    Write-Output "Motion preview completed. Logs: $motionLogs. No game replacement."
} finally {
    try { if ($motionProcess -and -not $motionProcess.HasExited) { $motionProcess.Kill(); $motionProcess.WaitForExit() } }
    finally { $env:APPDATA=$motionSavedData; Exit-FluxEngineRun $motionLease }
}
