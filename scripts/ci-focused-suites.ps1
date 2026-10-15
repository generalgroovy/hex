param([string]$Shard = '', [string]$ReceiptPath = '')

# Source-only PR selection and receipt validation. Engine execution stays in test.ps1.
$ErrorActionPreference = 'Stop'

function Get-HexRegisteredSuiteIds([string]$Source) {
    $blocks = [regex]::Matches($Source, '(?ms)^const SUITES: Array\[Script\] = \[\r?\n(.*?)^\]')
    if ($blocks.Count -ne 1) { throw 'Expected one explicit SUITES registry.' }
    $ids = [Collections.Generic.List[string]]::new()
    foreach ($line in ($blocks[0].Groups[1].Value -split '\r?\n')) {
        if (-not $line.Trim()) { continue }
        if ($line -cnotmatch '^\s*preload\("res://tests/(?:[a-z0-9_]+/)*test_([a-z0-9_]+)\.gd"\),\s*$') {
            throw "Unrecognized suite registry entry: $line"
        }
        $id = $Matches[1].Replace('_', '-')
        if ($ids.Contains($id)) { throw "Duplicate registered suite ID: $id" }
        $ids.Add($id)
    }
    if ($ids.Count -eq 0) { throw 'Suite registry is empty.' }
    # Keep this source-only parser tied to the runner's actual stable-ID rule.
    $rule = 'return filename.trim_prefix("test_").replace("_", "-")'
    if (-not $Source.Contains($rule)) { throw 'Runner stable-ID rule changed; review the CI parser.' }
    return $ids.ToArray()
}

function Assert-HexSuiteSelection([string[]]$Registry, [string[]]$Required, [object[]]$Shards) {
    if ($Required.Count -eq 0 -or $Shards.Count -eq 0) { throw 'PR selection and shards must be nonempty.' }
    $requiredSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($id in $Required) {
        if ($id -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or -not $requiredSet.Add($id)) { throw "Invalid or duplicate required ID: $id" }
        if ($Registry -cnotcontains $id) { throw "Unregistered required ID: $id" }
    }
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $selected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $Shards) {
        if ($entry.name -isnot [string] -or $entry.name -cnotmatch '^[a-z]+(?:-[a-z]+)*$' -or -not $names.Add($entry.name)) { throw 'Invalid or duplicate shard name.' }
        if (@($entry.suites).Count -eq 0) { throw "Empty shard: $($entry.name)" }
        foreach ($id in $entry.suites) {
            if ($id -isnot [string] -or -not $requiredSet.Contains($id) -or -not $selected.Add($id)) { throw "Unexpected or repeated selected ID: $id" }
        }
    }
    if (-not $selected.SetEquals($requiredSet)) { throw 'PR shards omit required suite IDs.' }
}

function Get-HexPrSuitePlan([string[]]$Registry) {
    # The policy inventory is independent of partitioning so a shard edit cannot
    # silently remove a regression. Review both explicitly when changing scope.
    $required = @(
        'runtime-build-identity', 'input-router', 'player-preferences',
        'identity-perks', 'elemental-spell-expansion', 'element-garden-exhibition',
        'local-navigation', 'spell-testing-tools', 'demo-result-integration',
        'team-replication', 'projectile-speed-policy', 'hex-round-result',
        'signature-progression', 'signature-rival', 'signature-recovery',
        'session-transport', 'session-admission-deadline', 'district-practice-coach',
        'paid-field-rendering', 'compact-combat-hud', 'cartoon-champion-presenter',
        'pixel-cast-continuity', 'element-delivery-presentation', 'wellspring-terrain-stream',
        'retained-campus-canvas', 'current-world-replay', 'diagnostic-replay',
        'spell-inspector', 'range-target-scenario', 'element-audio', 'hex-avoidance-feedback',
        'completed-step-profile', 'defeated-pending-capture', 'wellspring-async-terrain-stream', 'cast-startup-witness',
        'player-camera-rig', 'performance-presentation', 'wellspring-illustrated-kit',
        'signature-circuit', 'signature-circuit-integration', 'wellspring-map'
    )
    # Moving performance-presentation to arrival balances the Full7804 basis
    # at about 74/67/85 seconds. Recent local suites are slower; these are only
    # partitioning hints, not bounds. test.ps1 retains its 180-second limit.
    $shards = @(
        [pscustomobject]@{ name = 'player-loop'; suites = @('signature-circuit', 'signature-circuit-integration', 'wellspring-map') }
        [pscustomobject]@{ name = 'arrival'; suites = @('element-garden-exhibition', 'local-navigation', 'current-world-replay', 'performance-presentation') }
        [pscustomobject]@{ name = 'authority'; suites = @(
            'completed-step-profile', 'defeated-pending-capture', 'cast-startup-witness', 'identity-perks',
            'elemental-spell-expansion', 'team-replication', 'projectile-speed-policy',
            'hex-round-result', 'session-transport', 'session-admission-deadline'
        ) }
        [pscustomobject]@{ name = 'presentation-input'; suites = @(
            'runtime-build-identity', 'input-router', 'player-preferences', 'spell-testing-tools',
            'demo-result-integration', 'signature-progression', 'signature-rival', 'signature-recovery',
            'district-practice-coach', 'paid-field-rendering', 'compact-combat-hud',
            'cartoon-champion-presenter', 'pixel-cast-continuity', 'element-delivery-presentation',
            'wellspring-terrain-stream', 'wellspring-async-terrain-stream', 'retained-campus-canvas',
            'diagnostic-replay', 'spell-inspector', 'range-target-scenario', 'element-audio', 'hex-avoidance-feedback',
            'player-camera-rig', 'wellspring-illustrated-kit'
        ) }
    )
    Assert-HexSuiteSelection $Registry $required $shards
    return [pscustomobject]@{ required_ids = $required; shards = $shards }
}

