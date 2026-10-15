[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('normal-forward','normal-reverse','reduced-forward','reduced-reverse')][string]$Case,
    [Parameter(Mandatory)][string]$OutputDirectory
)
# Attribution only, through the desktop Diagnostic route; no candidate promotion.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$hexRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$hexRuns = Join-Path $PSScriptRoot 'runs'
$hexPrefix = '.godot/iteration-20261014/garden-next'
$hexPinsPath = Join-Path $PSScriptRoot 'source-pins.json'
$hexPinsSha = 'c6fc23afac0b0e31c8f554ae1f0359c3f8fb1b7a7a07d1b44a1578e8dc50e618'
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
    $first = if ($observedFirst) { 'observed' } else { 'plain' }; $second = if ($observedFirst) { 'plain' } else { 'observed' }
    Assert-Garden ($Order.Count -eq 2 -and $Order[0] -ceq $first -and $Order[1] -ceq $second) 'Actual paired invocation order differs.'
}
function Assert-GardenReceipt([System.Collections.IDictionary]$Receipt) {
    Assert-Garden ($Receipt.schema -ceq 'hex.garden-attribution.v1' -and $Receipt.passed -is [bool] -and $Receipt.passed -ceq $true -and $Receipt.errors.Count -eq 0 -and $Receipt.checks -gt 0) 'Garden helper failed.'
    Assert-Garden ($Receipt.reverse_order -ceq $hexReverse -and $Receipt.reduced -ceq $hexReduced -and $Receipt.source_pins_sha256 -ceq $hexPinsSha) 'Requested case or pin linkage differs.'
    Assert-GardenSources $Receipt.source_hashes
    Assert-Garden ($Receipt.cleanup.created -eq 2 -and $Receipt.cleanup.freed -eq 2 -and $Receipt.cleanup.live -eq 0) 'Garden owners did not close.'
    Assert-Garden ($Receipt.warmups -eq 4 -and $Receipt.measured_pairs -eq 16 -and $Receipt.cases.Count -eq 6 -and $Receipt.arrival_rows.Count -eq 50) 'Bounded draw/arrival inventory differs.'
    $labels = @('published','first_active_boundary','first_expiry','first_restart','departed','reentered')
    for ($i=0; $i -lt 6; $i++) {
        $row = $Receipt.cases[$i]
        Assert-Garden ($row.label -ceq $labels[$i] -and $row.rows.Count -eq 20 -and $row.exact_rgba_first_and_final -ceq $true) 'Case order/rows/RGBA differs.'
        for ($j=0; $j -lt 20; $j++) {
            $draw = $row.rows[$j]
            Assert-Garden ($draw.index -eq $j -and $draw.warmup -ceq ($j -lt 4)) 'Warmup/measurement inventory differs.'
            Assert-GardenOrder $draw.actual_order $j
            Assert-Garden ($draw.plain.entries -eq $draw.observed.entries -and $draw.plain.whole_pipeline_us -ge 0 -and $draw.observed.whole_pipeline_us -ge 0) 'Draw sample is invalid.'
            $child = $draw.observed.surface; $projection = $draw.observed.model
            Assert-Garden ($child.build_us -le $child.geometry_us -and $child.geometry_us -le $child.prepare_us -and $child.prepare_us+$child.retain_us+$projection.projection_us -le $draw.observed.whole_pipeline_us -and $projection.projection_calls -eq 1 -and $child.prepare_calls -eq $draw.observed.entries) 'Nested observer clocks/counts differ.'
        }
        $image = Resolve-GardenSource $row.image.path
        Assert-Garden ([IO.Path]::GetDirectoryName($image) -ceq $hexOutput -and [IO.Path]::GetFileName($image) -ceq ($labels[$i]+'.png') -and (Get-FluxFileSha256 $image) -ceq $row.image.sha256) 'Native PNG path/hash differs.'
    }
    for ($i=0; $i -lt 50; $i++) {
        $row = $Receipt.arrival_rows[$i]; $index = $i % 25
        Assert-Garden ($row.index -eq $index -and $row.label -ceq $(if ($i -lt 25) { 'initial' } else { 'reentry' })) 'Arrival order differs.'
        Assert-GardenOrder $row.actual_order $index
        Assert-Garden ($row.arms.plain.prepared -eq $index+1 -and $row.arms.observed.prepared -eq $index+1 -and $row.arms.observed.model.emit_calls -eq 1 -and $row.arms.observed.surface.prepare_calls -eq 1) 'One authority emission/visual preparation per arrival frame differs.'
    }
    Assert-Garden ($Receipt.groups.Count -gt 3 -and $Receipt.groups.Count -le 501) 'Exhibition group count exceeds bounds.'
    $totalSteps = 0
    for ($i=0; $i -lt $Receipt.groups.Count; $i++) {
        $row = $Receipt.groups[$i]; $count = [int]$row.steps
        Assert-Garden ($row.index -eq $i -and $count -in @(0,1,8) -and $row.steps -eq $count) 'Group step/index is invalid.'
        Assert-GardenOrder $row.actual_order $i
        Assert-Garden ($row.arms.plain.okay -ceq $true -and $row.arms.observed.okay -ceq $true -and $row.arms.plain.completed -eq $count -and $row.arms.observed.completed -eq $count) 'Group did not complete exactly.'
        $observation = $row.arms.observed.observer
        Assert-Garden ($observation.step_calls -eq $count -and $observation.emit_calls -le 1 -and $observation.emit_us -le $observation.step_us -and $observation.step_us -le $row.arms.observed.whole_exhibit_frame_us) 'Group observer count/containment differs.'
        $totalSteps += $count
    }
    Assert-Garden ($totalSteps -le 1501 -and $Receipt.groups[-1].steps -eq 1) 'Finite evolution/departure horizon differs.'
    foreach ($stderr in @("$hexOutput.log.err","$hexOutput-parse.log.err")) { Assert-Garden ((Get-Item -LiteralPath $stderr).Length -eq 0) 'Strict stderr is not empty.' }
    Assert-Garden (Select-String -LiteralPath "$hexOutput.log" -SimpleMatch "GARDEN_ATTRIBUTION_PASS checks=$($Receipt.checks) cases=6" -Quiet) 'Terminal result marker differs.'
}

