param(
    [switch]$Check,
    [switch]$Json,
    [switch]$Quiet,
    [string]$OutputPath = ''
)

. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$repoRoot = Get-FluxRepoRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot '.godot\reports\asset-inventory.json'
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $repoRoot $OutputPath
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

$assetExtensions = @('.png', '.svg', '.webp', '.jpg', '.jpeg', '.wav', '.ogg', '.mp3', '.ttf', '.otf', '.gdshader')
$textExtensions = @('.gd', '.tscn', '.tres', '.godot', '.json', '.md', '.ps1', '.cmd', '.sh', '.py', '.toml', '.txt')
$trackedAssets = @(& git -C $repoRoot ls-files -- assets | Where-Object { $assetExtensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() })
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate tracked assets.' }
$trackedAssetSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($path in $trackedAssets) { [void]$trackedAssetSet.Add($path.Replace('\', '/')) }

$references = @{}
$missingReferences = @{}
$referencePattern = '(?i)(?:(?:\.\./)+|res://)?assets[/\\][A-Za-z0-9_ .\-/\\]+?\.(?:png|svg|webp|jpg|jpeg|wav|ogg|mp3|ttf|otf|gdshader)'
$trackedTextFiles = @(& git -C $repoRoot ls-files | Where-Object { $textExtensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() })
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate tracked source files for asset references.' }

foreach ($sourcePath in $trackedTextFiles) {
    $fullSourcePath = Join-Path $repoRoot $sourcePath
    if (-not (Test-Path -LiteralPath $fullSourcePath -PathType Leaf)) { continue }
    $text = Get-Content -Raw -LiteralPath $fullSourcePath
    foreach ($match in [regex]::Matches($text, $referencePattern)) {
        $candidate = $match.Value.Replace('\', '/')
        $assetIndex = $candidate.IndexOf('assets/', [System.StringComparison]::OrdinalIgnoreCase)
        if ($assetIndex -lt 0) { continue }
        $candidate = $candidate.Substring($assetIndex)
        if ($trackedAssetSet.Contains($candidate)) {
            if (-not $references.ContainsKey($candidate)) { $references[$candidate] = @{} }
            $references[$candidate][$sourcePath.Replace('\', '/')] = $true
        } else {
            if (-not $missingReferences.ContainsKey($candidate)) { $missingReferences[$candidate] = @{} }
            $missingReferences[$candidate][$sourcePath.Replace('\', '/')] = $true
        }
    }
}

function Get-FluxReferenceClass([string]$SourcePath) {
    if ($SourcePath -eq 'project.godot' -or $SourcePath.StartsWith('src/') -or $SourcePath.StartsWith('scenes/')) { return 'runtime_code' }
    if ($SourcePath.StartsWith('content/')) { return 'content_catalog' }
    if ($SourcePath.StartsWith('scripts/')) { return 'tooling' }
    if ($SourcePath.StartsWith('tests/')) { return 'test' }
    if ($SourcePath -eq 'README.md' -or $SourcePath.StartsWith('docs/') -or $SourcePath.StartsWith('.agent/') -or $SourcePath.StartsWith('assets/')) { return 'documentation' }
    return 'other'
}

$assetRows = @()
foreach ($assetPath in $trackedAssets | Sort-Object) {
    $normalizedPath = $assetPath.Replace('\', '/')
    $sourcePaths = if ($references.ContainsKey($normalizedPath)) { @($references[$normalizedPath].Keys | Sort-Object) } else { @() }
    $classes = @($sourcePaths | ForEach-Object { Get-FluxReferenceClass $_ } | Sort-Object -Unique)
    $classification = if ($classes -contains 'runtime_code') {
        'runtime_code_referenced'
    } elseif ($classes -contains 'content_catalog') {
        'catalog_declared'
    } elseif ($classes -contains 'tooling') {
        'tooling_input'
    } elseif ($classes -contains 'test') {
        'test_only'
    } elseif ($classes -contains 'documentation') {
        'documentation_only'
    } elseif ($classes.Count -gt 0) {
        'other_reference'
    } else {
        'unreferenced_candidate'
    }
    $fullAssetPath = Join-Path $repoRoot $normalizedPath
    $assetRows += [ordered]@{
        path = $normalizedPath
        bytes = (Get-Item -LiteralPath $fullAssetPath).Length
        classification = $classification
        reference_classes = $classes
        references = $sourcePaths
    }
}

$missingRows = @()
foreach ($missingPath in $missingReferences.Keys | Sort-Object) {
    $sourcePaths = @($missingReferences[$missingPath].Keys | Sort-Object)
    $missingRows += [ordered]@{
        path = $missingPath
        reference_classes = @($sourcePaths | ForEach-Object { Get-FluxReferenceClass $_ } | Sort-Object -Unique)
        references = $sourcePaths
    }
}

$caseCollisions = @($trackedAssets | Group-Object { $_.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 } | ForEach-Object { @($_.Group) })
$missingRuntimeRows = @($missingRows | Where-Object { $_['reference_classes'] -contains 'runtime_code' })
$issues = @()
if ($caseCollisions.Count -gt 0) { $issues += 'Tracked asset paths collide when compared case-insensitively.' }
if ($missingRuntimeRows.Count -gt 0) { $issues += 'Runtime code or a scene directly references a missing asset.' }
$classificationCounts = [ordered]@{}
foreach ($group in $assetRows | Group-Object { $_['classification'] } | Sort-Object Name) {
    $classificationCounts[$group.Name] = $group.Count
}

$trackedAssetBytes = 0L
foreach ($assetRow in $assetRows) { $trackedAssetBytes += [long]$assetRow['bytes'] }
$report = [ordered]@{
    schema_version = 1
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    authority = 'conservative tracked-asset inventory; unreferenced never means safe to delete without catalog, export and history review'
    tracked_asset_count = $assetRows.Count
    tracked_asset_bytes = $trackedAssetBytes
    classification_counts = $classificationCounts
    missing_literal_reference_count = $missingRows.Count
    missing_runtime_literal_reference_count = $missingRuntimeRows.Count
    case_collision_count = $caseCollisions.Count
    check = [ordered]@{
        passed = ($issues.Count -eq 0)
        issues = $issues
    }
    assets = $assetRows
    missing_literal_references = $missingRows
    case_collisions = $caseCollisions
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$reportJson = $report | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($OutputPath, $reportJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

if ($Json) {
    Write-Output $reportJson
} elseif (-not $Quiet) {
    Write-Output ("FLUX assets: {0} tracked; {1} runtime-code, {2} catalog, {3} tooling, {4} documentation-only, {5} unreferenced candidates." -f $assetRows.Count, [int]$classificationCounts['runtime_code_referenced'], [int]$classificationCounts['catalog_declared'], [int]$classificationCounts['tooling_input'], [int]$classificationCounts['documentation_only'], [int]$classificationCounts['unreferenced_candidate'])
    Write-Output ("Literal references missing: {0} total, {1} from runtime code/scenes. Report: {2}" -f $missingRows.Count, $missingRuntimeRows.Count, $OutputPath)
}
if ($Check -and $issues.Count -gt 0) {
    foreach ($issue in $issues) { Write-Error $issue }
    throw "Asset inventory check failed with $($issues.Count) issue(s)."
}
if ($Check -and -not $Quiet) { Write-Output 'PASS: tracked asset path integrity is clean.' }
