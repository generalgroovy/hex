. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw 'Python 3 is required to install the pinned export templates.' }
$destination = Get-FluxExportTemplateRoot
$url = 'https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz'
& $python.Source (Join-Path $PSScriptRoot 'fetch-export-templates.py') --url $url --size 1280486955 --destination $destination
if ($LASTEXITCODE -ne 0) { throw 'Pinned export-template installation failed.' }
Assert-FluxExportTemplates 'All' | Out-Null
Write-Output "PASS: Godot 4.7.1 Windows/Linux release templates are ready at $destination"