function Assert-HexFocusedReceipt([object]$Receipt, [string[]]$Requested, [string[]]$Registry, [string]$Log) {
    if ($Receipt.schema_version -ne 1 -or $Receipt.tier -cne 'focused' -or $Receipt.result -cne 'passed' -or $null -ne $Receipt.failure) { throw 'Expected a passing Focused receipt.' }
    if ($Receipt.stderr_bytes -ne 0 -or $Receipt.supervision.suite_timeout_seconds -ne 180 -or $Receipt.executed.deterministic_suite_runner -isnot [bool] -or -not $Receipt.executed.deterministic_suite_runner) { throw 'Focused execution or supervision differs.' }
    if ((@($Receipt.requested_suite_ids) -join ',') -cne ($Requested -join ',')) { throw 'Receipt requested IDs differ from this shard.' }
    $expected = @($Registry | Where-Object { $Requested -ccontains $_ })
    $actual = @($Receipt.executed.suites)
    if ($actual.Count -ne $expected.Count -or $Receipt.executed.suite_count -ne $expected.Count -or (@($actual | ForEach-Object { $_.id }) -join ',') -cne ($expected -join ',')) { throw 'Receipt executed IDs differ from the exact registry-ordered selection.' }
    $rows = @([regex]::Matches($Log, '(?m)^([^:\r\n]+): ([0-9]+) assertions, ([0-9]+) failures\r?$'))
    $timings = @([regex]::Matches($Log, '(?m)^SUITE TIMING: ([a-z0-9-]+) [0-9]+ ms\r?$'))
    if ($rows.Count -ne $expected.Count -or $timings.Count -ne $expected.Count) { throw 'Raw suite log has missing or extra result/timing rows.' }
    $total = 0L
    for ($index = 0; $index -lt $expected.Count; $index++) {
        $row = $rows[$index]
        if ($row.Groups[1].Value -cne $expected[$index] -or $timings[$index].Groups[1].Value -cne $expected[$index] -or [long]$row.Groups[3].Value -ne 0 -or $actual[$index].failures -ne 0 -or $actual[$index].assertions -ne [long]$row.Groups[2].Value) { throw 'Raw results differ from the selected successful receipt rows.' }
        $total += [long]$row.Groups[2].Value
    }
    if ($Receipt.executed.assertion_count -ne $total) { throw 'Receipt assertion total differs from its raw results.' }
    $success = @($Log -split '\r?\n' | Where-Object { $_ -cmatch '^PASS: .*FLUX2 headless suite' })
    $expectedSuccess = 'PASS: {0} selected FLUX2 headless suite(s): {1}' -f $Requested.Count, ($Requested -join ',')
    if ($success.Count -ne 1 -or $success[0] -cne $expectedSuccess) { throw 'Raw runner did not confirm exactly this selected run.' }
}

$ciRepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$registry = @(Get-HexRegisteredSuiteIds (Get-Content -Raw -LiteralPath (Join-Path $ciRepoRoot 'tests/run_all.gd')))
$plan = Get-HexPrSuitePlan $registry
if (-not $Shard -and -not $ReceiptPath) { return $plan }
if (-not $Shard -or -not $ReceiptPath) { throw 'Receipt validation requires both -Shard and -ReceiptPath.' }
$selectedShard = @($plan.shards | Where-Object { $_.name -ceq $Shard })
if ($selectedShard.Count -ne 1) { throw "Unknown PR shard: $Shard" }
$receipt = Get-Content -Raw -LiteralPath $ReceiptPath | ConvertFrom-Json
$logs = @($receipt.logs)
if ($logs.Count -ne 1 -or $logs[0].path -cnotmatch '^\.godot/windows-tests/[0-9a-f]{32}/suite\.log$' -or $logs[0].stderr_bytes -ne 0) { throw 'Focused receipt must reference one owned suite log with empty stderr.' }
$logPath = Join-Path $ciRepoRoot $logs[0].path
if ((Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $logs[0].sha256) { throw 'Raw suite log hash differs from receipt.' }
if ((Get-Item -LiteralPath "$logPath.err").Length -ne 0) { throw 'Raw suite stderr is nonempty.' }
Assert-HexFocusedReceipt $receipt $selectedShard[0].suites $registry (Get-Content -Raw -LiteralPath $logPath)
Write-Output "PASS: PR shard $Shard executed exactly $($selectedShard[0].suites.Count) selected suites."
