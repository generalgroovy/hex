Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'validate-character-art-review.ps1')
$reviewRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$candidate = Join-Path $reviewRoot 'assets/sprites/champions_v3/style_v1/jan-wicked-v1.png'
$contract = Get-Content -LiteralPath (Join-Path $reviewRoot 'art_batches/character_style_v1/template_v2/contract.json') -Raw | ConvertFrom-Json
$baseline = Get-Content -LiteralPath (Join-Path $reviewRoot 'content/visual/foundation_champion_visuals_v1.json') -Raw | ConvertFrom-Json
$receipt = Get-Content -LiteralPath (Join-Path $reviewRoot 'art_batches/character_style_v1/template_v2/review-receipt.template.json') -Raw | ConvertFrom-Json
$assertions = 0
$cases = [Collections.Generic.List[string]]::new()
function Assert-Review([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Copy-Review($Value) { return $Value | ConvertTo-Json -Depth 20 | ConvertFrom-Json }
function Check-Review($Value) { return Test-FluxCharacterArtReview $Value $candidate 'jan_wicked' 'middle' $reviewRoot }
function Reject-Review([string]$Name, [scriptblock]$Mutation) {
    $copy = Copy-Review $script:receipt
    & $Mutation $copy
    $result = Check-Review $copy
    Assert-Review (-not $result.metadata_valid) "$Name must reject inconsistent metadata."
    Assert-Review (-not $result.promotion_ready) "$Name must not approve promotion."
    Assert-Review ($result.diagnostics.Count -gt 0) "$Name must explain rejection."
    $script:cases.Add($Name)
}

# Pure in-memory fixtures. These strings intentionally simulate attestations;
# they are never written as an actual art approval or used to promote Jan.
$receipt.champion_id = 'jan_wicked'
$receipt.body_type = 'middle'
$receipt.candidate_sha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
$receipt.reviewer.id = 'SYNTHETIC_TEST_FIXTURE_NOT_ART_ACCEPTANCE'
$receipt.reviewed_at_utc = '2026-09-08T12:00:00Z'
$pending = Check-Review $receipt
Assert-Review $pending.metadata_valid 'An honest80-cell pending receipt is structurally valid.'
Assert-Review (-not $pending.promotion_ready -and $pending.pending_cells -eq 80) 'Pending is never promotion-ready.'
$cases.Add('honest pending')
$receipt.status = 'approved'
$receipt.visual_attestation = $true
foreach ($cell in $receipt.cells) {
    $cell.decision = 'approved'
    $cell.heading = 'readable'
    $cell.body_volume = 'stable'
    if ($cell.state -in @('walk','sprint')) { $cell.support_leg = 'left'; $cell.arm_counter_swing = 'opposed' }
    if ($cell.state -in @('walk_b','sprint_b')) { $cell.support_leg = 'right'; $cell.arm_counter_swing = 'opposed' }
}
$evidenceKinds = @('native_light_contacts','native_dark_contacts','native_gait_review','in_game_review','portrait_review')
$evidencePaths = @('docs/evidence/character-pages-v1/swayne-wellspring.png','docs/evidence/character-pages-v1/waka-wellspring.png','docs/evidence/character-pages-v1/jan-wellspring.png','docs/evidence/character-pages-v1/gallery-four-pages.png','docs/evidence/character-pages-v1/farflow-pair-wide.png')
$receipt.evidence = @(for ($i = 0; $i -lt 5; $i++) {
    [pscustomobject]@{ kind = $evidenceKinds[$i]; path = $evidencePaths[$i]; sha256 = (Get-FileHash -LiteralPath (Join-Path $reviewRoot $evidencePaths[$i]) -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$approved = Check-Review $receipt
Assert-Review ($approved.metadata_valid -and $approved.promotion_ready -and $approved.approved_cells -eq 80) 'A complete internally consistent synthetic attestation is admitted.'
Assert-Review ($approved.evidence_boundary -match 'no automated anatomy' -and $approved.evidence_boundary -match 'Does not modify') 'Result preserves the vision and mutation boundary.'
$cases.Add('synthetic approval metadata only')

Reject-Review 'stale candidate' { param($r) $r.candidate_sha256 = '0' * 64 }
Reject-Review 'missing hash' { param($r) $r.candidate_sha256 = '' }
Reject-Review 'identity mismatch' { param($r) $r.champion_id = 'steezo' }
Reject-Review 'body mismatch' { param($r) $r.body_type = 'large' }
Reject-Review 'five-size legacy body' { param($r) $r.body_type = 'size_3_medium' }
Reject-Review 'schema string' { param($r) $r.schema_version = '1' }
Reject-Review 'wrong contract' { param($r) $r.contract_id = 'anything' }
Reject-Review 'missing reviewer' { param($r) $r.reviewer.id = '' }
Reject-Review 'unclear reviewer identity' { param($r) $r.reviewer.kind = 'approved_by_computer' }
Reject-Review 'false attestation' { param($r) $r.visual_attestation = $false }
Reject-Review 'string attestation' { param($r) $r.visual_attestation = 'true' }
Reject-Review 'missing attestation' { param($r) $r.PSObject.Properties.Remove('visual_attestation') }
Reject-Review 'malformed date' { param($r) $r.reviewed_at_utc = '2026-99-08T12:00:00Z' }
Reject-Review 'missing cell' { param($r) $r.cells = @($r.cells | Select-Object -First 79) }
Reject-Review 'duplicate cell' { param($r) $r.cells[79] = Copy-Review $r.cells[0] }
Reject-Review 'unknown direction' { param($r) $r.cells[0].direction = 'up_right' }
Reject-Review 'unknown state' { param($r) $r.cells[0].state = 'moonwalk' }
Reject-Review 'unreadable approved heading' { param($r) $r.cells[3].heading = 'ambiguous' }
Reject-Review 'unreviewed approved heading' { param($r) $r.cells[3].heading = 'unreviewed' }
Reject-Review 'unstable approved body' { param($r) $r.cells[3].body_volume = 'unstable' }
Reject-Review 'repeated walk foot' { param($r) $r.cells[64].support_leg = 'left' }
Reject-Review 'repeated sprint foot' { param($r) $r.cells[72].support_leg = 'left' }
Reject-Review 'fake non-gait support' { param($r) $r.cells[0].support_leg = 'left' }
Reject-Review 'gait claimed nonapplicable' { param($r) $r.cells[32].support_leg = 'not_applicable' }
Reject-Review 'screen-side foot claim' { param($r) $r.cells[32].support_leg = 'screen_left' }
Reject-Review 'wrong arm swing' { param($r) $r.cells[32].arm_counter_swing = 'incorrect' }
Reject-Review 'hidden held cell' { param($r) $r.cells[3].decision = 'held'; $r.cells[3].heading = 'ambiguous' }
Reject-Review 'held cell without reason' { param($r) $r.status = 'held'; $r.cells[3].decision = 'held'; $r.cells[3].note = '' }
Reject-Review 'held status without held cell' { param($r) $r.status = 'held' }
Reject-Review 'pending status without pending cell' { param($r) $r.status = 'pending' }
Reject-Review 'missing review evidence' { param($r) $r.evidence = @() }
Reject-Review 'stale evidence' { param($r) $r.evidence[0].sha256 = '0' * 64 }
Reject-Review 'duplicate evidence artifact' { param($r) $r.evidence[1].path = $r.evidence[0].path; $r.evidence[1].sha256 = $r.evidence[0].sha256 }
Reject-Review 'missing required view' { param($r) $r.evidence[4].kind = 'native_light_contacts' }
Reject-Review 'escaping evidence' { param($r) $r.evidence[0].path = '../README.md' }
Reject-Review 'absolute evidence' { param($r) $r.evidence[0].path = $candidate }
Reject-Review 'invalid enum decision' { param($r) $r.cells[0].decision = $true }
Reject-Review 'malformed cells' { param($r) $r.cells = 'looks good' }

$held = Copy-Review $receipt
$held.status = 'held'
$held.cells[3].decision = 'held'
$held.cells[3].heading = 'ambiguous'
$held.cells[3].note = 'Rear diagonal reads as profile; keep current live page pending repair.'
$heldResult = Check-Review $held
Assert-Review ($heldResult.metadata_valid -and -not $heldResult.promotion_ready -and $heldResult.held_cells -eq 1) 'A truthful hold stays inspectable but blocks promotion.'
$cases.Add('honest directional hold')
$missing = Test-FluxCharacterArtReview $receipt (Join-Path $reviewRoot 'not-an-existing-character.png') 'jan_wicked' 'middle' $reviewRoot
Assert-Review (-not $missing.metadata_valid -and -not $missing.promotion_ready) 'Missing candidate fails closed.'
$invalidPng = Test-FluxCharacterArtReview $receipt (Join-Path $reviewRoot 'README.md') 'jan_wicked' 'middle' $reviewRoot
Assert-Review (-not $invalidPng.metadata_valid -and -not $invalidPng.promotion_ready) 'Text cannot stand in for the candidate PNG.'
Assert-Review (($contract.body_build_order -join ',') -ceq 'small,middle,large') 'Contract has three bodies smallest first.'
Assert-Review (($contract.rows -join ',') -ceq ($baseline.atlas.states -join ',')) 'Rows reuse live grammar.'
Assert-Review (($contract.directions.id -join ',') -ceq ($baseline.atlas.directions -join ',')) 'Directions reuse live grammar.'
Assert-Review (($contract.cell -join ',') -ceq '96,96' -and ($contract.feet_pivot -join ',') -ceq '48,84') 'Shared geometry remains unchanged.'
foreach ($body in @('small','middle','large')) { Assert-Review ($contract.standing_height_pixels.$body -eq $baseline.body_template_contract.templates.$body.reference_height) "$body height agrees with live template." }
for ($i = 0; $i -lt 8; $i++) { Assert-Review ($contract.directions[$i].yaw_degrees -eq $i * 45) "Yaw target$i follows the stated art convention." }
Assert-Review ($contract.source_board.default_heading_count -eq 1 -and $contract.source_board.maximum_heading_count -eq 2) 'Dense uncontrolled source boards are not the production default.'
Assert-Review ($contract.post_template_character_style.activation -ceq 'after_all_three_templates_complete_all_animations_and_eight_directions_and_user_acceptance') 'New cast style remains behind complete animation/direction and user acceptance gate.'
Assert-Review ($contract.post_template_character_style.body_only -eq $true -and $contract.post_template_character_style.live_promotion -eq $false) 'New reference never silently promotes artwork or includes effect layers.'
Assert-Review ((Get-FileHash -LiteralPath (Join-Path $reviewRoot $contract.post_template_character_style.path) -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $contract.post_template_character_style.sha256) 'Preserved cast reference matches its recorded immutable hash.'
Assert-Review ($contract.portrait.crop -match 'top third' -and $contract.portrait.crop -match 'ceil' -and $contract.portrait.crop -match 'No separate manual') 'Portrait remains the exact automatic top-third crop.'
$cases.Add('current contract coherence')
[pscustomobject]@{ passed = $true; assertions = $assertions; cases = $cases.Count; failures = 0; scope = 'Synthetic metadata fixtures only; no art approval, PNG writes, import cache or registry mutation.' } | ConvertTo-Json
