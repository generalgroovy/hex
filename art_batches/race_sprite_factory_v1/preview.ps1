param(
    [string]$Manifest = 'res://art_batches/race_sprite_factory_v1/output/seakin-v3/manifest.json',
    [switch]$Validate,
    [switch]$TestContract,
    [string]$Capture = '',
    [ValidateRange(0, 1800)][int]$TimeoutSeconds = 0
)
$ErrorActionPreference = 'Stop'
$previewRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $previewRepo 'scripts/flux2-common.ps1')
if ((Get-FluxRepoRoot) -ne $previewRepo) { throw 'Preview checkout identity mismatch' }
$previewRemote = (& git -C $previewRepo remote get-url origin).Trim()
if ($previewRemote -ne 'https://github.com/generalgroovy/hex.git') { throw 'Expected generalgroovy/hex checkout' }
if (($Validate -or $TestContract) -and $Capture) { throw 'Headless validation and rendering capture are separate modes' }
if ($TimeoutSeconds -eq 0) {
    $TimeoutSeconds = if ($TestContract) { 30 } elseif ($Validate -or $Capture) { 120 } else { 600 }
}
# Narrow res:// targets; reject path traversal and junction/symlink ancestors.
foreach ($previewResource in @($Manifest, $Capture) | Where-Object { $_ }) {
    if ($previewResource -notmatch '^res://(?:\.godot/race-sprite-candidates|art_batches/race_sprite_factory_v1/output)/' -or $previewResource.Contains('..') -or $previewResource.Contains('\')) { throw 'Preview paths must be contained candidate resource paths' }
    $previewPhysical = [IO.Path]::GetFullPath((Join-Path $previewRepo $previewResource.Substring(6)))
    $previewCursor = $previewPhysical
    while ($previewCursor -and $previewCursor.Length -ge $previewRepo.Length) {
        if ((Test-Path -LiteralPath $previewCursor) -and (((Get-Item -LiteralPath $previewCursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'Preview targets must not contain links or junctions' }
        $previewCursor = [IO.Path]::GetDirectoryName($previewCursor)
    }
}
$previewLease = Enter-FluxEngineRun 'race-sprite-candidate-lab'
$previewSavedAppData = $env:APPDATA
$previewProcess = $null
try {
    $previewGodot = Get-FluxGodot
    Assert-FluxGodotVersion $previewGodot | Out-Null
    $previewRunId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $previewLogs = Join-Path $previewRepo ".godot/race-sprite-preview/$previewRunId"
    New-Item -ItemType Directory -Path $previewLogs | Out-Null
    $env:APPDATA = Join-Path $previewLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $previewScript = if ($TestContract) { 'res://art_batches/race_sprite_factory_v1/test_preview_contract.gd' } else { 'res://art_batches/race_sprite_factory_v1/preview.gd' }
    $previewArgs = @('--path', $previewRepo, '--script', $previewScript)
    if ($Validate -or $TestContract) { $previewArgs += '--headless' }
    else { $previewArgs += @('--windowed', '--resolution', '1280x800') }
    $previewArgs += @('--', "--manifest=$Manifest")
    if ($Validate) { $previewArgs += '--validate' }
    if ($Capture) { $previewArgs += "--capture=$Capture" }
    $previewQuoted = $previewArgs | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    $previewStyle = if ($Validate -or $TestContract -or $Capture) { 'Hidden' } else { 'Normal' }
    # Visible window is intentional: this launcher is the requested interactive art lab.
    $previewProcess = Start-FluxOwnedProcess @{FilePath=$previewGodot; ArgumentList=$previewQuoted; RedirectStandardOutput=(Join-Path $previewLogs 'preview.log'); RedirectStandardError=(Join-Path $previewLogs 'preview.err'); WindowStyle=$previewStyle}
    $previewDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $previewProcess.WaitForExit(250) -and [DateTime]::UtcNow -lt $previewDeadline) {
        # A failed script can leave a live SceneTree. Fail promptly, then the
        # finally block stops only this journalled child and releases its lease.
        foreach ($previewStreamName in @('preview.err', 'preview.log')) {
            $previewStreamPath = Join-Path $previewLogs $previewStreamName
            if (Test-Path -LiteralPath $previewStreamPath) {
                $previewRecentOutput = Get-Content -LiteralPath $previewStreamPath -Tail 80 -ErrorAction SilentlyContinue
                if ($previewRecentOutput -match 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|^ERROR:') {
                    throw "Candidate preview emitted an engine/script error. Inspect $previewLogs"
                }
            }
        }
    }
    if (-not $previewProcess.HasExited) { throw "Candidate preview watchdog reached. Logs: $previewLogs" }
    $previewProcess.WaitForExit()
    $previewProcess.Refresh()
    $previewStdout = Get-Content (Join-Path $previewLogs 'preview.log') -Raw
    $previewStderr = Get-Content (Join-Path $previewLogs 'preview.err') -Raw
    Write-Output $previewStdout
    if ($previewStderr -or $previewStdout -match 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' -or ($null -ne $previewProcess.ExitCode -and $previewProcess.ExitCode -ne 0)) { throw "Candidate preview failed. Inspect $previewLogs" }
    if (($Validate -or $TestContract -or $Capture) -and $previewStdout -notmatch 'PASS:') { throw "Missing explicit completion marker. Inspect $previewLogs" }
    Write-Output "Candidate art lab closed. Logs: $previewLogs. No production approval or promotion."
} finally {
    try { if ($null -ne $previewProcess -and -not $previewProcess.HasExited) { $previewProcess.Kill(); $previewProcess.WaitForExit() } }
    finally { $env:APPDATA = $previewSavedAppData; Exit-FluxEngineRun $previewLease }
}
