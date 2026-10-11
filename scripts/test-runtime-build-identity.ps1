# Pure source-only regressions. Synthetic records remain in memory; this test
# does not generate a production manifest or invoke engines, exports or network.
$ErrorActionPreference = 'Stop'
$identityScriptPath = Join-Path $PSScriptRoot 'runtime-build-identity.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($identityScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
$needed = @(
    'Test-FluxRuntimeIdentityInteger',
    'Test-FluxRuntimeIdentityMember',
    'Test-FluxRuntimeIdentityRecord',
    'Get-FluxRuntimeIdentityRequiredFiles',
    'Get-FluxRuntimeIdentityCanonicalText',
    'Get-FluxRuntimeIdentityDigest',
    'New-FluxRuntimeBuildIdentity',
    'Assert-FluxRuntimeBuildIdentity'
)
foreach ($name in $needed) {
    $definitions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true))
    if ($definitions.Count -ne 1) { throw "Expected one runtime identity function $name" }
    Invoke-Expression $definitions[0].Extent.Text
}

$assertions = 0
function Check-Identity([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Reject-Identity([string]$Label, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Check-Identity $rejected $Label
}
function Copy-Identity($Value) { return $Value | ConvertTo-Json -Depth 10 | ConvertFrom-Json }
function New-IdentityRecords {
    return @(
        [pscustomobject]@{path = 'project.godot'; bytes = 10; sha256 = '1' * 64}
        [pscustomobject]@{path = 'src/net/session_transport.gd'; bytes = 20; sha256 = '2' * 64}
        [pscustomobject]@{path = 'content/maps/campus.json'; bytes = 30; sha256 = '3' * 64}
    )
}

$records = New-IdentityRecords
$digest = Get-FluxRuntimeIdentityDigest $records 48 18 '4.7.1.stable.official.a13da4feb'
$reordered = @($records[2], $records[0], $records[1])
Check-Identity ($digest -ceq (Get-FluxRuntimeIdentityDigest $reordered 48 18 '4.7.1.stable.official.a13da4feb')) 'Record order does not change canonical identity'
Check-Identity ($digest -cmatch '^[0-9a-f]{64}$') 'Canonical identity is lowercase SHA-256'
$canonical = Get-FluxRuntimeIdentityCanonicalText $records 48 18 '4.7.1.stable.official.a13da4feb'
Check-Identity ($canonical.StartsWith("FLUX_RUNTIME_BUILD_IDENTITY_V1`nprotocol:48`nsnapshot_schema:18`n")) 'Canonical stream names schema, protocol and snapshot fields'
Check-Identity ($canonical.Contains("path_utf8:13:project.godot`nbytes:10`nsha256:")) 'Tagged UTF-8 path length and byte length prevent concatenation ambiguity'

foreach ($case in @(
    [pscustomobject]@{label = 'source bytes'; mutate = {param($r) [void]($r[1].bytes++)}}
    [pscustomobject]@{label = 'source hash'; mutate = {param($r) [void]($r[1].sha256 = '4' * 64)}}
    [pscustomobject]@{label = 'source path'; mutate = {param($r) [void]($r[1].path = 'src/net/other.gd')}}
    [pscustomobject]@{label = 'source membership'; mutate = {param($r) return @($r | Select-Object -First 2)}}
)) {
    $candidate = @(Copy-Identity $records)
    $mutated = & $case.mutate $candidate
    if ($null -ne $mutated) { $candidate = @($mutated) }
    Check-Identity ($digest -cne (Get-FluxRuntimeIdentityDigest $candidate 48 18 '4.7.1.stable.official.a13da4feb')) "$($case.label) changes runtime identity"
}
Check-Identity ($digest -cne (Get-FluxRuntimeIdentityDigest $records 47 18 '4.7.1.stable.official.a13da4feb')) 'Protocol changes runtime identity independently'
Check-Identity ($digest -cne (Get-FluxRuntimeIdentityDigest $records 48 19 '4.7.1.stable.official.a13da4feb')) 'Snapshot schema changes runtime identity independently'
Check-Identity ($digest -cne (Get-FluxRuntimeIdentityDigest $records 48 18 '4.7.2.stable.example')) 'Engine identity changes runtime identity independently'

$identity = New-FluxRuntimeBuildIdentity $records 48 18 '4.7.1.stable.official.a13da4feb'
Check-Identity ($identity.build_id -ceq "p48-$($digest.Substring(0, 12))") 'Display build ID is derived from protocol and full runtime digest'
Check-Identity ($identity.status -ceq 'candidate_generated_not_promoted' -and $identity.authority.Contains('delivery, publication and acceptance remain separate')) 'Generated identity cannot claim promotion or acceptance'
Check-Identity (Assert-FluxRuntimeBuildIdentity $identity (Copy-Identity $identity)) 'Exact generated identity validates'

foreach ($case in @(
    [pscustomobject]@{label = 'extra field'; mutate = {param($m) $m | Add-Member -NotePropertyName released -NotePropertyValue $true}}
    [pscustomobject]@{label = 'string schema'; mutate = {param($m) $m.schema_version = '1'}}
    [pscustomobject]@{label = 'promoted status'; mutate = {param($m) $m.status = 'released'}}
    [pscustomobject]@{label = 'wrong scope'; mutate = {param($m) $m.scope_id = 'tests-too'}}
    [pscustomobject]@{label = 'wrong encoding'; mutate = {param($m) $m.canonical_encoding = 'json'}}
    [pscustomobject]@{label = 'wrong protocol'; mutate = {param($m) $m.protocol_version = 47}}
    [pscustomobject]@{label = 'wrong snapshot'; mutate = {param($m) $m.snapshot_schema = 17}}
    [pscustomobject]@{label = 'wrong engine'; mutate = {param($m) $m.engine_identity = 'unknown'}}
    [pscustomobject]@{label = 'wrong count'; mutate = {param($m) $m.record_count++}}
    [pscustomobject]@{label = 'uppercase digest'; mutate = {param($m) $m.runtime_source_sha256 = $m.runtime_source_sha256.ToUpperInvariant()}}
    [pscustomobject]@{label = 'short digest'; mutate = {param($m) $m.runtime_source_sha256 = '0' * 63}}
    [pscustomobject]@{label = 'friendly drifting ID'; mutate = {param($m) $m.build_id = 'overnight-best'}}
    [pscustomobject]@{label = 'wrong derived prefix'; mutate = {param($m) $m.build_id = 'p48-000000000000'}}
    [pscustomobject]@{label = 'acceptance claim'; mutate = {param($m) $m.authority = 'verified and released'}}
)) {
    $candidate = Copy-Identity $identity
    & $case.mutate $candidate | Out-Null
    Reject-Identity $case.label { Assert-FluxRuntimeBuildIdentity $candidate $identity }
}

foreach ($included in @(
    'project.godot', 'src/net/session_transport.gd', 'content/maps/campus.json',
    'scenes/game.tscn', 'addons/runtime/plugin.gd', 'assets/world.png',
    'art_batches/pixel_v1/magic/manifest.json', 'art_batches/pixel_v1/magic/export/fire.png',
    'art_batches/pixel_v1/map/manifest.json', 'art_batches/pixel_v1/map/export/floor.png',
    'art_batches/wellspring_style_v2/runtime/terrain.png',
    'art_batches/wellspring_style_v2/ground_style.gd'
)) { Check-Identity (Test-FluxRuntimeIdentityMember $included) "Production runtime member included: $included" }
foreach ($excluded in @(
    'content/runtime/runtime_build_identity_v1.json', 'tests/unit/test_core.gd',
    'scripts/test.ps1', 'export_presets.cfg', 'packaging/README-FIRST.txt',
    'docs/evidence/run.json', 'exports/windows/flux2.pck', 'art_batches/pixel_v1/magic/source/fire.json'
)) { Check-Identity (-not (Test-FluxRuntimeIdentityMember $excluded)) "Generated/nonruntime member excluded: $excluded" }

$requiredFiles = @(Get-FluxRuntimeIdentityRequiredFiles)
Check-Identity ($requiredFiles -ccontains 'art_batches/wellspring_style_v2/ground_style.gd') 'Directly preloaded Wellspring ground style is a required enumerated file'
Check-Identity (($requiredFiles | Where-Object { $_ -ceq 'art_batches/wellspring_style_v2/ground_style.gd' }).Count -eq 1) 'Wellspring ground style is enumerated exactly once'

# Scan direct res:// string edges from included GDScript/scenes, plus included
# out-of-tree GDScript required files. Existing file targets must belong to the
# runtime identity unless they are documented self/editor edges or the exact
# terrain bake-provenance declaration below (not an executable dependency).
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$edgeSources = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($relativeRoot in @('src', 'content', 'scenes', 'addons', 'assets')) {
    $absoluteRoot = Join-Path $repoRoot $relativeRoot
    foreach ($file in Get-ChildItem -LiteralPath $absoluteRoot -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($repoRoot, $file.FullName).Replace('\', '/')
        if ($relative -cmatch '\.(gd|tscn)$' -and (Test-FluxRuntimeIdentityMember $relative)) {
            $null = $edgeSources.Add($relative)
        }
    }
}
foreach ($relative in $requiredFiles) {
    if ($relative -cmatch '\.(gd|tscn)$') { $null = $edgeSources.Add($relative) }
}
$intentionalExcludedEdges = @(
    'content/runtime/runtime_build_identity_v1.json',
    'scripts/generate_sanctum_runtime_kit.gd'
)
$edgePattern = [regex]'(?m)["'']res://([^"''\r\n]+)["'']'
$terrainProvenanceSource = 'src/presentation/wellspring_terrain_stream.gd'
$terrainProvenanceTarget = 'scripts/bake_wellspring_terrain.gd'
$terrainSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $terrainProvenanceSource)
$terrainDeclarations = [regex]::Matches($terrainSource, '(?ms)^const BAKE_SOURCE_PATHS: Array\[String\] = \[(?<body>.*?)^\]\r?$')
Check-Identity ($terrainDeclarations.Count -eq 1) 'Terrain authoring provenance has one explicit typed BAKE_SOURCE_PATHS declaration'
$terrainBody = $terrainDeclarations[0].Groups['body']
$terrainBakeEntries = @($edgePattern.Matches($terrainBody.Value) | Where-Object { $_.Groups[1].Value -ceq $terrainProvenanceTarget })
Check-Identity ($terrainBakeEntries.Count -eq 1) 'Terrain authoring provenance names the exact baker once'
$terrainLiteralPattern = [regex]'(?m)^[ \t]*(?<literal>(?<quote>["''])res://scripts/bake_wellspring_terrain\.gd\k<quote>)[ \t]*,?[ \t]*\r?$'
$terrainLiteralEntries = $terrainLiteralPattern.Matches($terrainBody.Value)
Check-Identity ($terrainLiteralEntries.Count -eq 1 -and $terrainLiteralEntries[0].Groups['literal'].Index -eq $terrainBakeEntries[0].Index) 'Terrain baker provenance is a bare literal entry, never an executable expression'
$wrappedTerrainEntry = $terrainBody.Value.Replace($terrainBakeEntries[0].Value, ('str(preload(' + $terrainBakeEntries[0].Value + '))'))
Check-Identity ($terrainLiteralPattern.Matches($wrappedTerrainEntry).Count -eq 0) 'An expression-wrapped baker reference cannot inherit the provenance exception'
$terrainBakeOffset = $terrainBody.Index + $terrainBakeEntries[0].Index

function Test-TerrainBakeProvenanceEdge([string]$Source, [string]$Target, [int]$Offset) {
    # The baker is a source fingerprint checked by the bake-equivalence suite.
    # Runtime consumes versioned baked signatures; it does not load this script.
    # Match the declaration occurrence, so a new preload even in this same
    # source remains an ordinary runtime edge and cannot inherit this exception.
    return $Source -ceq $terrainProvenanceSource -and $Target -ceq $terrainProvenanceTarget -and $Offset -eq $terrainBakeOffset
}
Check-Identity (Test-TerrainBakeProvenanceEdge $terrainProvenanceSource $terrainProvenanceTarget $terrainBakeOffset) 'Exact terrain authoring occurrence is recognized'
Check-Identity (-not (Test-TerrainBakeProvenanceEdge 'src/app/bootstrap.gd' $terrainProvenanceTarget $terrainBakeOffset)) 'Another runtime source cannot inherit the terrain provenance exception'
Check-Identity (-not (Test-TerrainBakeProvenanceEdge $terrainProvenanceSource 'scripts/other_baker.gd' $terrainBakeOffset)) 'Another script cannot inherit the terrain provenance exception'
Check-Identity (-not (Test-TerrainBakeProvenanceEdge $terrainProvenanceSource $terrainProvenanceTarget ($terrainBakeOffset + 1))) 'Another occurrence in the same source cannot inherit the terrain provenance exception'
foreach ($sourceRelative in $edgeSources) {
    $sourcePath = Join-Path $repoRoot $sourceRelative
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Static runtime edge source is missing: $sourceRelative" }
    foreach ($match in $edgePattern.Matches((Get-Content -Raw -LiteralPath $sourcePath))) {
        $targetRelative = $match.Groups[1].Value
        $targetPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $targetRelative))
        Check-Identity ($targetPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) "Runtime resource edge remains inside the checkout: $sourceRelative -> $targetRelative"
        if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) { continue }
        if ($intentionalExcludedEdges -ccontains $targetRelative) { continue }
        if (Test-TerrainBakeProvenanceEdge $sourceRelative $targetRelative $match.Index) { continue }
        Check-Identity (Test-FluxRuntimeIdentityMember $targetRelative) "Existing runtime resource edge is identity-covered: $sourceRelative -> $targetRelative"
    }
}

