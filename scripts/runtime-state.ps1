param(
    [string]$PackPath = '',
    [string]$OutputPath = ''
)
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$workflowLease = Enter-FluxEngineRun 'runtime-state'
try {

$repoRoot = Get-FluxRepoRoot
$godotBin = Get-FluxGodot
$reportRoot = Join-Path $repoRoot '.godot\reports'
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$runtimeRoot = $repoRoot
$arguments = @('--headless')
if ($PackPath) {
    if (-not [System.IO.Path]::IsPathRooted($PackPath)) { $PackPath = Join-Path $repoRoot $PackPath }
    $PackPath = [System.IO.Path]::GetFullPath($PackPath)
    if (-not (Test-Path -LiteralPath $PackPath -PathType Leaf)) { throw "Missing runtime pack: $PackPath" }
    # Do not let a missing exported resource fall back to the checkout.
    $runtimeRoot = Split-Path -Parent $PackPath
    $arguments += @('--main-pack', $PackPath)
}
$arguments += @('--path', $runtimeRoot, '--script', 'res://scripts/runtime-state.gd')
$runtimeLogRoot = Join-Path $reportRoot ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runtimeLogRoot -Force | Out-Null
$logPath = Join-Path $runtimeLogRoot $(if ($PackPath) { 'runtime-pack.log' } else { 'runtime-source.log' })
Invoke-FluxGodotChecked $godotBin $arguments $logPath -RejectWarnings | Out-Null
$records = @(Get-Content -LiteralPath $logPath | Where-Object { $_.StartsWith('FLUX_RUNTIME_STATE=') })
if ($records.Count -ne 1) { throw 'Runtime must emit exactly one validated content summary.' }
$summary = $records[0].Substring('FLUX_RUNTIME_STATE='.Length) | ConvertFrom-Json
if ($summary.schema_version -ne 1) { throw 'Unsupported runtime summary schema.' }
$evidence = [ordered]@{
    schema_version = 1
    source_kind = if ($PackPath) { 'exported_pack' } else { 'source' }
    pack_sha256 = if ($PackPath) { Get-FluxFileSha256 $PackPath } else { $null }
    state = $summary
}
if (-not $OutputPath) { $OutputPath = Join-Path $reportRoot 'runtime-content.json' }
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $repoRoot $OutputPath }
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
[System.IO.File]::WriteAllText($OutputPath, ($evidence | ConvertTo-Json -Depth 12) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
Write-Output "PASS: executed runtime content summary written to $OutputPath"

} finally { Exit-FluxEngineRun $workflowLease }
