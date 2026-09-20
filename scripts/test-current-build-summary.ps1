# Source-only descriptor and README-block regressions. Synthetic fixtures stay
# in memory; no payload, historical installer, engine, network or file write.
$ErrorActionPreference = 'Stop'
$summaryTestRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$summaryScriptPath = Join-Path $PSScriptRoot 'current-build-summary.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($summaryScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
$needed = @('Test-FluxSummaryInteger', 'Get-FluxSummaryRoleMap', 'Get-FluxCurrentBuildSummary', 'Format-FluxCurrentBuildMarkdown', 'Assert-FluxCurrentBuildText')
foreach ($name in $needed) {
    $definitions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true))
    if ($definitions.Count -ne 1) { throw "Expected one summary function $name" }
    Invoke-Expression $definitions[0].Extent.Text
}
$assertions = 0
function Check-Summary([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Reject-Summary([string]$Label, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Check-Summary $rejected $Label
}
function New-SummaryPointer {
    return [pscustomobject]@{
        schema_version = 1
        current = [pscustomobject]@{
            checkpoint_id = 'fixture-p47-20260913'
            kind = 'current_portable'
            build_directory = 'exports/windows-fixture-p47-20260913'
            evidence_directory = 'docs/evidence/windows-fixture-p47-20260913'
            payloads = @(
                [pscustomobject]@{path = 'exports/windows-fixture-p47-20260913/windows/flux2.exe'; bytes = 10; sha256 = '1' * 64; role = 'game'}
                [pscustomobject]@{path = 'exports/windows-fixture-p47-20260913/windows/flux2.pck'; bytes = 20; sha256 = '2' * 64; role = 'pack'}
                [pscustomobject]@{path = 'exports/windows-fixture-p47-20260913/release/FLUX2-Windows-x86_64.zip'; bytes = 30; sha256 = '3' * 64; role = 'portable'}
            )
            evidence = @(
                [pscustomobject]@{path = 'docs/evidence/windows-fixture-p47-20260913/checkpoint.json'; bytes = 40; sha256 = '4' * 64; role = 'checkpoint'}
                [pscustomobject]@{path = 'docs/evidence/windows-fixture-p47-20260913/full.json'; bytes = 50; sha256 = '5' * 64; role = 'full'}
                [pscustomobject]@{path = 'docs/evidence/windows-fixture-p47-20260913/capture.json'; bytes = 60; sha256 = '6' * 64; role = 'capture'}
                [pscustomobject]@{path = 'docs/evidence/windows-fixture-p47-20260913/boot.log'; bytes = 70; sha256 = '7' * 64; role = 'boot_log'}
                [pscustomobject]@{path = 'docs/evidence/windows-fixture-p47-20260913/boot.err'; bytes = 0; sha256 = '8' * 64; role = 'boot_stderr'}
            )
        }
        boundaries = [pscustomobject]@{
            publication = 'not_published'
            human_acceptance = 'pending'
            two_pc_acceptance = 'pending'
            sustained_rendered_120fps = 'not_certified'
            current_installer = 'not_attempted_portable_only'
        }
    }
}
function Copy-SummaryPointer { return New-SummaryPointer | ConvertTo-Json -Depth 12 | ConvertFrom-Json }

$fixture = New-SummaryPointer
$summary = Get-FluxCurrentBuildSummary $fixture
Check-Summary ($summary.descriptor_status -ceq 'pointer_descriptor_valid') 'Valid descriptor has a metadata-only status'
Check-Summary ($summary.checkpoint_id -ceq 'fixture-p47-20260913') 'Checkpoint identity comes from the pointer'
Check-Summary ($summary.game.path -ceq $fixture.current.payloads[0].path -and $summary.pack.path -ceq $fixture.current.payloads[1].path -and $summary.portable.path -ceq $fixture.current.payloads[2].path) 'All playable paths come from exact current roles'
Check-Summary ($summary.pack.sha256 -ceq ('2' * 64) -and $summary.portable.sha256 -ceq ('3' * 64)) 'Displayed hashes come from current roles'
Check-Summary ($null -eq $fixture.historical_installer) 'Synthetic source-only success does not require a historical installer group'
Check-Summary ($summary.PSObject.Properties.Name -notcontains 'passed' -and $summary.summary_scope.Contains('not freshly verified')) 'Summary cannot claim fresh verification'
$block = Format-FluxCurrentBuildMarkdown $summary
Check-Summary ($block.Contains($summary.game.path) -and $block.Contains($summary.portable.path) -and $block.Contains($summary.pack.sha256)) 'Markdown is generated from summary fields'
Check-Summary ($block.Contains('validates pointer metadata only') -and $block.Contains('current-checkpoint.ps1 -ReportOnly')) 'Markdown states the evidence boundary and exact verifier'
Check-Summary (Assert-FluxCurrentBuildText "intro`n`n$block`n`nafter" $block) 'One exact generated block passes'
Check-Summary (Assert-FluxCurrentBuildText ("intro`r`n`r`n" + $block.Replace("`n", "`r`n") + "`r`n") $block) 'Line-ending differences do not create false drift'
Reject-Summary 'Stale path in generated block fails closed' { Assert-FluxCurrentBuildText ($block.Replace($summary.game.path, 'exports/stale/windows/flux2.exe')) $block }
Reject-Summary 'Edited acceptance boundary fails closed' { Assert-FluxCurrentBuildText ($block.Replace('not_published', 'published')) $block }
Reject-Summary 'Duplicate generated blocks fail closed' { Assert-FluxCurrentBuildText "$block`n$block" $block }
Reject-Summary 'Missing generated block fails closed' { Assert-FluxCurrentBuildText 'README without a generated summary' $block }

$actualPointer = Get-Content -Raw -LiteralPath (Join-Path $summaryTestRoot 'docs/current-checkpoint.json') | ConvertFrom-Json
$actual = Get-FluxCurrentBuildSummary $actualPointer
Check-Summary ($actual.checkpoint_id -ceq [string]$actualPointer.current.checkpoint_id) 'Actual selected pointer descriptor validates without payload access'
Check-Summary ($actual.game.path -ceq [string](@($actualPointer.current.payloads | Where-Object role -eq 'game')[0].path)) 'Actual game path follows the selected pointer'

foreach ($case in @(
    [pscustomobject]@{label = 'wrong schema'; mutate = {param($p) $p.schema_version = 2}}
    [pscustomobject]@{label = 'string schema'; mutate = {param($p) $p.schema_version = '1'}}
    [pscustomobject]@{label = 'missing current group'; mutate = {param($p) $p.current = $null}}
    [pscustomobject]@{label = 'wrong current kind'; mutate = {param($p) $p.current.kind = 'historical_installer'}}
    [pscustomobject]@{label = 'unsafe checkpoint identity'; mutate = {param($p) $p.current.checkpoint_id = '../fixture'}}
    [pscustomobject]@{label = 'wrong build prefix'; mutate = {param($p) $p.current.build_directory = 'docs/windows-fixture'}}
    [pscustomobject]@{label = 'wrong evidence prefix'; mutate = {param($p) $p.current.evidence_directory = 'exports/windows-fixture'}}
    [pscustomobject]@{label = 'missing game role'; mutate = {param($p) $p.current.payloads = @($p.current.payloads | Select-Object -Skip 1)}}
    [pscustomobject]@{label = 'duplicate payload role'; mutate = {param($p) $p.current.payloads[1].role = 'game'}}
    [pscustomobject]@{label = 'wrong exact game target'; mutate = {param($p) $p.current.payloads[0].path = $p.current.build_directory + '/release/flux2.exe'}}
    [pscustomobject]@{label = 'parent traversal payload'; mutate = {param($p) $p.current.payloads[0].path = $p.current.build_directory + '/../flux2.exe'}}
    [pscustomobject]@{label = 'backslash payload'; mutate = {param($p) $p.current.payloads[0].path = $p.current.payloads[0].path.Replace('/', '\')}}
    [pscustomobject]@{label = 'alternate data stream payload'; mutate = {param($p) $p.current.payloads[0].path += ':stream'}}
    [pscustomobject]@{label = 'Windows device payload'; mutate = {param($p) $p.current.payloads[0].path = $p.current.build_directory + '/windows/NUL'}}
    [pscustomobject]@{label = 'string payload bytes'; mutate = {param($p) $p.current.payloads[0].bytes = '10'}}
    [pscustomobject]@{label = 'negative payload bytes'; mutate = {param($p) $p.current.payloads[0].bytes = -1}}
    [pscustomobject]@{label = 'fractional payload bytes'; mutate = {param($p) $p.current.payloads[0].bytes = 1.5}}
    [pscustomobject]@{label = 'uppercase payload hash'; mutate = {param($p) $p.current.payloads[0].sha256 = 'A' * 64}}
    [pscustomobject]@{label = 'malformed payload hash'; mutate = {param($p) $p.current.payloads[0].sha256 = 'bad'}}
    [pscustomobject]@{label = 'missing evidence role'; mutate = {param($p) $p.current.evidence = @($p.current.evidence | Select-Object -Skip 1)}}
    [pscustomobject]@{label = 'duplicate evidence role'; mutate = {param($p) $p.current.evidence[1].role = 'checkpoint'}}
    [pscustomobject]@{label = 'wrong checkpoint receipt target'; mutate = {param($p) $p.current.evidence[0].path = $p.current.evidence_directory + '/other.json'}}
    [pscustomobject]@{label = 'missing boundaries'; mutate = {param($p) $p.boundaries = $null}}
    [pscustomobject]@{label = 'missing publication boundary'; mutate = {param($p) $p.boundaries.publication = ''}}
    [pscustomobject]@{label = 'unsafe boundary value'; mutate = {param($p) $p.boundaries.current_installer = 'not attempted'}}
)) {
    $candidate = Copy-SummaryPointer
    & $case.mutate $candidate
    Reject-Summary $case.label { Get-FluxCurrentBuildSummary $candidate }
}

$source = Get-Content -Raw -LiteralPath $summaryScriptPath
Check-Summary (-not $source.Contains('Get-FileHash') -and -not $source.Contains('Start-Process') -and -not $source.Contains('Invoke-FluxGodot')) 'Summary helper has no payload hashing, process launch or engine path'
Check-Summary (-not $source.Contains('Set-Content') -and -not $source.Contains('Add-Content') -and -not $source.Contains('Out-File')) 'Summary helper has no write path'
Write-Output "PASS: current-build summary source-only regression, $assertions assertions; synthetic pointer fixtures and README drift checks; no payload, historical installer, engine or file writes."
