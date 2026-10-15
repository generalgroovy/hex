# Source-only documentation contract tests; no engine, payload or file writes.
$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'check-current-delivery.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
foreach ($name in @('Get-HexCurrentDeliverySummary', 'Assert-HexDeliveryLink', 'Assert-HexCurrentDeliveryText', 'Assert-HexPerformanceEvidence')) {
    $definitions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true))
    if ($definitions.Count -ne 1) { throw "Expected one delivery function $name" }
    Invoke-Expression $definitions[0].Extent.Text
}
$checks = 0
function Check-Delivery([bool]$Condition, [string]$Label) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Label" }
}
function Reject-Delivery([string]$Label, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Check-Delivery $rejected $Label
}
$pointer = [pscustomobject]@{
    schema_version = 1; qualified_build_id = 'p61-abcdef012345'
    launcher = 'exports/hex-fixture/windows/PLAY-HEX.cmd'
    qualification = 'docs/iteration-20261013/delivery-review-fixture/review.json'
    working_status = 'active_candidate'; performance_status = 'current_build_not_measured'
}
$summary = Get-HexCurrentDeliverySummary $pointer
Check-Delivery ($summary.zip -ceq 'exports/hex-fixture/HEX-p61-abcdef012345-Windows-x64.zip') 'Portable ZIP follows the selected build directory and identity'
$readme = @"
# H.E.X.
Status: **active improvement pass.**
The qualified local portable remains **$($summary.qualified_build_id)**; source can differ.
[delivery review]($($summary.qualification))
## Play
[Launch H.E.X.]($($summary.launcher))
[Windows x64 ZIP]($($summary.zip))
Older p61-000000000000 is historical, not the current selection.
"@
$guide = @"
# Player guide
Status: **development is active; the qualified playable build is $($summary.qualified_build_id).**
[Windows x64 ZIP](../$($summary.zip))
[independent delivery review]($($summary.qualification.Substring(5)))
Older p61-000000000000 is historical.
## Start
"@
Assert-HexCurrentDeliveryText $summary $readme $guide
Check-Delivery $true 'Candidate work and historical IDs may coexist with one qualified portable'
Assert-HexCurrentDeliveryText $summary ($readme.Replace("`n", "`r`n")) ($guide.Replace("`n", "`r`n"))
Check-Delivery $true 'Windows text newlines do not change header/link meaning'
$paused = $pointer | ConvertTo-Json | ConvertFrom-Json
$paused.working_status = 'paused_qualified'
Assert-HexCurrentDeliveryText (Get-HexCurrentDeliverySummary $paused) ($readme.Replace('active improvement pass', 'paused at a qualified checkpoint')) ($guide.Replace('development is active', 'development is paused'))
Check-Delivery $true 'Paused working status is explicit and independent of the qualified ID'
foreach ($case in @(
    @{label='string schema';field='schema_version';value='1'},
    @{label='wrong schema';field='schema_version';value=2},
    @{label='invalid ID';field='qualified_build_id';value='candidate'},
    @{label='parent traversal';field='launcher';value='exports/../windows/PLAY-HEX.cmd'},
    @{label='absolute launcher';field='launcher';value='C:/game/PLAY-HEX.cmd'},
    @{label='wrong executable';field='launcher';value='exports/fixture/windows/hex.exe'},
    @{label='absolute evidence';field='qualification';value='C:/review.json'},
    @{label='evidence traversal';field='qualification';value='docs/../review.json'},
    @{label='unknown work status';field='working_status';value='shipped'},
    @{label='unreviewed performance claim';field='performance_status';value='smooth_60fps'}
)) {
    $changed = $pointer | ConvertTo-Json | ConvertFrom-Json
    $changed.($case.field) = $case.value
    Reject-Delivery $case.label { Get-HexCurrentDeliverySummary $changed }
}
Reject-Delivery 'Stale README qualified header' { Assert-HexCurrentDeliveryText $summary ($readme.Replace('remains **p61-abcdef012345', 'remains **p61-000000000000')) $guide }
Reject-Delivery 'Stale guide qualified header' { Assert-HexCurrentDeliveryText $summary $readme ($guide.Replace('build is p61-abcdef012345', 'build is p61-000000000000')) }
Reject-Delivery 'Stale launcher link' { Assert-HexCurrentDeliveryText $summary ($readme.Replace($summary.launcher, 'exports/old/windows/PLAY-HEX.cmd')) $guide }
Reject-Delivery 'Stale README ZIP' { Assert-HexCurrentDeliveryText $summary ($readme.Replace($summary.zip, 'exports/old/old.zip')) $guide }
Reject-Delivery 'Stale guide ZIP' { Assert-HexCurrentDeliveryText $summary $readme ($guide.Replace($summary.zip, 'exports/old/old.zip')) }
Reject-Delivery 'Stale qualification link' { Assert-HexCurrentDeliveryText $summary ($readme.Replace($summary.qualification, 'docs/old/review.json')) $guide }
Reject-Delivery 'Duplicate current link' { Assert-HexCurrentDeliveryText $summary ($readme + "`n[Launch H.E.X.]($($summary.launcher))") $guide }
Reject-Delivery 'Stale work status' { Assert-HexCurrentDeliveryText $summary ($readme.Replace('active improvement pass', 'paused')) $guide }
$measured = $pointer | ConvertTo-Json | ConvertFrom-Json
$measured.performance_status = 'source_measured_portable_unmeasured'
Reject-Delivery 'Measured source requires its review path' { Get-HexCurrentDeliverySummary $measured }
$measured | Add-Member -NotePropertyName performance_evidence -NotePropertyValue 'docs/performance-evidence-20261014/foreground-fixture/review.json'
$measuredSummary = Get-HexCurrentDeliverySummary $measured
$measuredReadme = $readme + "`n[source performance review]($($measuredSummary.performance_evidence))"
$measuredGuide = $guide + "`n[source performance review]($($measuredSummary.performance_evidence.Substring(5)))"
Assert-HexCurrentDeliveryText $measuredSummary $measuredReadme $measuredGuide
Check-Delivery $true 'Measured source links stay separate from portable qualification'
Reject-Delivery 'Measured source cannot retain stale document link' { Assert-HexCurrentDeliveryText $measuredSummary $measuredReadme $guide }
$sourceReview = [pscustomobject]@{schema='hex-foreground-source-review-v1';status='passed';source_build_id='p61-abcdef012345';source_sha256=('abcdef012345' + 'c'*52);errors=@()}
Assert-HexPerformanceEvidence $measuredSummary $sourceReview
Check-Delivery $true 'A passing matching source review is admitted without a portable FPS claim'
foreach ($case in @(@{field='status';value='failed'},@{field='source_build_id';value='p61-000000000000'},@{field='source_sha256';value=('d'*64)},@{field='errors';value=@('focus lost')})) {
    $bad = $sourceReview | ConvertTo-Json | ConvertFrom-Json
    $bad.($case.field) = $case.value
    Reject-Delivery "Source review rejects $($case.field) drift" { Assert-HexPerformanceEvidence $measuredSummary $bad }
}
$measured.performance_status = 'current_build_not_measured'
Reject-Delivery 'Unmeasured status cannot keep current source evidence' { Get-HexCurrentDeliverySummary $measured }
Write-Output "PASS: $checks source-only current-delivery assertions."
