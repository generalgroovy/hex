param(
    [Parameter(Mandatory = $true)][string]$Sheet,
    [ValidateSet('View', 'Check', 'Export')][string]$Mode = 'View'
)
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$workflowLease = Enter-FluxEngineRun 'review-character-sheet'
try {

$reviewRepo = Get-FluxRepoRoot
if (-not (Test-Path -LiteralPath $Sheet -PathType Leaf)) { throw "Missing candidate PNG: $Sheet" }
$reviewSheet = (Resolve-Path -LiteralPath $Sheet).Path
$reviewId = [Guid]::NewGuid().ToString('N')
$reviewRoot = Join-Path $reviewRepo '.godot\character-qa'
New-Item -ItemType Directory -Path $reviewRoot -Force | Out-Null
$reviewLog = Join-Path $reviewRoot ($reviewId + '.log')
$reviewArgs = @('--path', $reviewRepo, '--script', 'res://tests/visual/character_sheet_qa.gd', '--', ('--sheet=' + $reviewSheet), ('--mode=' + $Mode.ToLowerInvariant()))
if ($Mode -eq 'Check') { $reviewArgs = @('--headless') + $reviewArgs }
if ($Mode -eq 'Export') { $reviewArgs += '--output=res://.godot/character-qa/' + $reviewId }
$reviewEngine = Get-FluxGodot
if ($Mode -eq 'View') {
    # This explicit View command opens the interactive review window only.
    $reviewQuoted = $reviewArgs | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    $reviewProcess = Start-FluxOwnedProcess @{FilePath=$reviewEngine; ArgumentList=$reviewQuoted; WindowStyle='Normal'}
    Write-Output "Character QA viewer PID $($reviewProcess.Id). Source is read-only; no game saves or network."
    try { while (-not $reviewProcess.WaitForExit(250)) { } }
    finally { if (-not $reviewProcess.HasExited) { $reviewProcess.Kill(); $reviewProcess.WaitForExit() } }
} else {
    Invoke-FluxGodotChecked $reviewEngine $reviewArgs $reviewLog -RejectWarnings
    Write-Output "QA log: $reviewLog"
    if ($Mode -eq 'Export') { Write-Output "Review images and report: $(Join-Path $reviewRoot $reviewId)" }
}

} finally { Exit-FluxEngineRun $workflowLease }