foreach ($bad in @(
    [pscustomobject]@{path = '../outside'; bytes = 1; sha256 = 'a' * 64}
    [pscustomobject]@{path = 'src\bad.gd'; bytes = 1; sha256 = 'a' * 64}
    [pscustomobject]@{path = 'src/NUL'; bytes = 1; sha256 = 'a' * 64}
    [pscustomobject]@{path = 'src/good.gd'; bytes = '1'; sha256 = 'a' * 64}
    [pscustomobject]@{path = 'src/good.gd'; bytes = -1; sha256 = 'a' * 64}
    [pscustomobject]@{path = 'src/good.gd'; bytes = 1; sha256 = 'A' * 64}
)) { Reject-Identity 'Malformed source record fails closed' { Get-FluxRuntimeIdentityDigest @($bad) 48 18 '4.7.1.stable.official.a13da4feb' } }
Reject-Identity 'Duplicate source paths fail closed' { Get-FluxRuntimeIdentityDigest @($records[0], $records[0]) 48 18 '4.7.1.stable.official.a13da4feb' }
Reject-Identity 'Unsafe engine identity fails closed' { Get-FluxRuntimeIdentityDigest $records 48 18 "engine`nspoof" }

$source = Get-Content -Raw -LiteralPath $identityScriptPath
Check-Identity (-not $source.Contains('Invoke-FluxGodot') -and -not $source.Contains('Start-Process') -and -not $source.Contains('http://') -and -not $source.Contains('https://')) 'Identity script has no engine or network path'
Check-Identity ($source.Contains("[ValidateSet('Check', 'Generate')]") -and $source.Contains("if (`$Mode -eq 'Generate')")) 'Only explicit Check and Generate modes exist'
Check-Identity ($source.Contains("if ((Test-Path -LiteralPath `$resolvedManifest) -and -not `$Force)")) 'Generation rejects an existing manifest without explicit Force'
Check-Identity ($source.Contains("`$ManifestPath = 'content/runtime/runtime_build_identity_v1.json'") -and $source.Contains("`$EngineIdentity = '4.7.1.stable.official.a13da4feb'")) 'Manifest exclusion and engine authority are fixed rather than caller-selectable'
Write-Output "PASS: runtime build identity source-only regression, $assertions assertions; canonical synthetic records, strict manifest/scope and static resource edges; no engine or production writes."
