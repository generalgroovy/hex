param(
    [switch]$Quiet,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This is an exact retirement list, not a ban on historical names, replay data,
# migration adapters, source artwork, or independently useful asset validators.
$retiredScopePaths = @(
    '.github/workflows/update-character-readme.yml',
    '.github/workflows/generate-visual-assets-v1.yml',
    '.github/workflows/generate-wellspring-visuals-v2.yml',
    '.github/workflows/generate-visual-gold-standard-v3.yml',
    '.agent/run-visual-assets-v1',
    '.agent/run-wellspring-visuals-v2',
    '.agent/run-visual-ai-v3',
    'tools/visual_ai/README.md',
    'tools/visual_ai/package.json',
    'tools/visual_ai/src/cli.mjs',
    'tools/visual_ai/src/fal.mjs',
    'tools/visual_ai/src/prompts.mjs',
    'tools/visual_ai/src/quality.mjs',
    'tools/visual_ai/src/sheets.mjs',
    'tools/assets/generate_character_readme_v1.py',
    'tools/assets/enhance_character_readme_v2.py',
    'legacy/web-prototype/assets/flux-rune.png.import',
    'legacy/web-prototype/assets/flux-rune.svg.import',
    'src/content/sprite_sheet_extractor.gd',
    'src/content/sprite_sheet_extractor.gd.uid',
    'src/content/visual_production_contract.gd',
    'src/content/visual_production_contract.gd.uid',
    'src/content/visual_candidate_manifest.gd',
    'src/content/visual_candidate_manifest.gd.uid',
    'tests/unit/test_sprite_sheet_extractor.gd',
    'tests/unit/test_sprite_sheet_extractor.gd.uid',
    'tests/unit/test_visual_production_contract.gd',
    'tests/unit/test_visual_production_contract.gd.uid',
    'tests/unit/test_visual_candidate_manifest.gd',
    'tests/unit/test_visual_candidate_manifest.gd.uid',
    'docs/OVERHAUL-PLAN.md',
    'docs/reactive-material-system.md',
    'docs/CHAMPION-AFFINITY-IMPLEMENTATION-PLAN.md',
    'docs/PROJECTILE-DELIVERY-IMPLEMENTATION-PLAN.md',
    'docs/MIGRATION-FLUX-MOVEMENT.md',
    'docs/SANCTUM-V1-ACCEPTANCE.md',
    'docs/SANCTUM-HUB.md',
    'docs/VISUAL-ASSET-PRODUCTION.md',
    'docs/VISUAL-ITERATION-V3.md',
    'docs/visual-baseline-v0.md',
    '.agent/TEAM-ITERATION-PROMPT.md',
    '.agent/GUI-MAP-UPDATE-PROMPT.md',
    '.agent/visual-assets-production-v1.txt'
)

# Only current, explicitly named claims are checked. Historical receipts and
# ordinary prose elsewhere are not scanned for forbidden words or old numbers.
$currentContractClaims = @(
    @{ document = 'README.md'; fact = 'playable'; pattern = 'Current source:\s*(?<value>\d+)\s*playable profiles' },
    @{ document = 'README.md'; fact = 'spells'; pattern = 'Current source:[^\r\n]*playable profiles,\s*(?<value>\d+)\s*spells' },
    @{ document = 'README.md'; fact = 'reactions'; pattern = '(?m)^\|\s*Chemistry\s*\|\s*(?<value>\d+)\s*symmetric' },
    @{ document = 'README.md'; fact = 'simulation_hz'; pattern = '(?m)^\|\s*Engine\s*\|\s*(?<value>\d+)\s*Hz authoritative simulation' },
    @{ document = 'README.md'; fact = 'snapshot_hz'; pattern = '(?m)^\|\s*Engine\s*\|[^\r\n]*;\s*(?<value>\d+)\s*Hz transport snapshots' },
    @{ document = 'SPECIFICATION.md'; fact = 'playable'; pattern = '(?m)^\|\s*Cast\s*\|\s*(?<value>\d+)\s*named playable profiles' },
    @{ document = 'SPECIFICATION.md'; fact = 'reserved'; pattern = '(?m)^\|\s*Cast\s*\|[^\r\n]*;\s*(?<value>\d+)\s*reserved' },
    @{ document = 'SPECIFICATION.md'; fact = 'spells'; pattern = '(?m)^\|\s*Magic\s*\|[^\r\n]*;\s*(?<value>\d+)\s*selectable spells' },
    @{ document = 'SPECIFICATION.md'; fact = 'reactions'; pattern = '(?m)^\|\s*Chemistry\s*\|\s*(?<value>\d+)\s*symmetric' },
    @{ document = 'SPECIFICATION.md'; fact = 'simulation_hz'; pattern = '(?m)^\|\s*Cadence\s*\|\s*(?<value>\d+)\s*Hz authoritative simulation' },
    @{ document = 'SPECIFICATION.md'; fact = 'snapshot_hz'; pattern = '(?m)^\|\s*Cadence\s*\|[^\r\n]*;\s*(?<value>\d+)\s*Hz snapshots' },
    @{ document = 'SPECIFICATION.md'; fact = 'players'; pattern = '(?m)^\|\s*Session\s*\|[^\r\n]*maximum\s*(?<value>\d+)\s*players' },
    @{ document = '.agent/OVERHAUL-IMPLEMENTATION.md'; fact = 'playable'; pattern = '(?m)^Active playable profiles:\s*(?<value>\d+)\.\s*$' }
)

function Find-RetiredScopeReferences([string]$Text) {
    $normalized = $Text.Replace('\', '/')
    foreach ($retiredPath in $retiredScopePaths) {
        $pattern = [regex]::Escape($retiredPath) + '(?![A-Za-z0-9_./-])'
        if ([regex]::IsMatch($normalized, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $retiredPath
        }
    }
}

function Find-CurrentContractIssues([hashtable]$Documents, [hashtable]$Facts) {
    foreach ($claim in $currentContractClaims) {
        if (-not $Documents.ContainsKey($claim.document) -or -not $Facts.ContainsKey($claim.fact)) {
            "Current contract input missing: $($claim.document) / $($claim.fact)"
            continue
        }
        $matches = [regex]::Matches($Documents[$claim.document], $claim.pattern)
        if ($matches.Count -ne 1) {
            "Current contract needs one explicit $($claim.fact) claim in $($claim.document)"
        } elseif ([long]$matches[0].Groups['value'].Value -ne [long]$Facts[$claim.fact]) {
            "Current contract drift: $($claim.document) $($claim.fact)=$($matches[0].Groups['value'].Value), runtime=$($Facts[$claim.fact])"
        }
    }
}

function Get-ScopeSourceInteger([string]$Root, [string]$Path, [string]$Name) {
    $source = [IO.File]::ReadAllText((Join-Path $Root $Path))
    $pattern = '(?m)^const\s+' + [regex]::Escape($Name) + '(?:\s*:\s*int)?\s*(?::=|=)\s*(?<value>[0-9_]+)'
    $match = [regex]::Match($source, $pattern)
    if (-not $match.Success) { throw "Cannot read current contract source constant: $Path / $Name" }
    return [int]$match.Groups['value'].Value.Replace('_', '')
}

if ($SelfTest) {
    $assertions = 0
    foreach ($retiredPath in $retiredScopePaths) {
        foreach ($spelling in @($retiredPath, $retiredPath.Replace('/', '\').ToUpperInvariant())) {
            $found = @(Find-RetiredScopeReferences ('load("res://' + $spelling + '")'))
            if ($found.Count -ne 1 -or $found[0] -ne $retiredPath) {
                throw "Cleanup guard failed to identify exact retired dependency: $spelling"
            }
            $assertions++
        }
    }
    foreach ($allowed in @('', 'legacy cooldown migration', 'res://src/sim/replay/replay_data.gd', 'res://art_batches/pixel_v1/magic/manifest.json', 'tools/assets/validate_visual_assets_v1.py', 'src/content/sprite_sheet_extractor.gd.provenance.txt')) {
        if (@(Find-RetiredScopeReferences $allowed).Count -ne 0) {
            throw "Cleanup guard incorrectly rejected preserved scope: $allowed"
        }
        $assertions++
    }
    $fixtureFacts = @{ playable = 27; spells = 57; reactions = 36; simulation_hz = 120; snapshot_hz = 60; players = 8; reserved = 1 }
    $fixtureDocuments = @{
        'README.md' = "Current source: 27 playable profiles, 57 spells`n| Chemistry |36 symmetric reactions |`n| Engine |120 Hz authoritative simulation; 60 Hz transport snapshots |`nHistorical checkpoint:5playable,24planned,60Hz remains evidence only."
        'SPECIFICATION.md' = "| Cast |27 named playable profiles;1 reserved Angel |`n| Magic | Eight elements;57 selectable spells;12 positions |`n| Chemistry |36 symmetric pairs |`n| Cadence |120Hz authoritative simulation;60Hz snapshots |`n| Session |Offline first, maximum8 players |"
        '.agent/OVERHAUL-IMPLEMENTATION.md' = "Active playable profiles: 27."
    }
    if (@(Find-CurrentContractIssues $fixtureDocuments $fixtureFacts).Count -ne 0) { throw 'Current contract fixture did not validate.' }
    $assertions++
    foreach ($fact in $fixtureFacts.Keys) {
        $wrongFacts = $fixtureFacts.Clone()
        $wrongFacts[$fact]++
        if (@(Find-CurrentContractIssues $fixtureDocuments $wrongFacts).Count -eq 0) { throw "Current contract did not detect $fact drift." }
        $assertions++
    }
    foreach ($document in $fixtureDocuments.Keys) {
        $missingClaim = $fixtureDocuments.Clone()
        $missingClaim[$document] = ''
        if (@(Find-CurrentContractIssues $missingClaim $fixtureFacts).Count -eq 0) { throw "Missing primary contract was accepted: $document" }
        $assertions++
    }
    foreach ($obsoleteOrDuplicate in @('| S2 |27unique identities, shared guides | queued |', "Active playable profiles: 27.`nActive playable profiles: 27.")) {
        $badQueue = $fixtureDocuments.Clone()
        $badQueue['.agent/OVERHAUL-IMPLEMENTATION.md'] = $obsoleteOrDuplicate
        if (@(Find-CurrentContractIssues $badQueue $fixtureFacts).Count -eq 0) { throw 'Historical or duplicated queue claim was accepted as current.' }
        $assertions++
    }
    Write-Output "PASS: cleanup dependency guard self-test, $assertions assertions."
    return
}

$scopeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$scopeIssues = [Collections.Generic.List[string]]::new()
foreach ($retiredPath in $retiredScopePaths) {
    if (Test-Path -LiteralPath (Join-Path $scopeRoot $retiredPath)) {
        $scopeIssues.Add("Retired entry point returned: $retiredPath")
    }
}

$scopeChampions = Get-Content -Raw -LiteralPath (Join-Path $scopeRoot 'content/champions/foundation_champions_v1.json') | ConvertFrom-Json
$scopeRoster = Get-Content -Raw -LiteralPath (Join-Path $scopeRoot 'content/champions/champion_roster_plan_v1.json') | ConvertFrom-Json
$scopeAbilities = Get-Content -Raw -LiteralPath (Join-Path $scopeRoot 'content/abilities/foundation_abilities_v1.json') | ConvertFrom-Json
$scopeReactions = Get-Content -Raw -LiteralPath (Join-Path $scopeRoot 'content/reactions/first_eight_element_reactions_v1.json') | ConvertFrom-Json
$scopeFacts = @{
    playable = @($scopeChampions.champions).Count
    reserved = @($scopeRoster.champions).Count - @($scopeChampions.champions).Count
    spells = @($scopeAbilities.runtime_wire_ids).Count
    reactions = @($scopeReactions.reactions).Count
    simulation_hz = Get-ScopeSourceInteger $scopeRoot 'src/sim/core/sim_config.gd' 'TICK_RATE'
    snapshot_hz = Get-ScopeSourceInteger $scopeRoot 'src/app/bootstrap.gd' 'SNAPSHOT_RATE'
    players = Get-ScopeSourceInteger $scopeRoot 'src/net/session_transport.gd' 'MAX_PLAYERS'
}
$scopeDocuments = @{}
foreach ($document in @('README.md', 'SPECIFICATION.md', '.agent/OVERHAUL-IMPLEMENTATION.md')) {
    $scopeDocuments[$document] = [IO.File]::ReadAllText((Join-Path $scopeRoot $document))
    foreach ($retiredReference in @(Find-RetiredScopeReferences $scopeDocuments[$document])) {
        $scopeIssues.Add("Primary contract references retired scope: $document -> $retiredReference")
    }
}
foreach ($contractIssue in @(Find-CurrentContractIssues $scopeDocuments $scopeFacts)) { $scopeIssues.Add($contractIssue) }

$scannedFiles = 0
$sourceExtensions = @('.gd', '.tscn', '.tres', '.json', '.ps1', '.py', '.sh')
foreach ($scopeDirectory in @('src', 'content', 'tests', 'scenes')) {
    foreach ($scopeFile in Get-ChildItem -LiteralPath (Join-Path $scopeRoot $scopeDirectory) -File -Recurse) {
        if ($scopeFile.Extension -notin $sourceExtensions) { continue }
        $scannedFiles++
        $sourceText = [IO.File]::ReadAllText($scopeFile.FullName)
        foreach ($retiredReference in @(Find-RetiredScopeReferences $sourceText)) {
            $relative = $scopeFile.FullName.Substring($scopeRoot.Length + 1).Replace('\', '/')
            $scopeIssues.Add("Live source dependency on retired entry point: $relative -> $retiredReference")
        }
    }
}
if ($scopeIssues.Count -gt 0) {
    throw ("Current-scope cleanup check failed:`n" + ($scopeIssues -join "`n"))
}
if (-not $Quiet) {
    Write-Output "PASS: $($retiredScopePaths.Count) retired paths remain absent; $scannedFiles live source/content/test/scene files have no literal dependency on them."
    Write-Output "PASS: $($currentContractClaims.Count) explicit README/specification/queue claims match runtime data and constants."
}
