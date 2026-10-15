[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('fire-forward','fire-reverse','mantle-forward','mantle-reverse')][string]$Case,
    [Parameter(Mandatory)][string]$OutputDirectory
)
# Attribution only, through the desktop Diagnostic route; no candidate promotion.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$hexRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$hexRuns = Join-Path $PSScriptRoot 'runs'
$hexPrefix = '.godot/iteration-20261014/stage-next'
$hexPinsPath = Join-Path $PSScriptRoot 'source-pins.json'
$hexPinsSha = 'd809ff83afac845d440ab0fe06f6fda9e28084a56597f9ee20b47a37f4706f3d'
. (Join-Path $hexRoot 'scripts/flux2-common.ps1')

function Assert-Stage([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-PhysicalStagePath([string]$Path) {
    $part = [IO.Path]::GetFullPath($Path)
    while ($part) {
        if ((Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Stage diagnostic rejects reparse paths.' }
        $part = [IO.Path]::GetDirectoryName($part)
    }
}
function Resolve-StageSource([string]$Resource) {
    Assert-Stage ($Resource -cmatch '^res://[^:\\]+$' -and $Resource -notmatch '(^|/)\.\.?(/|$)') 'Invalid pinned source path.'
    $path = [IO.Path]::GetFullPath((Join-Path $hexRoot $Resource.Substring(6)))
    Assert-Stage ($path.StartsWith($hexRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Source escapes checkout.'
    Assert-PhysicalStagePath $path
    return $path
}
function Assert-StageSources([System.Collections.IDictionary]$Actual) {
    Assert-Stage ($Actual.Count -eq $hexPins.source_hashes.Count) 'Receipt input count differs.'
    foreach ($entry in $hexPins.source_hashes.GetEnumerator()) {
        Assert-Stage ($Actual.Contains($entry.Key) -and $Actual[$entry.Key] -ceq $entry.Value) 'Receipt source pin differs.'
        Assert-Stage ((Get-FluxFileSha256 (Resolve-StageSource $entry.Key)) -ceq $entry.Value) "Current source differs: $($entry.Key)"
    }
    Assert-Stage ((Get-FluxFileSha256 $hexPinsPath) -ceq $hexPinsSha) 'Stage source inventory changed.'
}
function Get-StageMemory {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -Property FreePhysicalMemory,TotalVisibleMemorySize -ErrorAction Stop
        return [ordered]@{available=$true;observed_utc=[DateTime]::UtcNow.ToString('o');available_bytes=[long]$os.FreePhysicalMemory*1KB;total_visible_bytes=[long]$os.TotalVisibleMemorySize*1KB;scope='Host OS endpoint only, not process memory or idle-machine proof.'}
    } catch { return [ordered]@{available=$false;error=$_.Exception.Message} }
}
function Assert-StageOrder($Order, [int]$Index) {
    $observedFirst = (($Index % 2 -eq 0) -ne $hexReverse)
    $first = if ($observedFirst) { 'observed' } else { 'plain' }; $second = if ($observedFirst) { 'plain' } else { 'observed' }
    Assert-Stage ($Order.Count -eq 2 -and $Order[0] -ceq $first -and $Order[1] -ceq $second) 'Actual paired invocation order differs.'
}
function Assert-StageReceipt([System.Collections.IDictionary]$Receipt) {
    Assert-Stage ($Receipt.schema -ceq 'hex.stage-attribution.v1' -and $Receipt.passed -is [bool] -and $Receipt.passed -ceq $true -and $Receipt.errors.Count -eq 0 -and $Receipt.checks -gt 0) 'Stage helper failed.'
    Assert-Stage ($Receipt.case -ceq $hexWorkload -and $Receipt.reverse_order -ceq $hexReverse -and $Receipt.source_pins_sha256 -ceq $hexPinsSha) 'Case/order/pin linkage differs.'
    Assert-StageSources $Receipt.source_hashes
    Assert-Stage ($Receipt.cleanup.Count -eq 5 -and $Receipt.cleanup.created -eq 2 -and $Receipt.cleanup.ended -eq 2 -and $Receipt.cleanup.live_worlds -eq 0 -and $Receipt.cleanup.live_courts -eq 0 -and $Receipt.cleanup.factory_live -ceq $false) 'Observer/world/court/factory owners did not close.'
    Assert-Stage ($Receipt.initial_ticks -eq 48 -and $Receipt.rows.Count -ge 48 -and $Receipt.rows.Count -le 144 -and $Receipt.continuation_ticks -ge 0 -and $Receipt.continuation_ticks -le 72) 'Bounded paid trajectory differs.'
    Assert-Stage ($Receipt.admissions -eq 1 -and $Receipt.releases -eq 1 -and $Receipt.refusals -eq 0 -and $Receipt.flight_seen -ceq $true -and $Receipt.ground_seen -ceq $true -and $Receipt.first_flight_tick -gt 0 -and $Receipt.first_ground_tick -gt 0 -and $Receipt.first_ground_tick -le 120) 'Exactly one paid admission/release, no refusal and actual flight/ground required.'
    $children=@('setup_resources_status','reaction_contact_ratios','hex_pre_movement','movement','admission_offer','combat_player','release_store')
    Assert-Stage ($Receipt.child_names.Count -eq 7) 'Seven child names required.'
    for ($i=0;$i -lt 7;$i++) { Assert-Stage ($Receipt.child_names[$i] -ceq $children[$i]) 'Child order differs.' }
    $continuation=[int]$Receipt.continuation_ticks
    $extra=if ($continuation -gt 0) { 24 } else { 0 }
    Assert-Stage ($Receipt.ground_window_ticks -eq $extra -and $Receipt.rows.Count -eq 48+$continuation+$extra) 'Optional ground-only window inventory differs.'
    $starts=0;$releases=0;$refusals=0
    for ($i=0;$i -lt $Receipt.rows.Count;$i++) {
        $row=$Receipt.rows[$i]
        $phase=if($i -lt 48){'initial'}elseif($i -lt 48+$continuation){'continuation'}else{'ground_only'}
        $timed=$phase -cne 'continuation'
        Assert-Stage ($row.index -eq $i -and $row.tick_before -eq $i -and $row.tick_after -eq $i+1 -and $row.phase -ceq $phase -and $row.timed -ceq $timed -and $row.first_four_initial -ceq ($i -lt 4)) 'Actual contiguous phase/tick rows differ.'
        Assert-StageOrder $row.order $i
        $first=$row.order[0];$second=$row.order[1]
        Assert-Stage ($row.result[$first].serial -eq 2*$i+1 -and $row.result[$second].serial -eq 2*$i+2) 'Actual call serials differ.'
        Assert-Stage ($row.result.plain.success -ceq $true -and $row.result.observed.success -ceq $true -and $row.result.plain.last_error -ceq '' -and $row.result.observed.last_error -ceq '') 'A paired step failed.'
        $observation=$row.observation;$sum=0
        Assert-Stage ($observation.elapsed_us.Count -eq 7 -and $observation.executions.Count -eq 7 -and $observation.unfinished_interval -ceq $false) 'Child intervals are incomplete.'
        $survived=$observation.actors_entered-$observation.dead_at_entry-$observation.dead_after_status
        Assert-Stage ($observation.actors_entered -eq 5 -and $survived -ge 0 -and $observation.executions[0] -eq 5) 'Actual five-actor setup count differs.'
        for ($j=0;$j -lt 7;$j++) { Assert-Stage ($observation.elapsed_us[$j] -ge 0) 'Negative elapsed child.';$sum+=$observation.elapsed_us[$j]; if($j -gt 0){Assert-Stage ($observation.executions[$j] -eq $survived) 'Survivor child count differs.'} }
        $parent=$row.result.observed.stages_us.movement_cast_admission
        Assert-Stage ($sum -eq $row.child_sum_us -and $sum -le $parent -and $row.parent_residual_us -eq $parent-$sum) 'Disjoint children/parent residual differ.'
        foreach($side in @('plain','observed')) {
            $stageSum=0
            Assert-Stage ($row.result[$side].stages_us.Count -eq 9) 'Existing nine stages missing.'
            foreach($value in $row.result[$side].stages_us.Values){Assert-Stage ($value -ge 0) 'Negative existing stage.';$stageSum+=$value}
            if($timed){Assert-Stage ($row.result[$side].whole_step_us -ge $stageSum) 'Nine stages exceed enclosing step.'}else{Assert-Stage ($null -eq $row.result[$side].whole_step_us) 'Untimed continuation must not invent outer timing.'}
        }
        Assert-Stage ($row.actor_before_sha256 -cmatch '^[0-9a-f]{64}$' -and $row.actor_after_sha256 -cmatch '^[0-9a-f]{64}$' -and $row.actor_byte_count -gt 0 -and $row.command_hex -cmatch '^[0-9a-f]+$' -and $row.cumulative_completed -eq $i+1) 'Actor/command/accounting witness is missing.'
        if($i -gt 0){Assert-Stage ($row.actor_before_sha256 -ceq $Receipt.rows[$i-1].actor_after_sha256 -and $row.matter_paid_before -eq $Receipt.rows[$i-1].matter_paid) 'Continuity between observed attempts differs.'}
        foreach($event in $row.events){if($event.type -ceq 'cast_started'){$starts++}elseif($event.type -ceq 'projectile_spawned'){$releases++}elseif($event.type -ceq 'cast_refused'){$refusals++}}
        Assert-Stage ($row.matter_paid -eq $starts*600) 'Finite paid admission accounting differs.'
    }
    Assert-Stage ($starts -eq $Receipt.admissions -and $releases -eq $Receipt.releases -and $refusals -eq $Receipt.refusals) 'Paid event recount differs.'
    $labels=if($continuation -gt 0){@('entry','ground_window_entry','exit')}else{@('entry','exit')}
    $ticks=if($continuation -gt 0){@(0,(48+$continuation),$Receipt.rows.Count)}else{@(0,$Receipt.rows.Count)}
    Assert-Stage ($Receipt.boundaries.Count -eq $labels.Count) 'Strict boundary inventory differs.'
    for($i=0;$i -lt $labels.Count;$i++) {
        $boundary=$Receipt.boundaries[$i]
        Assert-Stage ($boundary.label -ceq $labels[$i] -and $boundary.tick -eq $ticks[$i] -and $boundary.state_hash -cmatch '^[0-9a-f]{64}$' -and $boundary.packet_sha256 -cmatch '^[0-9a-f]{64}$') 'Strict full-state/packet boundary differs.'
    }
    Assert-Stage ($Receipt.boundaries[0].actor_sha256 -ceq $Receipt.rows[0].actor_before_sha256 -and $Receipt.boundaries[-1].actor_sha256 -ceq $Receipt.rows[-1].actor_after_sha256) 'Strict endpoints do not link actor trace.'
    foreach($stderr in @("$hexOutput.log.err","$hexOutput-parse.log.err")){Assert-Stage ((Get-Item -LiteralPath $stderr).Length -eq 0) 'Strict stderr must be empty.'}
    Assert-Stage (Select-String -LiteralPath "$hexOutput.log" -SimpleMatch "STAGE_ATTRIBUTION_PASS case=$hexWorkload checks=$($Receipt.checks) rows=$($Receipt.rows.Count)" -Quiet) 'Terminal result marker differs.'
}

Assert-PhysicalStagePath $PSScriptRoot
Assert-Stage ((Get-FluxFileSha256 $hexPinsPath) -ceq $hexPinsSha) 'Reviewed Stage pin manifest differs.'
$hexPins = Get-Content -LiteralPath $hexPinsPath -Raw | ConvertFrom-Json -AsHashtable
Assert-Stage ($hexPins.schema -ceq 'hex.stage-attribution-pins.v1' -and $hexPins.runtime_identity.build_id -ceq 'p61-64590c45c7a5' -and $hexPins.source_hashes.Count -eq 337) 'Stage source scope differs.'
Assert-StageSources $hexPins.source_hashes
$hexOutput = [IO.Path]::GetFullPath($OutputDirectory); Assert-PhysicalStagePath $hexOutput
$hexLeaf = [IO.Path]::GetFileName($hexOutput)
Assert-Stage ([IO.Path]::GetDirectoryName($hexOutput) -ceq $hexRuns -and $hexLeaf -cmatch ('^'+[regex]::Escape($Case)+'-[a-z0-9]+(?:-[a-z0-9]+)*$')) 'Case-qualified fresh output must be one direct run child.'
foreach ($fresh in @($hexOutput,"$hexOutput.log","$hexOutput.log.err","$hexOutput-parse.log","$hexOutput-parse.log.err","$hexOutput-roaming")) { Assert-Stage (-not (Test-Path -LiteralPath $fresh)) "Preserve existing run: $fresh";Assert-PhysicalStagePath $fresh }
$hexReverse = $Case.EndsWith('-reverse',[StringComparison]::Ordinal); $hexWorkload = $Case.Split('-')[0]
$hexRunnerSha = Get-FluxFileSha256 $PSCommandPath
$hexPointerPath = Join-Path $hexRoot 'docs/current-delivery.json'; $hexPointerSha = Get-FluxFileSha256 $hexPointerPath
$hexGodot = Get-FluxGodot; $hexGodotSha = Get-FluxFileSha256 $hexGodot
$hexArguments = @('--path',$hexRoot,'--audio-driver','Dummy','--script',"res://$hexPrefix/compare-stages.gd",'--','--no-lan-discovery',"--case=$hexWorkload","--output=res://$hexPrefix/runs/$hexLeaf")
if ($hexReverse) { $hexArguments += '--reverse-order' }
$hexHadAppData = Test-Path Env:APPDATA; $hexSavedAppData = $env:APPDATA
$hexPassed=$false; $hexFailure=$null; $hexBefore=$null; $hexAfter=$null; $hexHelperSha=$null
$hexStarted=[DateTime]::UtcNow.ToString('o')
$hexLease=Enter-FluxEngineRun 'desktop-stage-attribution'
try {
    New-Item -ItemType Directory -Path $hexRuns -Force | Out-Null
    $env:APPDATA="$hexOutput-roaming"; New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Invoke-FluxGodotChecked $hexGodot @('--headless','--path',$hexRoot,'--check-only','--script',"res://$hexPrefix/compare-stages.gd") "$hexOutput-parse.log" -RejectWarnings -TimeoutSeconds 180 | Out-Null
    $hexBefore=Get-StageMemory
    Invoke-FluxGodotChecked $hexGodot $hexArguments "$hexOutput.log" -RejectWarnings -TimeoutSeconds 180 | Out-Null
    $hexAfter=Get-StageMemory
    $hexReceiptPath=Join-Path $hexOutput 'receipt.json'
    Assert-Stage ((Get-Item -LiteralPath $hexReceiptPath).Length -le 16MB) 'Stage receipt exceeds bounded size.'
    $receipt=Get-Content -LiteralPath $hexReceiptPath -Raw | ConvertFrom-Json -AsHashtable
    Assert-StageReceipt $receipt
    $hexHelperSha=Get-FluxFileSha256 $hexReceiptPath; $hexPassed=$true
} catch { $hexFailure=$_.Exception.Message }
finally {
    if ($null -eq $hexAfter) { $hexAfter=Get-StageMemory }
    if ($hexHadAppData) { $env:APPDATA=$hexSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $hexLease
    try {
        Assert-StageSources $hexPins.source_hashes
        Assert-Stage ((Get-FluxFileSha256 $PSCommandPath) -ceq $hexRunnerSha -and (Get-FluxFileSha256 $hexPointerPath) -ceq $hexPointerSha -and (Get-FluxFileSha256 $hexGodot) -ceq $hexGodotSha) 'Runner, qualified pointer or engine changed.'
    } catch { $hexPassed=$false; $hexFailure=([string]$hexFailure+'; '+$_.Exception.Message).Trim(';',' ') }
}
if (-not (Test-Path -LiteralPath $hexOutput)) { New-Item -ItemType Directory -Path $hexOutput | Out-Null }
$hexLogs=[ordered]@{}
foreach ($log in @("$hexOutput.log","$hexOutput.log.err","$hexOutput-parse.log","$hexOutput-parse.log.err")) { if (Test-Path -LiteralPath $log -PathType Leaf) { $hexLogs['../'+[IO.Path]::GetFileName($log)]=Get-FluxFileSha256 $log } }
$record=[ordered]@{schema='hex.stage-launcher-run.v1';passed=$hexPassed;case=$Case;failure=$hexFailure;started_utc=$hexStarted;ended_utc=[DateTime]::UtcNow.ToString('o');runner_sha256=$hexRunnerSha;source_pins_sha256=$hexPinsSha;helper_receipt_sha256=$hexHelperSha;engine_path=$hexGodot;engine_sha256=$hexGodotSha;engine_arguments=$hexArguments;parse_timeout_seconds=180;native_timeout_seconds=180;logs=$hexLogs;host_memory_before=$hexBefore;host_memory_after=$hexAfter;default_pointer_sha256=$hexPointerSha;appdata_restored=$true;scope='Seven-child simulation attribution only. Host memory endpoints are not process/private peaks. Desktop shortcut/wrapper invocation is separate external route evidence. No optimization, frame/FPS/GPU or physical-input claim.'}
$encoded=($record | ConvertTo-Json -Depth 20)+"`n"
$recordPath=Join-Path $hexOutput 'runner.json'
$stream=[IO.File]::Open($recordPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $bytes=[Text.UTF8Encoding]::new($false).GetBytes($encoded);$stream.Write($bytes,0,$bytes.Length);$stream.Flush() } finally { $stream.Dispose() }
Assert-Stage ([IO.File]::ReadAllText($recordPath) -ceq $encoded) 'Runner receipt readback differs.'
if (-not $hexPassed) { throw "Stage $Case failed: $hexFailure" }
Write-Output "PASS Stage $Case; helper receipt $hexHelperSha"
