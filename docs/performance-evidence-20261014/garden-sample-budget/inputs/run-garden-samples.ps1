[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('normal-forward','normal-reverse','reduced-forward','reduced-reverse')][string]$Case,
    [Parameter(Mandatory)][string]$OutputDirectory
)
# Sample-budget experiment only, through the desktop Diagnostic route; no promotion.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$hexRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$hexRuns = Join-Path $PSScriptRoot 'runs'
$hexPrefix = '.godot/iteration-20261014/garden-sample-next'
$hexPinsPath = Join-Path $PSScriptRoot 'source-pins.json'
$hexPinsSha = '5837332b5b1f7f99ee75e4bd220c73063b9c60ad427cd81b60f9476531d375f5'
. (Join-Path $hexRoot 'scripts/flux2-common.ps1')

function Assert-Garden([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-PhysicalGardenPath([string]$Path) {
    $part = [IO.Path]::GetFullPath($Path)
    while ($part) {
        if ((Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Garden diagnostic rejects reparse paths.' }
        $part = [IO.Path]::GetDirectoryName($part)
    }
}
function Resolve-GardenSource([string]$Resource) {
    Assert-Garden ($Resource -cmatch '^res://[^:\\]+$' -and $Resource -notmatch '(^|/)\.\.?(/|$)') 'Invalid pinned source path.'
    $path = [IO.Path]::GetFullPath((Join-Path $hexRoot $Resource.Substring(6)))
    Assert-Garden ($path.StartsWith($hexRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Source escapes checkout.'
    Assert-PhysicalGardenPath $path
    return $path
}
function Assert-GardenSources([System.Collections.IDictionary]$Actual) {
    Assert-Garden ($Actual.Count -eq $hexPins.source_hashes.Count) 'Receipt input count differs.'
    foreach ($entry in $hexPins.source_hashes.GetEnumerator()) {
        Assert-Garden ($Actual.Contains($entry.Key) -and $Actual[$entry.Key] -ceq $entry.Value) 'Receipt source pin differs.'
        Assert-Garden ((Get-FluxFileSha256 (Resolve-GardenSource $entry.Key)) -ceq $entry.Value) "Current source differs: $($entry.Key)"
    }
    Assert-Garden ((Get-FluxFileSha256 $hexPinsPath) -ceq $hexPinsSha) 'Garden source inventory changed.'
}
function Get-GardenMemory {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -Property FreePhysicalMemory,TotalVisibleMemorySize -ErrorAction Stop
        return [ordered]@{available=$true;observed_utc=[DateTime]::UtcNow.ToString('o');available_bytes=[long]$os.FreePhysicalMemory*1KB;total_visible_bytes=[long]$os.TotalVisibleMemorySize*1KB;scope='Host OS endpoint only, not process memory or idle-machine proof.'}
    } catch { return [ordered]@{available=$false;error=$_.Exception.Message} }
}
function Assert-GardenOrder($Order, [int]$Index) {
    $observedFirst = (($Index % 2 -eq 0) -ne $hexReverse)
    $first = if ($observedFirst) { 'candidate' } else { 'plain' }; $second = if ($observedFirst) { 'plain' } else { 'candidate' }
    Assert-Garden ($Order.Count -eq 2 -and $Order[0] -ceq $first -and $Order[1] -ceq $second) 'Actual paired invocation order differs.'
}
function Assert-GardenDraw($Row, [string]$Label, [int]$Index, [int]$Limit, [string]$Quality, [bool]$RequirePixels) {
    Assert-Garden ($Row.label -ceq $Label -and $Row.index -eq $Index -and $Row.sample_limit -eq $Limit -and $Row.quality_profile -ceq $Quality) 'Draw label/index/detail/profile differs.'
    Assert-GardenOrder $Row.actual_order $Index
    $hexExpectedEntries = if ($Label -ceq 'departed') { 0 } else { 25 }
    Assert-Garden ($Row.plain.entries -eq $hexExpectedEntries -and $Row.candidate.entries -eq $hexExpectedEntries -and $Row.plain.whole_pipeline_us -ge 0 -and $Row.candidate.whole_pipeline_us -ge 0) 'Whole draw sample is invalid.'
    Assert-Garden ($Row.warning_changed -is [bool] -and $Row.exact_rgba_checked -is [bool] -and $Row.authority_hash_checked -is [bool]) 'Draw proof flags are malformed.'
    if ($RequirePixels -or $Row.warning_changed) { Assert-Garden ($Row.exact_rgba_checked -ceq $true -and $Row.authority_hash_checked -ceq $true) 'Actual boundary lacks exact RGBA/authority proof.' }
    foreach ($hexField in @('resident','retained_geometry','geometry_builds','geometry_reuses')) {
        Assert-Garden ($Row.cache_after.plain.surface[$hexField] -eq $Row.cache_after.candidate.surface[$hexField]) 'Geometry cache counts diverge.'
    }
    Assert-Garden ($Row.cache_after.plain.plaque_builds -eq $Row.cache_after.candidate.plaque_builds -and $Row.cache_after.candidate.samples -le $hexExpectedEntries*$Limit -and $Row.cache_after.plain.samples -le $hexExpectedEntries*3) 'Prepared sample/plaque bounds differ.'
    if ($Label -ceq 'departed') { Assert-Garden ($Row.cache_after.plain.surface.resident -eq 0 -and $Row.cache_after.plain.surface.retained_geometry -eq 0 -and $Row.cache_after.candidate.surface.resident -eq 0 -and $Row.cache_after.candidate.surface.retained_geometry -eq 0) 'Departure retains owned geometry.' }
}
function Assert-GardenReceipt([System.Collections.IDictionary]$Receipt) {
    Assert-Garden ($Receipt.schema -ceq 'hex.garden-samples.v1' -and $Receipt.passed -is [bool] -and $Receipt.passed -ceq $true -and $Receipt.complete -ceq $true -and $Receipt.errors.Count -eq 0 -and $Receipt.checks -gt 0) 'Garden sample helper failed.'
    Assert-Garden ($Receipt.reverse_order -ceq $hexReverse -and $Receipt.reduced -ceq $hexReduced -and $Receipt.source_pins_sha256 -ceq $hexPinsSha) 'Requested case or pin linkage differs.'
    Assert-GardenSources $Receipt.source_hashes
    Assert-Garden ($Receipt.controls -is [System.Collections.IDictionary] -and $Receipt.controls.checks -gt 0 -and $Receipt.controls.errors.Count -eq 0) 'Compatibility/lifetime controls failed.'
    $hexEvidence = $Receipt.controls.evidence
    Assert-Garden ($hexEvidence.direct_default_samples -eq 3 -and $hexEvidence.exact_candidate_low_samples -eq 1 -and $hexEvidence.derived_surface_calls -eq 1 -and $hexEvidence.derived_ground_preparation_calls.Count -eq 2 -and $hexEvidence.derived_ground_preparation_calls[0] -eq 3 -and $hexEvidence.derived_ground_preparation_calls[1] -eq 3) 'Actual exact/virtual sample paths differ.'
    Assert-Garden ($hexEvidence.derived_court_region_calls.Count -eq 2 -and $hexEvidence.derived_court_region_calls[0] -gt 3 -and $hexEvidence.derived_court_region_calls[0] -eq $hexEvidence.derived_court_region_calls[1] -and $hexEvidence.staged_courts -eq 2 -and $hexEvidence.cancel_and_reconfigure_mesh_release -ceq $true) 'Court dispatch/staging/lifetime evidence differs.'
    Assert-Garden ($hexEvidence.phase_rows.Count -eq 4 -and @($hexEvidence.phase_rows | Where-Object { $_.warning -ceq $true }).Count -ge 1 -and $hexEvidence.phase_rows[-1].empty_mesh -ceq $true) 'Actual warning/expiry controls are absent.'
    Assert-Garden ($Receipt.cleanup.created -eq 2 -and $Receipt.cleanup.freed -eq 2 -and $Receipt.cleanup.live -eq 0) 'Garden owners did not close.'
    Assert-Garden ($Receipt.warmup_groups -eq 6 -and $Receipt.target_cycles -eq 3 -and $Receipt.final_cycles.Count -eq 25 -and $Receipt.arrival_rows.Count -eq 50 -and $Receipt.cases.Count -eq 7 -and $Receipt.images.Count -eq 7) 'Bounded evolution/control inventory differs.'
    foreach ($hexCycle in $Receipt.final_cycles.Values) { Assert-Garden ($hexCycle -isnot [bool] -and $hexCycle -eq [int]$hexCycle -and $hexCycle -ge 3) 'A resident did not complete three actual cycles.' }
    for ($hexIndex=0; $hexIndex -lt 50; $hexIndex++) {
        $hexRow = $Receipt.arrival_rows[$hexIndex]; $hexLocal = $hexIndex % 25
        Assert-Garden ($hexRow.index -eq $hexLocal -and $hexRow.label -ceq $(if ($hexIndex -lt 25) { 'initial' } else { 'reentry' })) 'Arrival order differs.'
        Assert-GardenOrder $hexRow.actual_order $hexLocal
        Assert-Garden ($hexRow.arms.plain.whole_preparation_us -ge 0 -and $hexRow.arms.candidate.whole_preparation_us -ge 0) 'Arrival clock is invalid.'
    }
    Assert-Garden ($Receipt.groups.Count -gt 7 -and $Receipt.groups.Count -le 1201) 'Finite continuous group count differs.'
    $hexEvolutionCount = $Receipt.groups.Count-1; $hexSteps = 0; $hexPhaseRows = 0
    for ($hexIndex=0; $hexIndex -lt $Receipt.groups.Count; $hexIndex++) {
        $hexRow=$Receipt.groups[$hexIndex]; $hexDeparture=$hexIndex -eq $hexEvolutionCount
        $hexExpectedIndex=if ($hexDeparture) { $hexEvolutionCount+2 } else { $hexIndex }
        $hexCount=if ($hexDeparture) { 1 } else { @(0,1,8)[$hexIndex%3] }
        Assert-Garden ($hexRow.index -eq $hexExpectedIndex -and $hexRow.steps -eq $hexCount) 'Continuous0/1/8/departure index differs.'
        Assert-GardenOrder $hexRow.actual_order $hexExpectedIndex
        foreach ($hexSide in @('plain','candidate')) { Assert-Garden ($hexRow.arms[$hexSide].okay -ceq $true -and $hexRow.arms[$hexSide].completed -eq $hexCount -and $hexRow.arms[$hexSide].whole_exhibit_frame_us -ge 0) 'Actual exhibit group did not complete.' }
        if ($hexDeparture) { Assert-Garden ($hexRow.departure -ceq $true) 'Final departure missing.'; continue }
        Assert-Garden ($hexRow.warmup -ceq ($hexIndex -lt 6) -and $hexRow.markers.Count -eq 25) 'Warmup or current plot inventory differs.'
        $hexProof = $hexRow.phase_changes.Count -gt 0 -or $hexRow.transitions.value_revision_changes -gt 0 -or $hexRow.transitions.render_revision_changes -gt 0 -or $hexIndex%32 -eq 0
        Assert-GardenDraw $hexRow.draw 'evolution' $hexIndex 1 'low' $hexProof
        if ($hexRow.phase_changes.Count -gt 0) { $hexPhaseRows++ }
        $hexSteps += $hexCount
    }
    Assert-Garden ($hexSteps -le 3600 -and $hexPhaseRows -gt 0) 'Actual continuous phase work or finite horizon missing.'
    $hexLabels=@('initial_low','same_phase_standard','same_phase_low_again','three_cycles','later_standard','departed','reentered')
    $hexIndices=@(0,1,2,$hexEvolutionCount,($hexEvolutionCount+1),($hexEvolutionCount+2),($hexEvolutionCount+3))
    for ($hexIndex=0; $hexIndex -lt 7; $hexIndex++) {
        $hexLimit=if ($hexIndex -in @(1,4)) { 3 } else { 1 }; $hexQuality=if ($hexLimit -eq 3) { 'standard' } else { 'low' }
        Assert-GardenDraw $Receipt.cases[$hexIndex] $hexLabels[$hexIndex] $hexIndices[$hexIndex] $hexLimit $hexQuality $true
        $hexImage=$Receipt.images[$hexIndex]; $hexImagePath=Resolve-GardenSource $hexImage.path
        Assert-Garden ($hexImage.label -ceq $hexLabels[$hexIndex] -and [IO.Path]::GetDirectoryName($hexImagePath) -ceq $hexOutput -and [IO.Path]::GetFileName($hexImagePath) -ceq ($hexLabels[$hexIndex]+'.png') -and (Get-FluxFileSha256 $hexImagePath) -ceq $hexImage.sha256) 'Representative native PNG path/hash differs.'
    }
    Assert-Garden ($Receipt.selection_gate.phase_refresh_mean_saved_percent -eq 5 -and $Receipt.selection_gate.phase_refresh_mean_saved_us -eq 50 -and $Receipt.selection_gate.both_processes -ceq $true -and $Receipt.selection_gate.positive_paired_median -ceq $true -and $Receipt.selection_gate.both_callback_order_strata_saving -ceq $true -and $Receipt.selection_gate.reject_repeated_all_frame_p95_regression_percent -eq 5) 'Predeclared selection gate differs.'
    foreach ($hexStderr in @("$hexOutput.log.err","$hexOutput-parse.log.err")) { Assert-Garden ((Get-Item -LiteralPath $hexStderr).Length -eq 0) 'Strict stderr is not empty.' }
    Assert-Garden (Select-String -LiteralPath "$hexOutput.log" -SimpleMatch "GARDEN_SAMPLES_PASS checks=$($Receipt.checks) groups=$($Receipt.groups.Count)" -Quiet) 'Terminal result marker differs.'
}

Assert-PhysicalGardenPath $PSScriptRoot
Assert-Garden ((Get-FluxFileSha256 $hexPinsPath) -ceq $hexPinsSha) 'Reviewed Garden pin manifest differs.'
$hexPins = Get-Content -LiteralPath $hexPinsPath -Raw | ConvertFrom-Json -AsHashtable
Assert-Garden ($hexPins.schema -ceq 'hex.garden-sample-pins.v1' -and $hexPins.runtime_identity.build_id -ceq 'p61-64590c45c7a5' -and $hexPins.source_hashes.Count -eq 335) 'Garden source scope differs.'
Assert-GardenSources $hexPins.source_hashes
$hexOutput = [IO.Path]::GetFullPath($OutputDirectory); Assert-PhysicalGardenPath $hexOutput
$hexLeaf = [IO.Path]::GetFileName($hexOutput)
Assert-Garden ([IO.Path]::GetDirectoryName($hexOutput) -ceq $hexRuns -and $hexLeaf -cmatch ('^'+[regex]::Escape($Case)+'-[a-z0-9]+(?:-[a-z0-9]+)*$')) 'Case-qualified fresh output must be one direct run child.'
foreach ($fresh in @($hexOutput,"$hexOutput.log","$hexOutput.log.err","$hexOutput-parse.log","$hexOutput-parse.log.err","$hexOutput-roaming")) { Assert-Garden (-not (Test-Path -LiteralPath $fresh)) "Preserve existing run: $fresh";Assert-PhysicalGardenPath $fresh }
$hexReverse = $Case.EndsWith('-reverse',[StringComparison]::Ordinal); $hexReduced = $Case.StartsWith('reduced-',[StringComparison]::Ordinal)
$hexRunnerSha = Get-FluxFileSha256 $PSCommandPath
$hexPointerPath = Join-Path $hexRoot 'docs/current-delivery.json'; $hexPointerSha = Get-FluxFileSha256 $hexPointerPath
$hexGodot = Get-FluxGodot; $hexGodotSha = Get-FluxFileSha256 $hexGodot
$hexArguments = @('--path',$hexRoot,'--audio-driver','Dummy','--script',"res://$hexPrefix/compare-garden-samples.gd",'--','--no-lan-discovery',"--output=res://$hexPrefix/runs/$hexLeaf")
if ($hexReverse) { $hexArguments += '--reverse-order' }; if ($hexReduced) { $hexArguments += '--reduced' }
$hexHadAppData = Test-Path Env:APPDATA; $hexSavedAppData = $env:APPDATA
$hexPassed=$false; $hexFailure=$null; $hexBefore=$null; $hexAfter=$null; $hexHelperSha=$null
$hexStarted=[DateTime]::UtcNow.ToString('o')
$hexLease=Enter-FluxEngineRun 'desktop-garden-sample-experiment'
try {
    New-Item -ItemType Directory -Path $hexRuns -Force | Out-Null
    $env:APPDATA="$hexOutput-roaming"; New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Invoke-FluxGodotChecked $hexGodot @('--headless','--path',$hexRoot,'--check-only','--script',"res://$hexPrefix/compare-garden-samples.gd") "$hexOutput-parse.log" -RejectWarnings -TimeoutSeconds 180 | Out-Null
    $hexBefore=Get-GardenMemory
    Invoke-FluxGodotChecked $hexGodot $hexArguments "$hexOutput.log" -RejectWarnings -TimeoutSeconds 300 | Out-Null
    $hexAfter=Get-GardenMemory
    $hexReceiptPath=Join-Path $hexOutput 'receipt.json'
    Assert-Garden ((Get-Item -LiteralPath $hexReceiptPath).Length -le 32MB) 'Garden receipt exceeds bounded size.'
    $receipt=Get-Content -LiteralPath $hexReceiptPath -Raw | ConvertFrom-Json -AsHashtable
    Assert-GardenReceipt $receipt
    $hexHelperSha=Get-FluxFileSha256 $hexReceiptPath; $hexPassed=$true
} catch { $hexFailure=$_.Exception.Message }
finally {
    if ($null -eq $hexAfter) { $hexAfter=Get-GardenMemory }
    if ($hexHadAppData) { $env:APPDATA=$hexSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $hexLease
    try {
        Assert-GardenSources $hexPins.source_hashes
        Assert-Garden ((Get-FluxFileSha256 $PSCommandPath) -ceq $hexRunnerSha -and (Get-FluxFileSha256 $hexPointerPath) -ceq $hexPointerSha -and (Get-FluxFileSha256 $hexGodot) -ceq $hexGodotSha) 'Runner, qualified pointer or engine changed.'
    } catch { $hexPassed=$false; $hexFailure=([string]$hexFailure+'; '+$_.Exception.Message).Trim(';',' ') }
}
if (-not (Test-Path -LiteralPath $hexOutput)) { New-Item -ItemType Directory -Path $hexOutput | Out-Null }
$hexLogs=[ordered]@{}
foreach ($log in @("$hexOutput.log","$hexOutput.log.err","$hexOutput-parse.log","$hexOutput-parse.log.err")) { if (Test-Path -LiteralPath $log -PathType Leaf) { $hexLogs['../'+[IO.Path]::GetFileName($log)]=Get-FluxFileSha256 $log } }
$record=[ordered]@{schema='hex.garden-sample-launcher-run.v1';passed=$hexPassed;case=$Case;failure=$hexFailure;started_utc=$hexStarted;ended_utc=[DateTime]::UtcNow.ToString('o');runner_sha256=$hexRunnerSha;source_pins_sha256=$hexPinsSha;helper_receipt_sha256=$hexHelperSha;engine_path=$hexGodot;engine_sha256=$hexGodotSha;engine_arguments=$hexArguments;parse_timeout_seconds=180;native_timeout_seconds=300;logs=$hexLogs;host_memory_before=$hexBefore;host_memory_after=$hexAfter;default_pointer_sha256=$hexPointerSha;appdata_restored=$true;scope='Garden sample-budget paired experiment only. Host memory endpoints and engine monitor fields are not process/private peaks. Desktop shortcut/wrapper invocation is separate external route evidence. No optimization, frame/FPS/GPU or physical-input claim.'}
$encoded=($record | ConvertTo-Json -Depth 20)+"`n"
$recordPath=Join-Path $hexOutput 'runner.json'
$stream=[IO.File]::Open($recordPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $bytes=[Text.UTF8Encoding]::new($false).GetBytes($encoded);$stream.Write($bytes,0,$bytes.Length);$stream.Flush() } finally { $stream.Dispose() }
Assert-Garden ([IO.File]::ReadAllText($recordPath) -ceq $encoded) 'Runner receipt readback differs.'
if (-not $hexPassed) { throw "Garden $Case failed: $hexFailure" }
Write-Output "PASS Garden $Case; helper receipt $hexHelperSha"
