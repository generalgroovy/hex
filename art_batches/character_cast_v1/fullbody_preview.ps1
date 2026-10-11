param(
    [string]$Manifest = 'res://art_batches/character_cast_v1/output/fullbody-v2/manifest.json',
    [switch]$Validate,
    [switch]$TestContract,
    [string]$Capture = '',
    [ValidateRange(0, 63)][int]$Character = 0,
    [ValidateRange(0, 1800)][int]$TimeoutSeconds = 0
)
$ErrorActionPreference = 'Stop'
$galleryRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $galleryRepo 'scripts/flux2-common.ps1')
if ((Get-FluxRepoRoot) -ne $galleryRepo) { throw 'Gallery checkout identity mismatch' }
$galleryRemote = (& git -C $galleryRepo remote get-url origin).Trim()
if ($galleryRemote -ne 'https://github.com/generalgroovy/hex.git') { throw 'Expected generalgroovy/hex checkout' }
if (($Validate -or $TestContract) -and $Capture) { throw 'Validation and rendering capture are separate modes' }
if ($Validate -and $TestContract) { throw 'Choose validation or contract tests, not both' }
if ($TimeoutSeconds -eq 0) { $TimeoutSeconds = if ($TestContract) { 30 } elseif ($Validate -or $Capture) { 120 } else { 600 } }
foreach ($galleryResource in @($Manifest, $Capture) | Where-Object { $_ }) {
    if ($galleryResource -notmatch '^res://art_batches/character_cast_v1/output/' -or $galleryResource.Contains('..') -or $galleryResource.Contains('\')) { throw 'Gallery paths must be contained staged candidate paths' }
    $galleryPhysical = [IO.Path]::GetFullPath((Join-Path $galleryRepo $galleryResource.Substring(6)))
    $galleryCursor = $galleryPhysical
    while ($galleryCursor -and $galleryCursor.Length -ge $galleryRepo.Length) {
        if ((Test-Path -LiteralPath $galleryCursor) -and (((Get-Item -LiteralPath $galleryCursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'Gallery target paths must not contain links or junctions' }
        $galleryCursor = [IO.Path]::GetDirectoryName($galleryCursor)
    }
}
$galleryLease = Enter-FluxEngineRun 'full-body-candidate-gallery'
$gallerySavedAppData = $env:APPDATA
$galleryProcess = $null
try {
    $galleryGodot = Get-FluxGodot
    Assert-FluxGodotVersion $galleryGodot | Out-Null
    $galleryRunId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $galleryLogs = Join-Path $galleryRepo ".godot/fullbody-preview/$galleryRunId"
    New-Item -ItemType Directory -Path $galleryLogs | Out-Null
    $env:APPDATA = Join-Path $galleryLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $galleryScript = if ($TestContract) { 'res://art_batches/character_cast_v1/test_fullbody_preview.gd' } else { 'res://art_batches/character_cast_v1/fullbody_preview.gd' }
    $galleryArgs = @('--path', $galleryRepo, '--script', $galleryScript)
    if ($Validate -or $TestContract) { $galleryArgs += '--headless' }
    else { $galleryArgs += @('--windowed', '--resolution', '1280x800') }
    $galleryArgs += @('--', "--manifest=$Manifest", "--character=$Character")
    if ($Validate) { $galleryArgs += '--validate' }
    if ($Capture) { $galleryArgs += "--capture=$Capture" }
    $galleryQuoted = $galleryArgs | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    # The visible branch is only the explicitly requested interactive art tool.
    # Capture stays a hidden native rendering child; no root.hide() render bug.
    $galleryStyle = if ($Validate -or $TestContract -or $Capture) { 'Hidden' } else { 'Normal' }
    $galleryProcess = Start-FluxOwnedProcess @{FilePath=$galleryGodot; ArgumentList=$galleryQuoted; RedirectStandardOutput=(Join-Path $galleryLogs 'gallery.log'); RedirectStandardError=(Join-Path $galleryLogs 'gallery.err'); WindowStyle=$galleryStyle}
    $galleryDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $galleryProcess.WaitForExit(250) -and [DateTime]::UtcNow -lt $galleryDeadline) {
        foreach ($galleryStream in @('gallery.err', 'gallery.log')) {
            $galleryStreamPath = Join-Path $galleryLogs $galleryStream
            if (Test-Path -LiteralPath $galleryStreamPath) {
                $galleryRecent = Get-Content -LiteralPath $galleryStreamPath -Tail 80 -ErrorAction SilentlyContinue
                if ($galleryRecent -match 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|^ERROR:') { throw "Gallery emitted an engine/script error. Inspect $galleryLogs" }
            }
        }
    }
    if (-not $galleryProcess.HasExited) { throw "Gallery watchdog reached. Logs: $galleryLogs" }
    $galleryProcess.WaitForExit()
    $galleryProcess.Refresh()
    $galleryStdout = Get-Content (Join-Path $galleryLogs 'gallery.log') -Raw
    $galleryStderr = Get-Content (Join-Path $galleryLogs 'gallery.err') -Raw
    Write-Output $galleryStdout
    if ($galleryStderr -or $galleryStdout -match 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' -or ($null -ne $galleryProcess.ExitCode -and $galleryProcess.ExitCode -ne 0)) { throw "Gallery failed. Inspect $galleryLogs" }
    if (($Validate -or $TestContract -or $Capture) -and $galleryStdout -notmatch 'PASS:') { throw "Missing explicit gallery completion marker. Inspect $galleryLogs" }
    Write-Output "Full-body idle gallery closed. Logs: $galleryLogs. No animation acceptance or production promotion."
} finally {
    try { if ($null -ne $galleryProcess -and -not $galleryProcess.HasExited) { $galleryProcess.Kill(); $galleryProcess.WaitForExit() } }
    finally { $env:APPDATA = $gallerySavedAppData; Exit-FluxEngineRun $galleryLease }
}
