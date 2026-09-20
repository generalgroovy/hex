param(
    [string]$ChampionId,
    [string]$BatchName = ('batch-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-FluxArtPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Art batch path contains a reparse point: $cursor" }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-FluxCharacterArtBatchPlan([string]$RepoRoot, [string]$Identity, [string]$Batch) {
    if ($Identity -cnotmatch '^[a-z][a-z0-9_]*$') { throw 'Use an exact canonical technical champion ID, not a display name or path.' }
    if ($Batch -cnotmatch '^[a-z0-9][a-z0-9_-]{0,63}$' -or $Batch -match '^(con|prn|aux|nul|com[1-9]|lpt[1-9])$') { throw 'Batch name must be a safe lowercase slug, not a path or reserved device name.' }
    $root = [IO.Path]::GetFullPath($RepoRoot)
    $relative = "art_batches/character_style_v1/$Identity/$Batch"
    $destination = [IO.Path]::GetFullPath((Join-Path $root $relative))
    $allowed = [IO.Path]::GetFullPath((Join-Path $root 'art_batches/character_style_v1')).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $destination.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Batch destination escapes the character-art workspace.' }
    Assert-FluxArtPath $destination
    if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite existing batch: $destination" }
    $catalogPath = Join-Path $root 'content/champions/foundation_champions_v1.json'
    $templateRoot = Join-Path $root 'art_batches/character_style_v1/template_v2'
    foreach ($path in @($catalogPath, (Join-Path $templateRoot 'contract.json'), (Join-Path $templateRoot 'GENERATION-PROMPT.md'), (Join-Path $templateRoot 'review-receipt.template.json'), (Join-Path $root 'art/templates/champion_profile_v2.json'))) { Assert-FluxArtPath $path }
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    $matches = @($catalog.champions | Where-Object { $_.id -ceq $Identity })
    if ($matches.Count -ne 1) { throw "Unknown canonical ID '$Identity'. Planned renamed IDs are not aliases; use the current catalog ID." }
    $champion = $matches[0]
    $contract = Get-Content -LiteralPath (Join-Path $templateRoot 'contract.json') -Raw | ConvertFrom-Json
    if ($contract.id -cne 'flux-three-body-art-production-v2' -or $champion.body_type -cnotin @('small','middle','large') -or $contract.directions.Count -ne 8 -or $contract.rows.Count -ne 10) { throw 'Current three-body production contract is unavailable or malformed.' }
    $height = $contract.standing_height_pixels.($champion.body_type)
    $summary = [ordered]@{
        schema_version = 1; status = 'pending_appearance_and_generation'; live_promotion = $false
        champion_id = $champion.id; display_name = $champion.display_name; race_id = $champion.ancestry
        body_type = $champion.body_type; standing_height_pixels = $height; wire_id = $champion.wire_id
        affinities = $champion.affinity_points; contract_id = $contract.id
        catalog_sha256 = (Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash.ToLowerInvariant()
        contract_sha256 = (Get-FileHash -LiteralPath (Join-Path $templateRoot 'contract.json') -Algorithm SHA256).Hash.ToLowerInvariant()
        appearance_status = 'PENDING: inspect approved identity references; no clothing, skin or palette inferred by this scaffold.'
        style_reference = $contract.style_reference; style_reference_sha256 = $contract.style_reference_sha256
        identity_reference_index = 'reference/art/CURRENT-CHARACTER-REFERENCE.md'
    }
    $worksheet = Get-Content -LiteralPath (Join-Path $root 'art/templates/champion_profile_v2.json') -Raw | ConvertFrom-Json
    $worksheet.champion_id = $champion.id; $worksheet.display_name = $champion.display_name
    $worksheet.race_id = $champion.ancestry; $worksheet.body_type = $champion.body_type; $worksheet.standing_height_pixels = $height
    foreach ($field in @('skin','primary','secondary','accent','hair','anatomy','clothing')) { $worksheet.$field = 'PENDING_APPROVED_IDENTITY_REFERENCE_REVIEW' }
    $worksheet.affinities = $champion.affinity_points
    $receipt = Get-Content -LiteralPath (Join-Path $templateRoot 'review-receipt.template.json') -Raw | ConvertFrom-Json
    $receipt.champion_id = $champion.id; $receipt.body_type = $champion.body_type
    $receipt.candidate_sha256 = $null; $receipt.reviewed_at_utc = $null
    $receipt.reviewer.id = 'PENDING_ACTUAL_REVIEWER'; $receipt.status = 'pending'; $receipt.visual_attestation = $false
    if ($receipt.cells.Count -ne 80 -or @($receipt.cells | Where-Object { $_.decision -cne 'pending' }).Count -ne 0) { throw 'Review template must contain80 pending cells.' }
    $promptTemplate = Get-Content -LiteralPath (Join-Path $templateRoot 'GENERATION-PROMPT.md') -Raw
    $prompts = [ordered]@{}
    $pages = @()
    $boardOrder = @('grounded','jump','cast','hit','walk','walk_b','sprint','sprint_b','slide','roll')
    foreach ($direction in $contract.directions) {
        $prompt = $promptTemplate.Replace('[canonical stable ID, display name, race, skin, hair, anatomy, clothing]', "$($champion.id); $($champion.display_name); race $($champion.ancestry). Appearance PENDING approved-reference review; do not invent skin, hair, anatomy or clothing.")
        $prompt = $prompt.Replace('[small 58 / middle 68 / large 76]', "$($champion.body_type) $height")
        $prompt = $prompt.Replace('[direction, yaw, exact cue from contract]', "$($direction.id), art yaw $($direction.yaw_degrees) degrees. $($direction.cue)")
        $prompts["$($direction.id)-prompt.md"] = "# DRAFT - resolve approved appearance before generation`n`n" + $prompt
        $cells = @(for ($i = 0; $i -lt $boardOrder.Count; $i++) {
            [ordered]@{ state = $boardOrder[$i]; direction = $direction.id; rect = $null; planned_board_row = [int][Math]::Floor($i / 2); planned_board_column = $i % 2; status = 'pending_source_and_measured_crop' }
        })
        $pages += [ordered]@{ id = $direction.id; path = "res://$relative/$($direction.id).png"; sha256 = $null; reference_cell_width = $null; status = 'pending_generation'; cells = $cells }
    }
    $layout = [ordered]@{ schema_version = 2; champion_id = $champion.id; body = $champion.body_type; standing_height = $height; status = 'scaffold_not_buildable'; planned_cells = 80; live_promotion = $false; visual_review = @{ status = 'pending'; limits = 'No generated sources, crops, hashes or visual approval exist yet.' }; pages = $pages }
    return [pscustomobject]@{ destination = $destination; relative_path = $relative; summary = $summary; worksheet = $worksheet; receipt = $receipt; layout = $layout; contract = $contract; prompts = $prompts }
}

function New-FluxCharacterArtBatch([string]$RepoRoot, [string]$Identity, [string]$Batch) {
    $plan = Get-FluxCharacterArtBatchPlan $RepoRoot $Identity $Batch
    $parent = [IO.Path]::GetDirectoryName($plan.destination)
    if (-not (Test-Path -LiteralPath $parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    Assert-FluxArtPath $parent
    New-Item -ItemType Directory -Path $plan.destination -ErrorAction Stop | Out-Null
    $files = [ordered]@{
        'identity.json' = ($plan.summary | ConvertTo-Json -Depth 20)
        'champion-worksheet.json' = ($plan.worksheet | ConvertTo-Json -Depth 20)
        'contract.snapshot.json' = ($plan.contract | ConvertTo-Json -Depth 20)
        'source-layout.scaffold.json' = ($plan.layout | ConvertTo-Json -Depth 20)
        'review-receipt.pending.json' = ($plan.receipt | ConvertTo-Json -Depth 20)
        'README.md' = @"
# $($plan.summary.display_name) - new art batch

Status: pending appearance review and generation. No artwork or promotion exists.
Canonical ID: $Identity; race: $($plan.summary.race_id); body: $($plan.summary.body_type), $($plan.summary.standing_height_pixels)px.

1. Resolve appearance from approved references into champion-worksheet.json; no example palette/clothing was silently assigned.
2. Use eight one-heading prompts. Keep original generated source PNGs immutable; the planned2x5 board pairs A/B contacts.
3. Fill source-layout.scaffold.json with actual source hashes, measured crops and page-wide calibration. Null placeholders intentionally fail assembly; do not replace them with guessed values.
4. Assemble an isolated candidate with scripts/build_character_style_pack.gd, then run native sheet QA.
5. Complete all80 pending review cells against the actual candidate SHA and evidence. Agent review is not final human approval.
6. Run scripts/validate-character-art-review.ps1, integration tests and the Full gate before any new live promotion.

The existing game, catalog, art registry, sprites and installer are untouched.
Runtime stays80 slots/8headings,96px cells,48/84 pivot; each whole body uses one immutable scale. Effects remain separate and hands empty.
"@
    }
    foreach ($key in $plan.prompts.Keys) { $files[$key] = $plan.prompts[$key] }
    foreach ($name in $files.Keys) {
        $path = Join-Path $plan.destination $name
        Assert-FluxArtPath $path
        $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try { $writer.Write([string]$files[$name]); $writer.Write("`n") } finally { $writer.Dispose() }
    }
    return [pscustomobject]@{ created = $plan.destination; champion_id = $Identity; display_name = $plan.summary.display_name; body_type = $plan.summary.body_type; files = $files.Count; heading_prompts = 8; pending_cells = 80; live_promotion = $false }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($ChampionId)) { throw 'Use -ChampionId <exact canonical ID> [-BatchName <new-safe-slug>]. No source artwork or live files are generated.' }
    New-FluxCharacterArtBatch ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) $ChampionId $BatchName | ConvertTo-Json
}