Assert-PhysicalGardenPath $PSScriptRoot
Assert-Garden ((Get-FluxFileSha256 $hexPinsPath) -ceq $hexPinsSha) 'Reviewed Garden pin manifest differs.'
$hexPins = Get-Content -LiteralPath $hexPinsPath -Raw | ConvertFrom-Json -AsHashtable
Assert-Garden ($hexPins.schema -ceq 'hex.garden-attribution-pins.v1' -and $hexPins.runtime_identity.build_id -ceq 'p61-64590c45c7a5' -and $hexPins.source_hashes.Count -eq 330) 'Garden source scope differs.'
Assert-GardenSources $hexPins.source_hashes
$hexOutput = [IO.Path]::GetFullPath($OutputDirectory); Assert-PhysicalGardenPath $hexOutput
$hexLeaf = [IO.Path]::GetFileName($hexOutput)
Assert-Garden ([IO.Path]::GetDirectoryName($hexOutput) -ceq $hexRuns -and $hexLeaf -cmatch ('^'+[regex]::Escape($Case)+'-[a-z0-9]+(?:-[a-z0-9]+)*$')) 'Case-qualified fresh output must be one direct run child.'
foreach ($fresh in @($hexOutput,"$hexOutput.log","$hexOutput.log.err","$hexOutput-parse.log","$hexOutput-parse.log.err","$hexOutput-roaming")) { Assert-Garden (-not (Test-Path -LiteralPath $fresh)) "Preserve existing run: $fresh";Assert-PhysicalGardenPath $fresh }
$hexReverse = $Case.EndsWith('-reverse',[StringComparison]::Ordinal); $hexReduced = $Case.StartsWith('reduced-',[StringComparison]::Ordinal)
$hexRunnerSha = Get-FluxFileSha256 $PSCommandPath
$hexPointerPath = Join-Path $hexRoot 'docs/current-delivery.json'; $hexPointerSha = Get-FluxFileSha256 $hexPointerPath
$hexGodot = Get-FluxGodot; $hexGodotSha = Get-FluxFileSha256 $hexGodot
$hexArguments = @('--path',$hexRoot,'--audio-driver','Dummy','--script',"res://$hexPrefix/compare-garden.gd",'--','--no-lan-discovery',"--output=res://$hexPrefix/runs/$hexLeaf")
if ($hexReverse) { $hexArguments += '--reverse-order' }; if ($hexReduced) { $hexArguments += '--reduced' }
$hexHadAppData = Test-Path Env:APPDATA; $hexSavedAppData = $env:APPDATA
$hexPassed=$false; $hexFailure=$null; $hexBefore=$null; $hexAfter=$null; $hexHelperSha=$null
$hexStarted=[DateTime]::UtcNow.ToString('o')
$hexLease=Enter-FluxEngineRun 'desktop-garden-attribution'
try {
    New-Item -ItemType Directory -Path $hexRuns -Force | Out-Null
    $env:APPDATA="$hexOutput-roaming"; New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Invoke-FluxGodotChecked $hexGodot @('--headless','--path',$hexRoot,'--check-only','--script',"res://$hexPrefix/compare-garden.gd") "$hexOutput-parse.log" -RejectWarnings -TimeoutSeconds 180 | Out-Null
    $hexBefore=Get-GardenMemory
    Invoke-FluxGodotChecked $hexGodot $hexArguments "$hexOutput.log" -RejectWarnings -TimeoutSeconds 300 | Out-Null
    $hexAfter=Get-GardenMemory
    $hexReceiptPath=Join-Path $hexOutput 'receipt.json'
    Assert-Garden ((Get-Item -LiteralPath $hexReceiptPath).Length -le 16MB) 'Garden receipt exceeds bounded size.'
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
$record=[ordered]@{schema='hex.garden-launcher-run.v1';passed=$hexPassed;case=$Case;failure=$hexFailure;started_utc=$hexStarted;ended_utc=[DateTime]::UtcNow.ToString('o');runner_sha256=$hexRunnerSha;source_pins_sha256=$hexPinsSha;helper_receipt_sha256=$hexHelperSha;engine_path=$hexGodot;engine_sha256=$hexGodotSha;engine_arguments=$hexArguments;parse_timeout_seconds=180;native_timeout_seconds=300;logs=$hexLogs;host_memory_before=$hexBefore;host_memory_after=$hexAfter;default_pointer_sha256=$hexPointerSha;appdata_restored=$true;scope='Garden method attribution only. Host memory endpoints and engine monitor fields are not process/private peaks. Desktop shortcut/wrapper invocation is separate external route evidence. No optimization, frame/FPS/GPU or physical-input claim.'}
$encoded=($record | ConvertTo-Json -Depth 20)+"`n"
$recordPath=Join-Path $hexOutput 'runner.json'
$stream=[IO.File]::Open($recordPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $bytes=[Text.UTF8Encoding]::new($false).GetBytes($encoded);$stream.Write($bytes,0,$bytes.Length);$stream.Flush() } finally { $stream.Dispose() }
Assert-Garden ([IO.File]::ReadAllText($recordPath) -ceq $encoded) 'Runner receipt readback differs.'
if (-not $hexPassed) { throw "Garden $Case failed: $hexFailure" }
Write-Output "PASS Garden $Case; helper receipt $hexHelperSha"
