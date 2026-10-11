$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
$hexHistoricalPath=Join-Path $hexRoot 'docs/completion-evidence-20261004/paid-load-v1.json'
$hexCurrentPath=Join-Path $hexRoot '.godot/unified-wellspring-profile-clarity-20261005-v1.json'
$hexOutput=Join-Path $PSScriptRoot 'paid-load-comparison-v1.json'
if(Test-Path -LiteralPath $hexOutput){throw 'Fresh paid-load comparison output required'}

# Exact profile_unified_wellspring.gd::_deterministic_result contract.
# Dictionary order is immaterial; array order and scalar values remain exact.
$hexFields=@(
 'instrumentation_version','case','sample_ticks','requested_pressed_by_wire','requested_held_ticks_by_wire',
 'admitted_by_wire','refusals_by_wire_and_reason','released_by_wire',
 'processed_clashes','processed_products','workload_totals','event_counts','event_accounting','authority_metrics','publication',
 'inventory_totals','alive_work','final_occupancy_after_cleanup',
 'contact_queries','cleanup_ticks','sample_end_hash','final_hash','trace_sha256','peaks'
)
function ConvertTo-HexCanonicalValue {
 param([AllowNull()][object]$Value)
 if($null -eq $Value){return $null}
 if($Value -is [Collections.IDictionary]){
  $hexOrdered=[ordered]@{}
  [string[]]$hexKeys=@($Value.Keys)
  [Array]::Sort($hexKeys,[StringComparer]::Ordinal)
  foreach($hexKey in $hexKeys){$hexOrdered[$hexKey]=ConvertTo-HexCanonicalValue $Value[$hexKey]}
  return $hexOrdered
 }
 if($Value -is [Collections.IList]){
  $hexItems=[object[]]::new($Value.Count)
  for($hexIndex=0;$hexIndex -lt $Value.Count;$hexIndex++){$hexItems[$hexIndex]=ConvertTo-HexCanonicalValue $Value[$hexIndex]}
  return ,$hexItems
 }
 return $Value
}
function Get-HexDeterministicJson {
 param([Collections.IDictionary]$Run,[string]$Field)
 if(-not $Run.Contains($Field)){throw "Missing deterministic field: $Field"}
 $hexValue=$Run[$Field]
 if($Field -eq 'peaks'){
  if($hexValue -isnot [Collections.IDictionary] -or -not $hexValue.Contains('static_memory_bytes')){throw 'Malformed deterministic peaks'}
  $hexPeaks=[ordered]@{}
  foreach($hexKey in $hexValue.Keys){if($hexKey -cne 'static_memory_bytes'){$hexPeaks[$hexKey]=$hexValue[$hexKey]}}
  $hexValue=$hexPeaks
 }
 ConvertTo-Json -InputObject (ConvertTo-HexCanonicalValue $hexValue) -Depth 100 -Compress
}
function Read-HexPaidReceipt {
 param([string]$Path,[bool]$Current)
 $hexDocument=Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
 if($hexDocument.failures -ne 0 -or $hexDocument.assertions -le 0 -or $hexDocument.sources_unchanged -isnot [bool] -or -not $hexDocument.sources_unchanged){throw "Paid-load receipt did not pass: $Path"}
 if($hexDocument.schema_version -ne 1 -or $hexDocument.workload_version -cne 'unified-wellspring-profile-v1' -or $hexDocument.seed -ne 906190 -or $hexDocument.tick_rate -ne 120 -or $hexDocument.warmup_ticks -ne 120 -or $hexDocument.sample_ticks -ne 720 -or $hexDocument.repetitions_per_case -ne 2){throw "Unexpected paid workload contract: $Path"}
 if(($hexDocument.cases -join '|') -cne 'sustained-distributed|dense-crucible' -or $hexDocument.runs.Count -ne 4){throw "Expected both cases and four runs: $Path"}
 if($Current -and $hexDocument.runtime_identity.build_id -cne 'p56-4c82db23d160'){throw 'Current paid-load build identity mismatch'}
 $hexSeen=@{}
 foreach($hexRun in $hexDocument.runs){
  if($hexRun.case -cnotin @('sustained-distributed','dense-crucible') -or $hexRun.repeat -notin @(1,2) -or $hexRun.sample_ticks -ne 720 -or $hexRun.instrumentation_version -cne 'event-accounting-v2-owned-publication'){throw "Unexpected paid run contract: $Path"}
  if($hexRun.reverse_command_order -isnot [bool] -or $hexRun.reverse_command_order -ne ($hexRun.repeat -eq 2)){throw "Wrong command-order repetition: $Path"}
  $hexKey='{0}:{1}' -f $hexRun.case,$hexRun.repeat
  if($hexSeen.ContainsKey($hexKey)){throw "Duplicate paid run: $hexKey"}
  $hexSeen[$hexKey]=$hexRun
  foreach($hexField in $hexFields){$null=Get-HexDeterministicJson $hexRun $hexField}
 }
 return @{document=$hexDocument;runs=$hexSeen}
}
function Get-HexObservedTimings {
 param([Collections.IDictionary]$Run)
 $hexTimings=[ordered]@{}
 foreach($hexField in @('step_us','host_step_event_retention_and_60hz_envelope_us','owned_capture_and_packetization_core_us','envelope_capture_and_wire_pack_us','deadline_misses_over_8333us')){
  if(-not $Run.Contains($hexField)){throw "Missing observed timing field: $hexField"}
  $hexTimings[$hexField]=$Run[$hexField]
 }
 return $hexTimings
}

