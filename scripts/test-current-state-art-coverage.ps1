param([string]$OutputPath = '.godot/art-coverage-20260908/regression-report.json')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$coverageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
# Load only the trusted audit function, not current-state's report-producing main.
# Fixtures are in-memory descriptor copies; no catalog, registry or PNG is edited.
$coverageTokens = $null
$coverageParseErrors = $null
$coverageAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'current-state.ps1'), [ref]$coverageTokens, [ref]$coverageParseErrors)
if ($coverageParseErrors.Count -gt 0) { throw ($coverageParseErrors | Out-String) }
$coverageFunctions = @($coverageAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in @('Get-FluxCharacterArtCoverage','Get-FluxActiveCharacterArtCoverage') }, $true))
if ($coverageFunctions.Count -ne 2) { throw 'Expected exactly two independent current source art-audit functions.' }
foreach ($coverageFunction in $coverageFunctions) { Invoke-Expression $coverageFunction.Extent.Text }

$coverageCatalog = Get-Content -LiteralPath (Join-Path $coverageRoot 'content/champions/foundation_champions_v1.json') -Raw | ConvertFrom-Json
$coverageVisual = Get-Content -LiteralPath (Join-Path $coverageRoot 'content/visual/foundation_champion_visuals_v1.json') -Raw | ConvertFrom-Json
$coverageOverrides = Get-Content -LiteralPath (Join-Path $coverageRoot 'content/visual/champion_page_overrides_v1.json') -Raw | ConvertFrom-Json
$coverageAssertions = 0
$coverageCases = [Collections.Generic.List[string]]::new()
function Assert-Coverage([bool]$Condition, [string]$Message) {
    $script:coverageAssertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Copy-Descriptor($Value) { return $Value | ConvertTo-Json -Depth 60 | ConvertFrom-Json }
function Audit($Catalog = $coverageCatalog, $Visual = $coverageVisual, $Overrides = $coverageOverrides, [bool]$Present = $true) {
    return Get-FluxCharacterArtCoverage $coverageRoot $Catalog $Visual $Overrides $Present
}
function Reject-Descriptor([string]$Name, [string]$Code, $Catalog = $coverageCatalog, $Visual = $coverageVisual, $Overrides = $coverageOverrides) {
    $result = Audit $Catalog $Visual $Overrides
    Assert-Coverage (-not $result.source_validation_passed) "$Name must reject source coverage."
    Assert-Coverage ($null -eq $result.effective_individual_count -and $null -eq $result.effective_template_count) "$Name must withhold effective counts, not report a partial accepted registry."
    Assert-Coverage (@($result.diagnostics | Where-Object { $_.code -eq $Code }).Count -gt 0) "$Name must explain $Code."
    $coverageCases.Add($Name)
}

$coverageBaselineIds = @($coverageVisual.champions.PSObject.Properties.Name | Sort-Object)
$coverageOverrideIds = @($coverageOverrides.pages.PSObject.Properties.Name | Sort-Object)
$coverageExpectedIndividuals = @($coverageBaselineIds + $coverageOverrideIds | Sort-Object -Unique)
$coverageLive = Audit
Assert-Coverage $coverageLive.source_validation_passed 'Current source assets must validate.'
Assert-Coverage ($coverageLive.playable_count -eq 30) 'Current catalog retains 30 playable identities.'
Assert-Coverage ($coverageLive.catalog_fallback_declaration_count -eq 25) 'Catalog provenance still contains 25 fallback declarations.'
Assert-Coverage ($coverageLive.effective_individual_count -eq $coverageExpectedIndividuals.Count) 'Effective individual count is a union, never baseline plus raw override count.'
Assert-Coverage ($coverageLive.effective_template_count -eq 30 - $coverageExpectedIndividuals.Count) 'Effective templates are the remaining catalog identities.'
Assert-Coverage (($coverageLive.validated_registry_declared_override_ids -join ',') -ceq ($coverageOverrideIds -join ',')) 'Validated registry IDs retain exact declared identities.'
Assert-Coverage ($coverageLive.effective_identities.Count -eq 30) 'Every source-valid identity has a classification.'
Assert-Coverage ($coverageLive.evidence -match 'Not imported-RGBA' -and $coverageLive.evidence -match 'human art approval') 'Source evidence boundary must remain explicit.'
$coverageCases.Add('current catalog and source registry')

$coverageAbsent = Audit -Overrides $null -Present $false
Assert-Coverage $coverageAbsent.source_validation_passed 'Absent optional registry retains baseline source coverage.'
Assert-Coverage ($coverageAbsent.effective_individual_count -eq $coverageBaselineIds.Count -and $coverageAbsent.effective_template_count -eq 25) 'Absent override registry does not invent individual art.'
Assert-Coverage ($coverageAbsent.validated_registry_declared_override_ids -is [array] -and $coverageAbsent.validated_registry_declared_override_ids.Count -eq 0) 'Empty validated IDs serialize as an array, not null.'
$coverageCases.Add('absent optional registry')

$coverageOne = Copy-Descriptor $coverageOverrides
$coverageOne.pages = [pscustomobject]@{ oh_tipi = $coverageOverrides.pages.oh_tipi }
$coverageOverlap = Audit -Overrides $coverageOne
Assert-Coverage $coverageOverlap.source_validation_passed 'A foundation override remains valid.'
Assert-Coverage ($coverageOverlap.effective_individual_count -eq $coverageBaselineIds.Count) 'Replacing Oh Tipi does not add an individual identity.'
Assert-Coverage ($coverageOverlap.validated_registry_declared_override_ids -is [array] -and $coverageOverlap.validated_registry_declared_override_ids.Count -eq 1) 'One validated ID also remains an array.'
$coverageCases.Add('foundation override overlap')
$coverageOne.pages = [pscustomobject]@{ steezo = $coverageOverrides.pages.steezo }
$coverageAlias = Audit -Overrides $coverageOne
Assert-Coverage ($coverageAlias.source_validation_passed -and $coverageAlias.effective_individual_count -eq $coverageBaselineIds.Count + 1) 'Steezo override replaces exactly one template.'
Assert-Coverage ($coverageAlias.catalog_fallback_declaration_count -eq 25) 'An override never rewrites catalog provenance in the report.'
$coverageTemplate = @($coverageAlias.effective_identities | Where-Object { $_.champion_id -eq 'luuh_i_zeh' })[0]
Assert-Coverage ($coverageTemplate.classification -eq 'body_template' -and $coverageTemplate.source_identity -eq 's_wayne') 'Other aliases do not inherit an exemplar override as individual art.'
Assert-Coverage ($coverageTemplate.source_path -ceq $coverageVisual.atlas.path) 'A body alias explicitly reports the old baseline atlas, not its exemplar override.'
$coverageCases.Add('alias override without inherited uniqueness')

foreach ($coverageField in @('path','sha256','imported_rgba_sha256')) {
    $coverageBad = Copy-Descriptor $coverageOverrides
    $coverageBad.pages.steezo.$coverageField = $coverageVisual.extension_atlases.grace_reava.$coverageField
    Reject-Descriptor "cross-baseline extension $coverageField" 'override_baseline_duplicate' -Overrides $coverageBad
}
$coverageSamePage = Copy-Descriptor $coverageOverrides.pages.s_wayne
foreach ($coverageField in @('path','sha256','imported_rgba_sha256')) { $coverageSamePage.$coverageField = $coverageVisual.extension_atlases.grace_reava.$coverageField }
$coverageSamePage.visible_feet_y = 84
$coverageSame = Copy-Descriptor $coverageOverrides
$coverageSame.pages = [pscustomobject]@{ grace_reava = $coverageSamePage }
$coverageSameResult = Audit -Overrides $coverageSame
Assert-Coverage $coverageSameResult.source_validation_passed 'Same-identity baseline extension replacement is permitted.'
Assert-Coverage ($coverageSameResult.effective_individual_count -eq $coverageBaselineIds.Count) 'Same-identity replacement adds no individual coverage.'
Assert-Coverage ($coverageSameResult.evidence -match 'foundation.*runtime') 'Source-only audit explains that foundation crop identity requires runtime decoded checks.'
Assert-Coverage (-not $coverageSameResult.decoded_identity_uniqueness_verified) 'Raw metadata must not claim independent decoded-pixel uniqueness.'
$coverageCases.Add('same-identity baseline extension replacement')
$coverageFullClone = Copy-Descriptor $coverageOverrides
$coverageFullClone.pages = [pscustomobject]@{ steezo = (Copy-Descriptor $coverageSamePage) }
Reject-Descriptor 'fully source-valid extension clone under alias' 'override_baseline_duplicate' -Overrides $coverageFullClone

$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages | Add-Member -NotePropertyName 'not_a_champion' -NotePropertyValue (Copy-Descriptor $coverageBad.pages.oh_tipi)
Reject-Descriptor 'unknown identity' 'override_identity' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.body_type = 'large'
Reject-Descriptor 'wrong body' 'override_body' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.reference_height = 68
Reject-Descriptor 'wrong body guide' 'override_body' -Overrides $coverageBad
foreach ($coveragePath in @('res://assets/sprites/champions_v3/../../outside.png','res://assets/sprites/champions_v3/./bad.png','res://assets/sprites/champions_v3//bad.png','res://assets/sprites/champions_v3\bad.png','res://other/bad.png')) {
    $coverageBad = Copy-Descriptor $coverageOverrides
    $coverageBad.pages.steezo.path = $coveragePath
    Reject-Descriptor "unsafe path $coveragePath" 'page_path' -Overrides $coverageBad
}
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.path = 'res://assets/sprites/champions_v3/bad' + [char]0 + '.png'
Reject-Descriptor 'unresolvable path' 'page_path' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.path = 'res://assets/sprites/champions_v3/missing-art-coverage-fixture.png'
Reject-Descriptor 'missing raw PNG' 'page_missing' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.sha256 = '0' * 64
Reject-Descriptor 'changed source digest' 'page_sha256' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.imported_rgba_sha256 = 'not-a-digest'
Reject-Descriptor 'malformed declared decoded digest' 'page_digest' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.path = $coverageBad.pages.s_wayne.path
Reject-Descriptor 'duplicate override path' 'override_duplicate' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.sha256 = $coverageBad.pages.s_wayne.sha256
Reject-Descriptor 'duplicate raw identity digest' 'override_duplicate' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.imported_rgba_sha256 = $coverageBad.pages.s_wayne.imported_rgba_sha256
Reject-Descriptor 'duplicate declared decoded identity digest' 'override_duplicate' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.path = $coverageVisual.atlas.path
$coverageBad.pages.steezo.sha256 = $coverageVisual.atlas.sha256
Reject-Descriptor 'wrong real PNG dimensions' 'page_dimensions' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.frame_count = 79
Reject-Descriptor 'incomplete row contract' 'override_contract' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.cell[0] = '96'
Reject-Descriptor 'string geometry rejected' 'override_contract' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.visible_feet_y = '83'
Reject-Descriptor 'string feet registration rejected' 'override_registration' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.schema_version = '1'
Reject-Descriptor 'string schema rejected' 'override_contract' -Overrides $coverageBad
$coverageBad = Copy-Descriptor $coverageOverrides
$coverageBad.pages.steezo.reference_height = '58'
Reject-Descriptor 'string height rejected' 'override_body' -Overrides $coverageBad
Reject-Descriptor 'malformed registry root' 'override_contract' -Overrides $null
$coverageBadVisual = Copy-Descriptor $coverageVisual
$coverageBadVisual.atlas.sha256 = '0' * 64
Reject-Descriptor 'baseline source digest changed' 'page_sha256' -Visual $coverageBadVisual
$coverageBadVisual = Copy-Descriptor $coverageVisual
$coverageBadVisual.extension_atlases.PSObject.Properties.Remove('wa_bidi')
Reject-Descriptor 'baseline extension missing' 'page_object' -Visual $coverageBadVisual
$coverageBadCatalog = Copy-Descriptor $coverageCatalog
($coverageBadCatalog.champions | Where-Object { $_.id -eq 'biggy_bob' }).template_source_id = 's_wayne'
Reject-Descriptor 'template wrong body' 'template_registration' -Catalog $coverageBadCatalog

$coverageManifest = Get-Content -Raw -LiteralPath (Join-Path $coverageRoot 'assets/sprites/wireframe_motion_v2/manifest.json') | ConvertFrom-Json
$coveragePresenterSource = Get-Content -Raw -LiteralPath (Join-Path $coverageRoot 'src/presentation/cartoon_champion_presenter.gd')
$coverageBodySource = Get-Content -Raw -LiteralPath (Join-Path $coverageRoot 'src/presentation/wireframe_body_presenter.gd')
$coverageBootstrapSource = Get-Content -Raw -LiteralPath (Join-Path $coverageRoot 'src/app/bootstrap.gd')
function Audit-Active($Manifest = $coverageManifest, $Catalog = $coverageCatalog, [string]$Presenter = $coveragePresenterSource, [string]$Body = $coverageBodySource, [string]$Bootstrap = $coverageBootstrapSource, $Legacy = $coverageLive) {
    return Get-FluxActiveCharacterArtCoverage $coverageRoot $Catalog $Manifest $Presenter $Body $Bootstrap $Legacy
}
function Reject-Active([string]$Name, [string]$Code, $Manifest = $coverageManifest, $Catalog = $coverageCatalog, [string]$Presenter = $coveragePresenterSource, [string]$Body = $coverageBodySource, [string]$Bootstrap = $coverageBootstrapSource, $Legacy = $coverageLive) {
    $result = Audit-Active $Manifest $Catalog $Presenter $Body $Bootstrap $Legacy
    Assert-Coverage (-not $result.source_validation_passed) "$Name must reject active source coverage."
    Assert-Coverage ($null -eq $result.effective_individual_count -and $null -eq $result.effective_template_count -and $result.effective_identities.Count -eq 0) "$Name must withhold current effective totals and mappings."
    Assert-Coverage (@($result.diagnostics | Where-Object { $_.code -eq $Code }).Count -gt 0) "$Name must explain $Code."
    $coverageCases.Add($Name)
}
$coverageActive = Audit-Active
Assert-Coverage $coverageActive.source_validation_passed 'Current active wireframe source must validate independently of old page totals.'
Assert-Coverage ($coverageActive.active_presentation.mode -ceq 'wireframe_body') 'Default bootstrap/presenter binding resolves wireframe mode.'
Assert-Coverage ($coverageActive.effective_individual_count -eq 0 -and $coverageActive.effective_template_count -eq 30) 'Default live art is zero individual skins and 30 size-mapped profiles.'
Assert-Coverage ($coverageActive.active_presentation.shared_body_count -eq 3 -and $coverageActive.active_presentation.source_checked_pages.Count -eq 9 -and $coverageActive.active_presentation.shared_texture_count -eq 9) 'Three bodies share nine source-verified base/walk/sprint atlases.'
Assert-Coverage ($coverageActive.active_presentation.manifest_schema_version -eq 2 -and @($coverageActive.active_presentation.source_checked_pages | Where-Object { $_.kind -ceq 'sprint' }).Count -eq 3) 'Schema 2 validates one separate sprint source page for each body.'
Assert-Coverage ($coverageActive.active_presentation.size_profile_counts.small -eq 10 -and $coverageActive.active_presentation.size_profile_counts.middle -eq 10 -and $coverageActive.active_presentation.size_profile_counts.large -eq 10) 'Current body counts are derived from all 30 catalog entries.'
Assert-Coverage ($coverageActive.legacy_provenance.effective_individual_count -eq $coverageExpectedIndividuals.Count -and $coverageActive.legacy_provenance.catalog_fallback_declaration_count -eq 25) 'Old individual/fallback coverage is preserved only inside historical provenance.'
Assert-Coverage ($coverageActive.legacy_provenance_scope -match 'not the current default live presentation' -and $coverageActive.evidence -match 'Not executed presentation') 'Legacy and execution evidence boundaries remain explicit.'
foreach ($coverageIdentity in $coverageActive.effective_identities) {
    Assert-Coverage ($coverageIdentity.classification -ceq 'shared_size_wireframe' -and $coverageIdentity.source_identity -ceq $coverageIdentity.body_type) 'Each active identity uses its size, not another champion or ancestry, as its source identity.'
    Assert-Coverage ($coverageIdentity.sprint_path -ceq "res://assets/sprites/wireframe_motion_v2/$($coverageIdentity.body_type)-sprint.png" -and $coverageIdentity.sprint_path -cne $coverageIdentity.locomotion_path) 'Every identity explicitly reports its same-size separate sprint page.'
}
$coverageCases.Add('current source-default wireframe and preserved legacy provenance')
# The old direct default and the new known-flag adapter are both explicit
# source bindings. All mutations stay in memory; no startup or asset is edited.
$coverageGuardedStart = $coverageBootstrapSource.IndexOf('var pixel_body_pilot := OS.get_cmdline_user_args().has("--pixel-body-pilot")')
$coverageGuardedEnd = $coverageBootstrapSource.IndexOf('if fullbody_requested:', $coverageGuardedStart)
Assert-Coverage ($coverageGuardedStart -ge 0 -and $coverageGuardedEnd -gt $coverageGuardedStart) 'Current fixture contains the complete guarded startup block.'
$coverageLegacyBootstrap = $coverageBootstrapSource.Substring(0, $coverageGuardedStart) + "if not cartoon_champion_presenter.configure(visual_language):`n`t`treturn`n`t" + $coverageBootstrapSource.Substring($coverageGuardedEnd)
$coverageLegacyBinding = Audit-Active -Bootstrap $coverageLegacyBootstrap
Assert-Coverage $coverageLegacyBinding.source_validation_passed 'Preserved direct eager default remains a recognized source binding.'
Assert-Coverage ($coverageLegacyBinding.effective_template_count -eq 30) 'Legacy binding preserves all thirty size-mapped default identities.'
$coverageCases.Add('preserved direct eager startup binding')
foreach ($coverageMutation in @(
    @('unconditional Fullbody default', 'var fullbody_requested := OS.get_cmdline_user_args().has("--fullbody-art") or pixel_body_pilot or pixel_cast', 'var fullbody_requested := true'),
    @('unrecognized Fullbody flag', 'OS.get_cmdline_user_args().has("--pixel-cast")', 'OS.get_cmdline_user_args().has("--other-art")'),
    @('inverted default and opt-in branches', 'if fullbody_requested else cartoon_champion_presenter.configure(visual_language)', 'if not fullbody_requested else cartoon_champion_presenter.configure(visual_language)'),
    @('metadata-only call with wrong flags', 'configure_fullbody_startup(visual_language, pixel_body_pilot, pixel_cast)', 'configure_fullbody_startup(visual_language, false, false)'),
    @('unchecked startup readiness', 'if not characters_ready:', 'if false:'),
    @('startup failure no longer exits', 'get_tree().quit(1)', 'get_tree().quit(0)')
)) {
    $coverageMutatedBootstrap = $coverageBootstrapSource.Replace($coverageMutation[1], $coverageMutation[2])
    Assert-Coverage ($coverageMutatedBootstrap -cne $coverageBootstrapSource) "Binding tamper actually changes source: $($coverageMutation[0])"
    Reject-Active $coverageMutation[0] 'wireframe_source_binding' -Bootstrap $coverageMutatedBootstrap
}
foreach ($coverageMutation in @(
    @('eager metadata-only default', 'metadata_only: bool = false', 'metadata_only: bool = true'),
    @('eager branch skips body pages', '_configure_validated(visual_language, path) and', '_configure_validated(visual_language, path, true) and'),
    @('Fullbody candidate bypasses metadata validation', 'if not candidate._configure_validated(visual_language, path, true):', 'if false:'),
    @('Fullbody candidate loads unbounded banks', 'candidate.enable_fullbody_art(use_pixel_pilot, use_full_cast, true)', 'candidate.enable_fullbody_art(use_pixel_pilot, use_full_cast, false)')
)) {
    $coverageMutatedPresenter = $coveragePresenterSource.Replace($coverageMutation[1], $coverageMutation[2])
    Assert-Coverage ($coverageMutatedPresenter -cne $coveragePresenterSource) "Presenter tamper actually changes source: $($coverageMutation[0])"
    Reject-Active $coverageMutation[0] 'wireframe_source_binding' -Presenter $coverageMutatedPresenter
}
foreach ($coverageField in @('schema_version','cell','directions','base_rows')) {
    $coverageBad = Copy-Descriptor $coverageManifest
    switch ($coverageField) {
        'schema_version' { $coverageBad.schema_version = '2' }
        'cell' { $coverageBad.cell[0] = '96' }
        'directions' { $coverageBad.directions[0] = 'east' }
        'base_rows' { $coverageBad.base_rows[0] = 'missing' }
    }
    Reject-Active "wireframe malformed $coverageField" 'wireframe_manifest_contract' -Manifest $coverageBad
}
foreach ($coverageField in @('columns','rows','phases','index_formula','gait_policy')) {
    $coverageBad = Copy-Descriptor $coverageManifest
    $coverageBad.locomotion.$coverageField = 'invalid'
    Reject-Active "wireframe malformed layout $coverageField" 'wireframe_manifest_contract' -Manifest $coverageBad
}
foreach ($coveragePath in @('res://assets/sprites/wireframe_motion_v2/../small-base.png','res://assets/sprites/wireframe_motion_v2/middle-base.png','res://other/small-base.png')) {
    $coverageBad = Copy-Descriptor $coverageManifest
    $coverageBad.sizes.small.base = $coveragePath
    Reject-Active "wireframe wrong or unsafe path $coveragePath" 'wireframe_page_path' -Manifest $coverageBad
}
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.PSObject.Properties.Remove('middle')
Reject-Active 'wireframe missing size' 'wireframe_manifest_contract' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes | Add-Member -NotePropertyName 'huge' -NotePropertyValue (Copy-Descriptor $coverageBad.sizes.large)
Reject-Active 'wireframe extra size' 'wireframe_manifest_contract' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.reference_height = 68
Reject-Active 'wireframe wrong body height' 'wireframe_body' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.locomotion_dimensions[0] = 768
Reject-Active 'wireframe wrong declared atlas dimensions' 'wireframe_page_dimensions' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.base_sha256 = '0' * 64
Reject-Active 'wireframe changed raw source digest' 'wireframe_page_sha256' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.base_rgba_sha256 = 'not-a-digest'
Reject-Active 'wireframe malformed declared decoded digest' 'wireframe_page_digest' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.schema_version = 1
Reject-Active 'wireframe old schema cannot claim separate sprint coverage' 'wireframe_manifest_contract' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.locomotion.gait_policy = 'shared_stride_speed_dependent_cadence'
Reject-Active 'wireframe old cadence-only gait contract' 'wireframe_manifest_contract' -Manifest $coverageBad
foreach ($coverageBody in @('small','middle','large')) {
    $coverageBad = Copy-Descriptor $coverageManifest
    $coverageBad.sizes.$coverageBody.PSObject.Properties.Remove('sprint')
    Reject-Active "wireframe missing $coverageBody sprint path" 'wireframe_page_path' -Manifest $coverageBad
}
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.sprint = $coverageBad.sizes.small.locomotion
Reject-Active 'wireframe sprint cannot alias walk page' 'wireframe_page_path' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.sprint_sha256 = '0' * 64
Reject-Active 'wireframe changed sprint source digest' 'wireframe_page_sha256' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.sprint_sha256 = 'not-a-digest'
Reject-Active 'wireframe malformed sprint source digest' 'wireframe_page_digest' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.PSObject.Properties.Remove('sprint_rgba_sha256')
Reject-Active 'wireframe missing declared sprint pixel digest' 'wireframe_page_digest' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.sprint_dimensions = @(768,960)
Reject-Active 'wireframe wrong sprint atlas dimensions' 'wireframe_page_dimensions' -Manifest $coverageBad
$coverageBad = Copy-Descriptor $coverageManifest
$coverageBad.sizes.small.PSObject.Properties.Remove('sprint_dimensions')
Reject-Active 'wireframe missing sprint dimensions' 'wireframe_page_dimensions' -Manifest $coverageBad
Reject-Active 'wireframe missing manifest' 'wireframe_manifest_contract' -Manifest $null
$coverageBadCatalog = Copy-Descriptor $coverageCatalog
$coverageBadCatalog.champions[0].body_type = 'unknown'
Reject-Active 'wireframe unknown catalog body' 'wireframe_catalog_body' -Catalog $coverageBadCatalog
$coverageBadCatalog = Copy-Descriptor $coverageCatalog
$coverageBadCatalog.champions[1].id = $coverageBadCatalog.champions[0].id
Reject-Active 'wireframe duplicate catalog identity' 'wireframe_catalog_identity' -Catalog $coverageBadCatalog
Reject-Active 'wireframe disabled presenter default' 'wireframe_source_binding' -Presenter ($coveragePresenterSource.Replace('use_wireframe: bool = true','use_wireframe: bool = false'))
Reject-Active 'wireframe changed body manifest binding' 'wireframe_source_binding' -Body ($coverageBodySource.Replace('wireframe_motion_v2/manifest.json','other/manifest.json'))
Reject-Active 'wireframe bootstrap opts out of default' 'wireframe_source_binding' -Bootstrap ($coverageBootstrapSource.Replace('cartoon_champion_presenter.configure(visual_language)','cartoon_champion_presenter.configure(visual_language, "", "", false)'))
$coverageBrokenLegacy = Copy-Descriptor $coverageOverrides
$coverageBrokenLegacy.pages.steezo.sha256 = '0' * 64
Reject-Active 'active wireframe does not bypass failed legacy audit' 'page_sha256' -Legacy (Audit -Overrides $coverageBrokenLegacy)

if (-not [IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $coverageRoot $OutputPath }
$coverageOutput = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $coverageOutput) -Force | Out-Null
$coverageReceipt = [ordered]@{
    passed = $true; assertions = $coverageAssertions; cases = @($coverageCases)
    current_counts = [ordered]@{ playable = $coverageActive.playable_count; shared_bodies = $coverageActive.active_presentation.shared_body_count; shared_textures = $coverageActive.active_presentation.shared_texture_count; manifest_schema_version = $coverageActive.active_presentation.manifest_schema_version; individual_live_skins = $coverageActive.effective_individual_count; shared_size_profiles = $coverageActive.effective_template_count }
    legacy_provenance_counts = [ordered]@{ playable = $coverageLive.playable_count; catalog_fallback_declarations = $coverageLive.catalog_fallback_declaration_count; overrides = $coverageOverrideIds.Count; individual = $coverageLive.effective_individual_count; templates = $coverageLive.effective_template_count }
    audit_source_sha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'current-state.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()
    evidence = 'In-memory descriptor regressions plus read-only actual raw PNG checks. No registry or source image mutation; no imported-RGBA or visual approval claim.'
}
[IO.File]::WriteAllText($coverageOutput, ($coverageReceipt | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Output "PASS: character art source coverage $coverageAssertions assertions, $($coverageCases.Count) cases. Receipt: $coverageOutput"
