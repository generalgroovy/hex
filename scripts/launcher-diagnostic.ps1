[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Runner,
    [Parameter(Mandatory)][string]$RunnerSha256,
    [Parameter(Mandatory)][string]$Case,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$QualificationSha256 = '',
    [switch]$Inspect
)

# Explicit developer diagnostics use the desktop front door. The pinned runner
# owns its fixed cases, input pins, engine lease, isolated profile and receipts.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HexDiagnosticRequest([string]$Root, [string]$RunnerPath, [string]$RunnerPin, [string]$CaseName, [string]$OutputPath, [string]$QualificationPin) {
    if ($RunnerPin -cnotmatch '^[a-f0-9]{64}$' -or ($QualificationPin -and $QualificationPin -cnotmatch '^[a-f0-9]{64}$')) { throw 'Diagnostics require exact lowercase SHA-256 pins.' }
    if ($CaseName -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'Select one named diagnostic case without shell arguments.' }
    if ($RunnerPath -cnotmatch '^\.godot/iteration-[0-9]{8}/[a-z0-9]+(?:-[a-z0-9]+)*/run-[a-z0-9]+(?:-[a-z0-9]+)*\.ps1$') { throw 'Select a prepared runner inside one ignored diagnostic directory.' }
    $experiment = $RunnerPath.Substring(0, $RunnerPath.LastIndexOf('/'))
    if ($OutputPath -cnotmatch ('^' + [regex]::Escape($experiment) + '/runs/[a-z0-9]+(?:-[a-z0-9]+)*$')) { throw 'Diagnostic output must be a named fresh run in the selected experiment.' }
    return [pscustomobject]@{
        runner = [IO.Path]::GetFullPath((Join-Path $Root $RunnerPath))
        runner_sha256 = $RunnerPin
        case = $CaseName
        output = [IO.Path]::GetFullPath((Join-Path $Root $OutputPath))
        qualification_sha256 = $QualificationPin
    }
}

function Assert-HexDiagnosticPhysicalPath([string]$Path) {
    $ancestor = [IO.Path]::GetFullPath($Path)
    while ($ancestor) {
        if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Diagnostic paths must not traverse a junction or symbolic link.' }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
}

$diagnosticRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$request = Get-HexDiagnosticRequest $diagnosticRoot $Runner $RunnerSha256 $Case $OutputDirectory $QualificationSha256
Assert-HexDiagnosticPhysicalPath $request.runner
Assert-HexDiagnosticPhysicalPath $request.output
if (-not (Test-Path -LiteralPath $request.runner -PathType Leaf)) { throw 'The prepared diagnostic runner is absent.' }
if (Test-Path -LiteralPath $request.output) { throw 'Diagnostic output already exists; preserve it and select a fresh run.' }
if ((Get-FileHash -LiteralPath $request.runner).Hash.ToLowerInvariant() -cne $request.runner_sha256) { throw 'Diagnostic runner bytes differ from the reviewed pin.' }
$pointerPath = Join-Path $diagnosticRoot 'docs/current-delivery.json'
$pointerPin = (Get-FileHash -LiteralPath $pointerPath).Hash
if ($Inspect) {
    [ordered]@{mode='Diagnostic';runner=$request.runner;runner_sha256=$request.runner_sha256;case=$request.case;output=$request.output;qualification_sha256=$request.qualification_sha256;default_selection_unchanged=$true;scope='Prepared developer diagnostic only; inspection launches no engine.'} | ConvertTo-Json
    return
}
$runnerArguments = @{Case=$request.case;OutputDirectory=$request.output}
if ($request.qualification_sha256) { $runnerArguments.QualificationSha256 = $request.qualification_sha256 }
try { & $request.runner @runnerArguments }
finally {
    if ((Get-FileHash -LiteralPath $request.runner).Hash.ToLowerInvariant() -cne $request.runner_sha256) { throw 'Diagnostic runner changed during execution.' }
    if ((Get-FileHash -LiteralPath $pointerPath).Hash -cne $pointerPin) { throw 'Diagnostic changed the qualified delivery selection.' }
}