$hexHistorical=Read-HexPaidReceipt $hexHistoricalPath $false
$hexCurrent=Read-HexPaidReceipt $hexCurrentPath $true
$hexComparisons=@()
$hexAllEqual=$true
foreach($hexCase in @('sustained-distributed','dense-crucible')){
 foreach($hexRepeat in @(1,2)){
  $hexKey='{0}:{1}' -f $hexCase,$hexRepeat
  $hexOldRun=$hexHistorical.runs[$hexKey]
  $hexNewRun=$hexCurrent.runs[$hexKey]
  $hexDifferent=@()
  foreach($hexField in $hexFields){
   if((Get-HexDeterministicJson $hexOldRun $hexField) -cne (Get-HexDeterministicJson $hexNewRun $hexField)){$hexDifferent+=$hexField}
  }
  if($hexDifferent.Count -gt 0){$hexAllEqual=$false}
  $hexComparisons+=[ordered]@{case=$hexCase;repeat=$hexRepeat;reverse_command_order=$hexNewRun.reverse_command_order;sample_ticks=720;deterministic_match=($hexDifferent.Count -eq 0);different_fields=$hexDifferent;historical_observed=Get-HexObservedTimings $hexOldRun;current_observed=Get-HexObservedTimings $hexNewRun}
 }
}
$hexResult=[ordered]@{
 status=$(if($hexAllEqual){'passed'}else{'failed'})
 historical_receipt='docs/completion-evidence-20261004/paid-load-v1.json'
 historical_receipt_sha256=(Get-FileHash -LiteralPath $hexHistoricalPath).Hash.ToLowerInvariant()
 current_receipt='.godot/unified-wellspring-profile-clarity-20261005-v1.json'
 current_receipt_sha256=(Get-FileHash -LiteralPath $hexCurrentPath).Hash.ToLowerInvariant()
 historical_build_id=$hexHistorical.document.runtime_identity.build_id
 current_build_id=$hexCurrent.document.runtime_identity.build_id
 deterministic_fields=$hexFields
 excluded_peak='static_memory_bytes'
 runs=$hexComparisons
 scope='Exact profiler deterministic counters, ordered events, publication inventory and hashes across four matching paid runs. Source identity, timings and memory are not equality targets.'
 timing_interpretation='Historical versus current observations only, not a controlled speedup comparison. No rendered, physical-network, dense120Hz or capacity acceptance is established.'
}
[IO.File]::WriteAllText($hexOutput,($hexResult | ConvertTo-Json -Depth 100),[Text.UTF8Encoding]::new($false))
$hexComparisons | ForEach-Object { [pscustomobject]$_ } | Select-Object case,repeat,deterministic_match,different_fields | ConvertTo-Json -Depth 4
if(-not $hexAllEqual){throw 'Paid-load deterministic comparison failed'}
