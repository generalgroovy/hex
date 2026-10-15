# Pure request controls; no engine, filesystem writes or experiment execution.
$ErrorActionPreference = 'Stop'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'launcher-diagnostic.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$definition = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-HexDiagnosticRequest'}, $true))
if ($definition.Count -ne 1) { throw 'Expected one diagnostic request function.' }
Invoke-Expression $definition[0].Extent.Text
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runner = '.godot/iteration-20261014/performance-next/run-membership.ps1'
$output = '.godot/iteration-20261014/performance-next/runs/functional-a'
$checks = 0
function Check-Diagnostic([bool]$Okay, [string]$Label) { $script:checks++; if (-not $Okay) { throw "FAIL: $Label" } }
function Reject-Diagnostic([string]$Label, [scriptblock]$Action) { $rejected=$false; try { & $Action | Out-Null } catch {$rejected=$true}; Check-Diagnostic $rejected $Label }
$request = Get-HexDiagnosticRequest $root $runner ('a'*64) 'functional' $output ''
Check-Diagnostic ($request.runner -ceq [IO.Path]::GetFullPath((Join-Path $root $runner)) -and $request.case -ceq 'functional' -and $request.qualification_sha256 -ceq '') 'Contained explicit functional request'
$request = Get-HexDiagnosticRequest $root $runner ('a'*64) 'forward' $output ('b'*64)
Check-Diagnostic ($request.qualification_sha256 -ceq ('b'*64)) 'Timing qualifier passes as a separate pinned value'
foreach ($bad in @('../run-test.ps1','scripts/run.ps1','C:/run-test.ps1','.godot/iteration-20261014/../run-test.ps1','.godot/iteration-20261014/performance-next/nested/run-test.ps1','.godot/iteration-20261014/performance-next/run-test.cmd')) {
    Reject-Diagnostic "Reject runner $bad" { Get-HexDiagnosticRequest $root $bad ('a'*64) 'functional' $output '' }
}
foreach ($bad in @('../outside','.godot/iteration-20261014/other/runs/test-a','.godot/iteration-20261014/performance-next/runs/../test-a','.godot/iteration-20261014/performance-next/runs/nested/test-a')) {
    Reject-Diagnostic "Reject output $bad" { Get-HexDiagnosticRequest $root $runner ('a'*64) 'functional' $bad '' }
}
foreach ($bad in @('','abc',('A'*64))) { Reject-Diagnostic 'Reject unpinned runner' { Get-HexDiagnosticRequest $root $runner $bad 'functional' $output '' } }
foreach ($bad in @('','forward;whoami','--output=elsewhere','forward reverse')) { Reject-Diagnostic 'Reject extra case arguments' { Get-HexDiagnosticRequest $root $runner ('a'*64) $bad $output '' } }
Reject-Diagnostic 'Reject malformed qualification pin' { Get-HexDiagnosticRequest $root $runner ('a'*64) 'forward' $output 'passed' }
Write-Output "PASS: $checks diagnostic request assertions."
