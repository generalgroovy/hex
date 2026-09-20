param(
    [switch]$RequireExportTemplates,
    [ValidateSet('Windows', 'Linux', 'All')][string]$ExportTarget = 'All'
)
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$repoRoot = Get-FluxRepoRoot
$godotBin = Get-FluxGodot
$actual = Assert-FluxGodotVersion $godotBin
foreach ($required in @('project.godot', 'scenes\bootstrap\bootstrap.tscn', 'tests\run_all.gd', 'export_presets.cfg')) {
    $path = Join-Path $repoRoot $required
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing $required" }
}
$templates = Get-FluxExportTemplateRoot
$hasTemplates = Test-Path -LiteralPath $templates -PathType Container
if ($RequireExportTemplates) { $templates = Assert-FluxExportTemplates $ExportTarget }
Write-Output "OK: Godot $actual and HEX source foundation are present."
Write-Output ("Export templates: " + $(if ($RequireExportTemplates) { "$ExportTarget ready at $templates" } elseif ($hasTemplates) { $templates } else { 'missing (source run/test remains available)' }))
