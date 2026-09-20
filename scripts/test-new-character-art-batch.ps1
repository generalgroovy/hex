Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'new-character-art-batch.ps1')
$batchRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$batchAssertions = 0
$batchCases = 0
function Assert-Batch([bool]$Condition, [string]$Message) {
    $script:batchAssertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Reject-Batch([string]$Name, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert-Batch $rejected "$Name must be rejected."
    $script:batchCases++
}
$batchCatalog = Get-Content -LiteralPath (Join-Path $batchRepo 'content/champions/foundation_champions_v1.json') -Raw | ConvertFrom-Json
$batchSlug = 'test-plan-' + [Guid]::NewGuid().ToString('N')
$protectedFiles = @('content/champions/foundation_champions_v1.json','content/visual/champion_page_overrides_v1.json','assets/sprites/champions_v3/style_v1/jan-wicked-v1.png')
$protectedHashes = @{}
foreach ($file in $protectedFiles) { $protectedHashes[$file] = (Get-FileHash -LiteralPath (Join-Path $batchRepo $file) -Algorithm SHA256).Hash }

foreach ($champion in $batchCatalog.champions) {
    $plan = Get-FluxCharacterArtBatchPlan $batchRepo $champion.id $batchSlug
    Assert-Batch ($plan.summary.champion_id -ceq $champion.id -and $plan.summary.display_name -ceq $champion.display_name) 'Every current canonical identity/name is preserved.'
    Assert-Batch ($plan.summary.body_type -ceq $champion.body_type -and $plan.summary.race_id -ceq $champion.ancestry) 'Race/body come from the catalog.'
    Assert-Batch ($plan.prompts.Count -eq 8 -and $plan.layout.pages.Count -eq 8 -and $plan.receipt.cells.Count -eq 80) 'Each profile has eight prompts and80 pending semantic cells.'
    Assert-Batch (-not (Test-Path -LiteralPath $plan.destination)) 'Planning creates no destination.'
    Assert-Batch ($null -eq $plan.receipt.candidate_sha256 -and -not $plan.receipt.visual_attestation -and -not $plan.summary.live_promotion) 'No invented candidate hash or visual approval.'
    foreach ($field in @('skin','primary','secondary','accent','hair','anatomy','clothing')) { Assert-Batch ($plan.worksheet.$field -ceq 'PENDING_APPROVED_IDENTITY_REFERENCE_REVIEW') 'Worksheet example appearance never leaks to another identity.' }
    $slots = @{}
    foreach ($page in $plan.layout.pages) {
        Assert-Batch ($null -eq $page.sha256 -and $null -eq $page.reference_cell_width) 'Ungenerated source hashes/calibration remain unknown.'
        foreach ($cell in $page.cells) {
            $key = "$($cell.state)/$($cell.direction)"
            Assert-Batch ($null -eq $cell.rect -and -not $slots.ContainsKey($key)) 'Every source slot is unique with an explicitly unmeasured crop.'
            $slots[$key] = $true
        }
    }
    Assert-Batch ($slots.Count -eq 80) 'All canonical semantic slots are scaffolded without manual typing.'
    Assert-Batch (@($plan.receipt.cells | Where-Object { $_.decision -cne 'pending' }).Count -eq 0) 'All review cells remain pending.'
    $script:batchCases++
}
Assert-Batch ($batchCatalog.champions.Count -eq 30) 'Current roster test explicitly covers30 profiles.'
Assert-Batch ((Get-FluxCharacterArtBatchPlan $batchRepo 'nico_lai' $batchSlug).summary.display_name -ceq 'Waka Aren Si') 'Retained nico_lai ID has the current display name.'
Assert-Batch ((Get-FluxCharacterArtBatchPlan $batchRepo 'donnok' $batchSlug).summary.display_name -ceq 'Don Doko Don') 'Retained donnok ID has the current display name.'
foreach ($id in @('waka_aren_si','don_doko_don','samwise','unknown','../jan_wicked','Jan_Wicked','S. Wayne')) {
    Reject-Batch "unknown/unsafe ID $id" { Get-FluxCharacterArtBatchPlan $batchRepo $id $batchSlug }
}
foreach ($slug in @('../escape','nested/path','nested\path','C:\escape','UPPER','con','nul','com1','with space','.','..','')) {
    Reject-Batch "unsafe slug $slug" { Get-FluxCharacterArtBatchPlan $batchRepo 'jan_wicked' $slug }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('flux-art-batch-test-' + [Guid]::NewGuid().ToString('N'))
$junction = $null
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $fixtureRepo = Join-Path $fixture 'repo'
    $inputs = @('content/champions/foundation_champions_v1.json','art/templates/champion_profile_v2.json','art_batches/character_style_v1/template_v2/contract.json','art_batches/character_style_v1/template_v2/GENERATION-PROMPT.md','art_batches/character_style_v1/template_v2/review-receipt.template.json')
    foreach ($inputPath in $inputs) {
        $target = Join-Path $fixtureRepo $inputPath
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        [IO.File]::Copy((Join-Path $batchRepo $inputPath), $target, $false)
    }
    foreach ($id in @('s_wayne','oh_tipi','red_baron','nico_lai','donnok')) {
        $result = New-FluxCharacterArtBatch $fixtureRepo $id 'fixture-v1'
        $files = @(Get-ChildItem -LiteralPath $result.created -File)
        Assert-Batch ($files.Count -eq 14 -and $result.heading_prompts -eq 8 -and -not $result.live_promotion) 'One batch creates exactly14 draft files, no artwork.'
        Assert-Batch (@($files | Where-Object { $_.Extension -eq '.png' }).Count -eq 0) 'Scaffolding never synthesizes images.'
        $layout = Get-Content -LiteralPath (Join-Path $result.created 'source-layout.scaffold.json') -Raw | ConvertFrom-Json
        Assert-Batch ($layout.status -ceq 'scaffold_not_buildable' -and $null -eq $layout.pages[0].cells[0].rect) 'Serialized scaffold cannot claim measured source crops.'
        $firstPrompt = Get-Content -LiteralPath (Join-Path $result.created 'north_east-prompt.md') -Raw
        Assert-Batch ($firstPrompt -match '135 degrees' -and $firstPrompt -match 'Rear-right' -and $firstPrompt -match 'Appearance PENDING') 'A one-heading prompt carries exact yaw cues and unresolved appearance honestly.'
        $before = (Get-FileHash -LiteralPath (Join-Path $result.created 'identity.json')).Hash
        Reject-Batch 'existing batch overwrite' { New-FluxCharacterArtBatch $fixtureRepo $id 'fixture-v1' }
        Assert-Batch ((Get-FileHash -LiteralPath (Join-Path $result.created 'identity.json')).Hash -ceq $before) 'Rejected overwrite preserves existing files byte-for-byte.'
        $script:batchCases++
    }
    $fileTarget = Join-Path $fixtureRepo 'art_batches/character_style_v1/jan_wicked/file-target'
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fileTarget)) | Out-Null
    [IO.File]::WriteAllText($fileTarget, 'existing file must be preserved')
    Reject-Batch 'existing file target' { New-FluxCharacterArtBatch $fixtureRepo 'jan_wicked' 'file-target' }
    $outside = Join-Path $fixture 'outside-target'
    New-Item -ItemType Directory -Path $outside | Out-Null
    $junction = Join-Path $fixtureRepo 'art_batches/character_style_v1/steezo'
    New-Item -ItemType Junction -Path $junction -Target $outside | Out-Null
    Reject-Batch 'reparse champion directory' { New-FluxCharacterArtBatch $fixtureRepo 'steezo' 'forbidden' }
    Assert-Batch (@(Get-ChildItem -LiteralPath $outside -Force).Count -eq 0) 'Reparse rejection writes nothing to its target.'
    foreach ($file in $protectedFiles) { Assert-Batch ((Get-FileHash -LiteralPath (Join-Path $batchRepo $file) -Algorithm SHA256).Hash -ceq $protectedHashes[$file]) 'Live catalog, registry and representative sprite remain byte-identical.' }
} finally {
    if ($null -ne $junction -and (Test-Path -LiteralPath $junction)) { Remove-Item -LiteralPath $junction -Force }
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolvedFixture) -cnotmatch '^flux-art-batch-test-[0-9a-f]{32}$') { throw 'Refusing cleanup outside the exact owned test fixture.' }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
[pscustomobject]@{ passed = $true; assertions = $batchAssertions; cases = $batchCases; failures = 0; scope = 'All27 plans; isolated three-body/retained-ID writes; no live artwork/catalog/registry changes; owned fixtures removed.' } | ConvertTo-Json
