# Pure source/selection/receipt regressions. No engine, subprocess or file writes.
$ErrorActionPreference = 'Stop'
$ciTestRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'ci-focused-suites.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
foreach ($name in @('Get-HexRegisteredSuiteIds', 'Assert-HexSuiteSelection', 'Get-HexPrSuitePlan', 'Assert-HexFocusedReceipt')) {
    $definitions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true))
    if ($definitions.Count -ne 1) { throw "Expected one CI function $name" }
    Invoke-Expression $definitions[0].Extent.Text
}
$checks = 0
function Check-Ci([bool]$Condition, [string]$Label) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Label" }
}
function Reject-Ci([string]$Label, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Check-Ci $rejected $Label
}
function Copy-Ci([object]$Value) { return $Value | ConvertTo-Json -Depth 12 | ConvertFrom-Json }

$source = Get-Content -Raw -LiteralPath (Join-Path $ciTestRoot 'tests/run_all.gd')
$registry = @(Get-HexRegisteredSuiteIds $source)
$plan = Get-HexPrSuitePlan $registry
Check-Ci ($plan.required_ids.Count -eq 41 -and $plan.shards.Count -eq 4 -and (@($plan.shards | ForEach-Object {$_.suites.Count}) -join ',') -ceq '3,4,10,24') 'Explicit 41-suite policy has four bounded 3/4/10/24 runs'
foreach ($id in @('completed-step-profile', 'defeated-pending-capture', 'wellspring-async-terrain-stream', 'cast-startup-witness', 'player-camera-rig', 'performance-presentation', 'wellspring-illustrated-kit')) {
    Check-Ci ($plan.required_ids -ccontains $id) "New authority/loading regression is selected: $id"
}
Check-Ci ($registry -ccontains 'current-world-replay' -and $registry -ccontains 'session-transport') 'Nested replay/network suite paths are recognized'
Reject-Ci 'Duplicate registered IDs are refused' { Get-HexRegisteredSuiteIds ($source.Replace('const SUITES: Array[Script] = [', "const SUITES: Array[Script] = [`n`tpreload(`"res://tests/unit/test_completed_step_profile.gd`"),")) }
Reject-Ci 'Unrecognized commented registry lines are not silently ignored' { Get-HexRegisteredSuiteIds ($source.Replace('const SUITES: Array[Script] = [', "const SUITES: Array[Script] = [`n`t# hidden suite")) }
Reject-Ci 'Stable ID transformation drift is refused' { Get-HexRegisteredSuiteIds ($source.Replace('trim_prefix("test_")', 'trim_prefix("other_")')) }
Reject-Ci 'Missing registry is refused' { Get-HexRegisteredSuiteIds '' }
Reject-Ci 'Empty required selection is refused' { Assert-HexSuiteSelection $registry @() $plan.shards }
Reject-Ci 'Duplicate policy ID is refused' { Assert-HexSuiteSelection $registry ($plan.required_ids + $plan.required_ids[0]) $plan.shards }
Reject-Ci 'Unknown required ID is refused' { Assert-HexSuiteSelection $registry ($plan.required_ids + 'unknown-suite') $plan.shards }
Reject-Ci 'Empty shard list is refused' { Assert-HexSuiteSelection $registry $plan.required_ids @() }
foreach ($case in @(
    @{ label = 'missing selected ID'; change = {param($p) $p.shards[0].suites = @($p.shards[0].suites | Select-Object -Skip 1)} }
    @{ label = 'empty shard'; change = {param($p) $p.shards[0].suites = @()} }
    @{ label = 'duplicate shard'; change = {param($p) $p.shards[1].name = $p.shards[0].name} }
    @{ label = 'extra selected ID'; change = {param($p) $p.shards[0].suites += 'unknown-suite'} }
    @{ label = 'repeated selected ID'; change = {param($p) $p.shards[0].suites += $p.shards[1].suites[0]} }
    @{ label = 'blank selected ID'; change = {param($p) $p.shards[0].suites += ''} }
    @{ label = 'case-folded selected ID'; change = {param($p) $p.shards[0].suites[0] = $p.shards[0].suites[0].ToUpperInvariant()} }
)) {
    $changed = Copy-Ci $plan
    & $case.change $changed
    Reject-Ci $case.label { Assert-HexSuiteSelection $registry $changed.required_ids $changed.shards }
}

$requested = @('second', 'first')
$fixtureRegistry = @('first', 'unselected', 'second')
$log = "Godot fixture`nfirst: 3 assertions, 0 failures`nSUITE TIMING: first 1 ms`nsecond: 4 assertions, 0 failures`nSUITE TIMING: second 2 ms`nPASS: 2 selected FLUX2 headless suite(s): second,first`n"
$receipt = [pscustomobject]@{
    schema_version = 1; tier = 'focused'; result = 'passed'; failure = $null; stderr_bytes = 0
    requested_suite_ids = $requested
    supervision = [pscustomobject]@{suite_timeout_seconds = 180}
    executed = [pscustomobject]@{
        deterministic_suite_runner = $true; suite_count = 2; assertion_count = 7
        suites = @([pscustomobject]@{id = 'first'; assertions = 3; failures = 0}, [pscustomobject]@{id = 'second'; assertions = 4; failures = 0})
    }
}
Assert-HexFocusedReceipt $receipt $requested $fixtureRegistry $log
Check-Ci $true 'Requested order and actual registry order validate independently'
Assert-HexFocusedReceipt $receipt $requested $fixtureRegistry ($log.Replace("`n", "`r`n"))
Check-Ci $true 'Windows log newlines preserve exact selection validation'
foreach ($case in @(
    @{ label = 'fallback Full receipt'; change = {param($r) $r.tier = 'full'} }
    @{ label = 'failed receipt'; change = {param($r) $r.result = 'failed'} }
    @{ label = 'empty request'; change = {param($r) $r.requested_suite_ids = @()} }
    @{ label = 'wrong request order'; change = {param($r) $r.requested_suite_ids = @('first', 'second')} }
    @{ label = 'missing result'; change = {param($r) $r.executed.suites = @($r.executed.suites[0])} }
    @{ label = 'extra result'; change = {param($r) $r.executed.suites += $r.executed.suites[0]} }
    @{ label = 'wrong executed order'; change = {param($r) $r.executed.suites = @($r.executed.suites[1], $r.executed.suites[0])} }
    @{ label = 'wrong result count'; change = {param($r) $r.executed.suite_count = 3} }
    @{ label = 'partial assertions'; change = {param($r) $r.executed.suites[0].assertions = 2} }
    @{ label = 'failed assertion'; change = {param($r) $r.executed.suites[0].failures = 1} }
    @{ label = 'wrong assertion sum'; change = {param($r) $r.executed.assertion_count = 8} }
    @{ label = 'missing suite execution'; change = {param($r) $r.executed.deterministic_suite_runner = $false} }
    @{ label = 'stderr diagnostics'; change = {param($r) $r.stderr_bytes = 1} }
    @{ label = 'relaxed supervision'; change = {param($r) $r.supervision.suite_timeout_seconds = 181} }
)) {
    $changed = Copy-Ci $receipt
    & $case.change $changed
    Reject-Ci $case.label { Assert-HexFocusedReceipt $changed $requested $fixtureRegistry $log }
}
foreach ($changedLog in @(
    $log.Replace('first: 3 assertions, 0 failures', 'first: 3 assertions, 1 failures'),
    $log.Replace('SUITE TIMING: first 1 ms', 'SUITE TIMING: unknown 1 ms'),
    $log.Replace('PASS: 2 selected FLUX2 headless suite(s): second,first', 'PASS: all FLUX2 headless suites'),
    $log.Replace('second: 4 assertions, 0 failures', ''),
    ($log + "first: 3 assertions, 0 failures`n"),
    ($log + "PASS: all FLUX2 headless suites`n")
)) { Reject-Ci 'Raw result/timing/success drift is refused' { Assert-HexFocusedReceipt $receipt $requested $fixtureRegistry $changedLog } }
Write-Output "PASS: $checks source-only PR selection assertions."
