[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateSet('hearth', 'garden-entry', 'paid-fire-bolt', 'paid-all-six-mantle')]
    [string[]]$Cases = @('hearth', 'garden-entry', 'paid-fire-bolt', 'paid-all-six-mantle'),
    [ValidateRange(1, 36000)][int]$Frames = 900,
    [ValidateRange(0, 1799)][int]$CloseAfterSeconds = 0,
    [ValidateRange(960, 2560)][int]$Width = 1280,
    [ValidateRange(540, 1440)][int]$Height = 720,
    [switch]$VisibleWindow,
    [switch]$RequestForegroundOnce,
    [ValidateRange(1, 1800)][int]$TimeoutSeconds = 180
)

# Measures the named release executable, never the editor or checkout project.
# A finite diagnostic sequence is not sustained casting. Engine FPS lines are
# one-second observations including cold startup, not presentation timestamps.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
. (Join-Path $PSScriptRoot 'measurement-observation.ps1')
if ($CloseAfterSeconds -ge $TimeoutSeconds) { throw 'Scheduled window close must precede the measurement watchdog.' }
if ($RequestForegroundOnce -and -not $VisibleWindow) { throw 'Foreground request requires explicit VisibleWindow.' }

function Get-PortableProperty($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    if ($Object -is [Collections.IDictionary]) { if ($Object.Contains($Name)) { return $Object[$Name] }; return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-PortableAvailableMemory {
    try {
        $memory = Get-CimInstance -ClassName Win32_OperatingSystem -Property FreePhysicalMemory -ErrorAction Stop
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); available_mb = [Math]::Round([double]$memory.FreePhysicalMemory / 1024.0, 2); error = $null }
    } catch {
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); available_mb = $null; error = $_.Exception.Message }
    }
}

function Write-PortableJson([string]$Path, $Value) {
    if (Test-Path -LiteralPath $Path) { throw "Evidence already exists: $Path" }
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function Read-PortableObservations([string]$Path, [Collections.IEnumerable]$Lines = $null) {
    $fps = [Collections.Generic.List[object]]::new()
    $chemistry = [Collections.Generic.List[object]]::new()
    $casts = [Collections.Generic.List[object]]::new()
    $identities = [Collections.Generic.List[object]]::new()
    $parseErrors = [Collections.Generic.List[string]]::new()
    $lineNumber = 0
    $maximumRecords = 8192
    $records = 0
    $limitExceeded = $false
    if ($null -eq $Lines) {
        $Lines = @()
        # Keep the lazy iterator itself; an if-expression assignment would
        # enumerate the entire log before the record bound could stop it.
        if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) { $Lines = [IO.File]::ReadLines($Path) }
    }
    if ($null -ne $Lines) {
        foreach ($line in $Lines) {
            $lineNumber++
            if ($line -notmatch '^(Project FPS:|FLUX2 runtime build:|FLUX2 paid chemistry capture:|FLUX2 spell capture:)') { continue }
            $records++
            if ($records -gt $maximumRecords) { $limitExceeded = $true; break }
            if ($line.Length -gt 262144) { $parseErrors.Add("Observation line $lineNumber exceeds 256KiB; inspect the retained raw log."); break }
            if ($line -match '^Project FPS:\s*(?<fps>[0-9]+(?:\.[0-9]+)?)\s*\((?<ms>[0-9]+(?:\.[0-9]+)?)\s+mspf\)\s*$') {
                $fps.Add([ordered]@{ line_number = $lineNumber; fps = [double]::Parse($Matches.fps, [Globalization.CultureInfo]::InvariantCulture); reported_mspf = [double]::Parse($Matches.ms, [Globalization.CultureInfo]::InvariantCulture); raw = $line })
            } elseif ($line -match '^Project FPS:') { $parseErrors.Add("Unparsed FPS line $lineNumber`: $line") }
            if ($line -match '^FLUX2 runtime build:\s*(?<id>p[0-9]+-[0-9a-f]{12})\s*\|\s*(?<hash>[0-9a-f]{64})\s*$') {
                $identities.Add([ordered]@{ line_number = $lineNumber; build_id = $Matches.id; runtime_source_sha256 = $Matches.hash })
            }
            if ($line -match '^FLUX2 paid chemistry capture: tick (?<tick>[0-9]+) (?<json>.+)$') {
                $eventTick = [long]$Matches.tick
                $json = $Matches.json
                try { $chemistry.Add([ordered]@{ line_number = $lineNumber; simulation_tick = $eventTick; event = ($json | ConvertFrom-Json -ErrorAction Stop); raw = $line }) }
                catch { $parseErrors.Add("Invalid chemistry JSON at line $lineNumber`: $($_.Exception.Message)") }
            }
            if ($line -match '^FLUX2 spell capture: tick (?<tick>[0-9]+) pending (?<wire>[0-9]+)/(?<ticks>[0-9]+) projectiles (?<shots>[0-9]+) fields (?<fields>[0-9]+) events (?<json>.+)$') {
                $captureRow = [ordered]@{ line_number = $lineNumber; simulation_tick = [long]$Matches.tick; pending_wire_id = [int]$Matches.wire; pending_ticks = [int]$Matches.ticks; projectile_count = [int]$Matches.shots; field_count = [int]$Matches.fields; events = @(); raw = $line }
                $json = $Matches.json
                try { $captureRow.events = @($json | ConvertFrom-Json -ErrorAction Stop); $casts.Add($captureRow) }
                catch { $parseErrors.Add("Invalid combat JSON at line $lineNumber`: $($_.Exception.Message)") }
            }
        }
    }
    if ($limitExceeded) { $parseErrors.Add('Observation storage exceeded 8192 recognized records; partial observations are retained, never admitted as a completed measurement.') }
    $summary = [ordered]@{ sample_count = $fps.Count; mean_reported_fps = $null; minimum_reported_fps = $null; maximum_reported_fps = $null }
    if ($fps.Count -gt 0) {
        $values = @($fps | ForEach-Object { $_.fps })
        $statistics = $values | Measure-Object -Average -Minimum -Maximum
        $summary.mean_reported_fps = $statistics.Average
        $summary.minimum_reported_fps = $statistics.Minimum
        $summary.maximum_reported_fps = $statistics.Maximum
    }
    return [ordered]@{ fps_summary = $summary; fps_samples = $fps.ToArray(); chemistry_observations = $chemistry.ToArray(); combat_observations = $casts.ToArray(); runtime_identities = $identities.ToArray(); parse_errors = $parseErrors.ToArray(); maximum_recognized_records = $maximumRecords; storage_limit_exceeded = $limitExceeded }
}

function Get-PortableWorkloadPhases($Observations, [int]$Wire) {
    $anchors = [Collections.Generic.List[object]]::new()
    foreach ($combat in $Observations.combat_observations) {
        foreach ($event in $combat.events) {
            $kind = Get-PortableProperty $event 'type' ''
            if ([int](Get-PortableProperty $event 'wire_id' 0) -eq $Wire -and $Wire -gt 0 -and $kind -in @('cast_started', 'cast_refused')) {
                $anchors.Add([ordered]@{ line_number = $combat.line_number; simulation_tick = $combat.simulation_tick; event = $kind; wire_id = $Wire })
            }
        }
    }
    $first = if ($anchors.Count -gt 0) { $anchors[0] } else { $null }
    $last = if ($anchors.Count -gt 0) { $anchors[$anchors.Count - 1] } else { $null }
    foreach ($fps in $Observations.fps_samples) {
        $fps['log_order_phase'] = if ($null -eq $first) { 'unpartitioned_cold_to_idle' } elseif ($fps.line_number -lt $first.line_number) { 'before_first_attempt' } elseif ($fps.line_number -le $last.line_number) { 'between_attempt_log_anchors' } else { 'after_last_attempt_effect_lifetime_unknown' }
    }
    return [ordered]@{ first_attempt = $first; last_attempt = $last; attempt_log_anchors = $anchors.ToArray(); scope = 'Coarse stdout ordering only. Each FPS line spans about the preceding second and may cross an anchor; it is not an active-frame timing bucket. Effects may persist after the last attempt. No cold/idle or active-only FPS average is inferred.' }
}

$portableRoot = Get-FluxRepoRoot
if (-not [IO.Path]::IsPathRooted($PackDirectory)) { $PackDirectory = Join-Path $portableRoot $PackDirectory }
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory = Join-Path $portableRoot $OutputDirectory }
$PackDirectory = [IO.Path]::GetFullPath($PackDirectory)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a fresh output directory; prior measurements are preserved.' }
if ($OutputDirectory.StartsWith($PackDirectory.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Measurement output must be outside the portable directory.' }
if ($Cases.Count -eq 0 -or @($Cases | Select-Object -Unique).Count -ne $Cases.Count) { throw 'Select at least one case, without duplicates.' }
$portableExe = Join-Path $PackDirectory 'hex.exe'
$portablePack = Join-Path $PackDirectory 'hex.pck'
$portableBuildPath = Join-Path $PackDirectory 'BUILD-STATE.json'
foreach ($path in @($portableExe, $portablePack, $portableBuildPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing exact portable payload file: $path" }
}
$portableBefore = [ordered]@{ exe_sha256 = Get-FluxFileSha256 $portableExe; pack_sha256 = Get-FluxFileSha256 $portablePack; build_state_sha256 = Get-FluxFileSha256 $portableBuildPath }
$portableBuild = Get-Content -Raw -LiteralPath $portableBuildPath | ConvertFrom-Json -ErrorAction Stop
$portableIdentity = Get-PortableProperty (Get-PortableProperty (Get-PortableProperty $portableBuild 'state') 'runtime') 'build_identity'
$portableBuildId = [string](Get-PortableProperty $portableIdentity 'build_id' '')
$portableSourceHash = [string](Get-PortableProperty $portableIdentity 'runtime_source_sha256' '')
if ((Get-PortableProperty $portableBuild 'source_kind' '') -cne 'exported_pack' -or (Get-PortableProperty $portableBuild 'pack_sha256' '') -cne $portableBefore.pack_sha256 -or $portableBuildId -cnotmatch '^p[0-9]+-[0-9a-f]{12}$' -or $portableSourceHash -cnotmatch '^[0-9a-f]{64}$') { throw 'BUILD-STATE must identify this exact exported PCK and a valid release identity.' }

$portableCaseRows = @{
    'hearth' = @{ Wire = 0; Spawn = @(1536, 880); Extra = @('--capture-spawn=1536,880') }
    'garden-entry' = @{ Wire = 0; Spawn = @(4880, 720); Extra = @('--capture-spawn=4880,720') }
    'paid-fire-bolt' = @{ Wire = 145; Spawn = @(1536, 880); Extra = @('--capture-spawn=1536,880', '--capture-pointer=1736,880', '--capture-spell-wires=145', '--capture-cast-slot=1', '--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1') }
    'paid-all-six-mantle' = @{ Wire = 1319; Spawn = @(1536, 880); Extra = @('--capture-spawn=1536,880', '--capture-pointer=1736,880', '--capture-spell-wires=1319', '--capture-cast-slot=1', '--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1') }
}
$portableScope = 'Actual named release EXE/PCK; engine one-second FPS observations include cold startup and output logging. Not a frame-present trace, input-latency measurement, GPU timer, or sustained casting certification. Twelve finite slot-1 attempts use ordinary cooldown/Flux rules; refusals and idle after sequence/expiry remain in the sample. No resource refill or current-source engine is used. Exit mode is recorded per case: engine-iteration-limit uses --quit-after; normal-window-close sends a close request to this owned process after the requested wall time and requires the application safe-close marker. Requested engine iterations are not seconds or verified displayed-frame counts; they are null in normal-close mode. Exact owned-HWND physical client pixels, foreground and visibility/minimization are sampled roughly every500ms and validated. Unavailable-handle startup/shutdown boundaries are retained and explicitly excluded; an interior missing window fails. Sampling does not prove continuous focus or unobscured presentation. Failed diagnostics retain partial samples and raw logs.'
$portableRunId = [Guid]::NewGuid().ToString('D')
$portableInputsBefore = [ordered]@{}
foreach ($path in @($PSCommandPath, (Join-Path $PSScriptRoot 'flux2-common.ps1'), (Join-Path $PSScriptRoot 'engine-guard.ps1'), (Join-Path $PSScriptRoot 'measurement-observation.ps1'))) { $portableInputsBefore[$path] = Get-FluxFileSha256 $path }
$portablePresentTools = Get-MeasurementPresentToolAvailability
$portableLease = Enter-FluxEngineRun 'measure-actual-portable'
$portableHadAppData = Test-Path Env:APPDATA
$portableSavedAppData = $env:APPDATA
$portableResults = [Collections.Generic.List[object]]::new()
$portableError = $null
$portableAfter = $null
$portableMemoryBefore = Get-PortableAvailableMemory
try {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    Copy-Item -LiteralPath $portableBuildPath -Destination (Join-Path $OutputDirectory 'BUILD-STATE.input.json')
    foreach ($caseName in $Cases) {
        $definition = $portableCaseRows[$caseName]
        $caseDirectory = Join-Path $OutputDirectory $caseName
        New-Item -ItemType Directory -Path $caseDirectory | Out-Null
        $env:APPDATA = Join-Path $caseDirectory 'isolated-roaming'
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $arguments = @('--print-fps', '--windowed', '--resolution', "${Width}x${Height}")
        if ($CloseAfterSeconds -eq 0) { $arguments += @('--quit-after', [string]$Frames) }
        $arguments += @('--', '--fullbody-art', '--pixel-cast', '--no-lan-discovery') + $definition.Extra
        $logPath = Join-Path $caseDirectory 'engine.log'
        $caseError = $null
        $windowObservations = [Collections.Generic.List[object]]::new()
        $windowActivations = [Collections.Generic.List[object]]::new()
        $memoryBefore = Get-PortableAvailableMemory
        $startedUtc = [DateTime]::UtcNow.ToString('o')
        $watch = [Diagnostics.Stopwatch]::StartNew()
        Push-Location -LiteralPath $PackDirectory
        try { Invoke-FluxGodotChecked $portableExe $arguments $logPath -RejectWarnings -TimeoutSeconds $TimeoutSeconds -CloseAfterSeconds $CloseAfterSeconds -VisibleWindow:$VisibleWindow -WindowObservations $windowObservations -RequestForegroundOnce:$RequestForegroundOnce -WindowActivationRequests $windowActivations | Out-Null }
        catch { $caseError = $_.Exception.Message }
        finally { Pop-Location; $watch.Stop() }
        $memoryAfter = Get-PortableAvailableMemory
        $observations = Read-PortableObservations $logPath
        $validation = [Collections.Generic.List[string]]::new()
        if ($null -ne $caseError) { $validation.Add($caseError) }
        $windowAssessment = Get-MeasurementWindowAssessment $windowObservations.ToArray() $Width $Height
        foreach ($message in $windowAssessment.errors) { $validation.Add($message) }
        foreach ($message in @(Get-MeasurementActivationErrors ([bool]$RequestForegroundOnce) $windowActivations.ToArray() $windowObservations.ToArray())) { $validation.Add($message) }
        foreach ($message in $observations.parse_errors) { $validation.Add($message) }
        if ($observations.fps_summary.sample_count -eq 0) { $validation.Add('No engine FPS observation was emitted; this is not a completed FPS measurement.') }
        if ($observations.runtime_identities.Count -ne 1 -or $observations.runtime_identities[0].build_id -cne $portableBuildId -or $observations.runtime_identities[0].runtime_source_sha256 -cne $portableSourceHash) { $validation.Add('Runtime log did not prove exactly the BUILD-STATE identity.') }
        $accepted = 0
        $refused = 0
        foreach ($combat in $observations.combat_observations) {
            foreach ($event in $combat.events) {
                if ([int](Get-PortableProperty $event 'wire_id' 0) -ne [int]$definition.Wire) { continue }
                $kind = Get-PortableProperty $event 'type' ''
                if ($kind -ceq 'cast_started') { $accepted++ }
                if ($kind -ceq 'cast_refused') { $refused++ }
            }
        }
        if ($definition.Wire -gt 0 -and ($accepted -eq 0 -or $accepted + $refused -ne 12)) { $validation.Add('Finite cast case must prove all 12 admitted/refused attempts, including at least one admitted cast.') }
        $safeCloseLogged = (Test-Path -LiteralPath $logPath -PathType Leaf) -and (Select-String -LiteralPath $logPath -SimpleMatch 'safe quit: local state flushed and network peer closed' -Quiet)
        if ($CloseAfterSeconds -gt 0 -and -not $safeCloseLogged) { $validation.Add('Normal window-close mode did not prove the application safe-close path.') }
        $stderrBytes = if (Test-Path -LiteralPath "$logPath.err") { (Get-Item -LiteralPath "$logPath.err").Length } else { 0 }
        if ($stderrBytes -ne 0) { $validation.Add('Release process emitted stderr; retain and inspect the exact log.') }
        $row = [ordered]@{ case = $caseName; status = if ($validation.Count -eq 0) { 'measured' } else { 'incomplete_or_failed' }; started_utc = $startedUtc; process_wall_seconds = $watch.Elapsed.TotalSeconds; engine_iterations_requested = $Frames; watchdog_seconds = $TimeoutSeconds; arguments = $arguments; requested_spawn_px = $definition.Spawn; requested_wire_id = $definition.Wire; finite_sequence_attempts_requested = if ($definition.Wire -gt 0) { 12 } else { 0 }; admitted_cast_events = $accepted; refused_cast_events = $refused; memory_before = $memoryBefore; memory_after = $memoryAfter; stderr_bytes = $stderrBytes; validation_errors = $validation.ToArray(); observations = $observations; scope = $portableScope }
        $row['requested_window_style'] = if ($VisibleWindow) { 'Normal' } else { 'Hidden' }
        $row['exit_mode'] = if ($CloseAfterSeconds -gt 0) { 'normal-window-close' } else { 'engine-iteration-limit' }
        $row['close_after_seconds_requested'] = $CloseAfterSeconds
        $row['safe_close_logged'] = $safeCloseLogged
        if ($CloseAfterSeconds -gt 0) { $row.engine_iterations_requested = $null }
        $row['window_observations'] = $windowObservations.ToArray()
        $row['window_assessment'] = $windowAssessment
        $row['foreground_request_opt_in'] = [bool]$RequestForegroundOnce
        $row['window_activation_requests'] = $windowActivations.ToArray()
        $row['run_id'] = $portableRunId
        $row['case_index'] = $portableResults.Count
        $row['observer_mode'] = 'portable-stdout-and-window-sampling'
        $row['workload'] = [ordered]@{ fresh_process = $true; isolated_user_data = $env:APPDATA; spawn_request_px = $definition.Spawn; wire_request = $definition.Wire; resource_refill = $false; finite_attempts = if ($definition.Wire -gt 0) { 12 } else { 0 }; client_pixels_requested = @($Width, $Height); phases = Get-PortableWorkloadPhases $observations $definition.Wire }
        Write-PortableJson (Join-Path $caseDirectory 'measurement.json') $row
        $portableResults.Add($row)
        Write-Output ("Portable {0}: {1}, {2} FPS observations, mean reported FPS {3}" -f $caseName, $row.status, $observations.fps_summary.sample_count, $observations.fps_summary.mean_reported_fps)
        if ((Get-FluxFileSha256 $portableExe) -cne $portableBefore.exe_sha256 -or (Get-FluxFileSha256 $portablePack) -cne $portableBefore.pack_sha256) { throw 'Portable executable or PCK changed; no further cases will run.' }
        foreach ($path in $portableInputsBefore.Keys) { if ((Get-FluxFileSha256 $path) -cne $portableInputsBefore[$path]) { throw 'A measurement input changed; raw case evidence is retained and no further cases will run.' } }
    }
} catch { $portableError = $_.Exception.Message }
finally {
    if ($portableHadAppData) { $env:APPDATA = $portableSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $portableLease
}
$portableMemoryAfter = Get-PortableAvailableMemory
$portableAfter = [ordered]@{ exe_sha256 = Get-FluxFileSha256 $portableExe; pack_sha256 = Get-FluxFileSha256 $portablePack; build_state_sha256 = Get-FluxFileSha256 $portableBuildPath }
$portableUnchanged = $portableBefore.exe_sha256 -ceq $portableAfter.exe_sha256 -and $portableBefore.pack_sha256 -ceq $portableAfter.pack_sha256 -and $portableBefore.build_state_sha256 -ceq $portableAfter.build_state_sha256
$portableInputsAfter = [ordered]@{}
$portableInputsUnchanged = $true
foreach ($path in $portableInputsBefore.Keys) {
    $portableInputsAfter[$path] = if (Test-Path -LiteralPath $path -PathType Leaf) { Get-FluxFileSha256 $path } else { $null }
    if ($portableInputsAfter[$path] -cne $portableInputsBefore[$path]) { $portableInputsUnchanged = $false }
}
$portableComplete = $null -eq $portableError -and $portableUnchanged -and $portableInputsUnchanged -and $portableResults.Count -eq $Cases.Count -and @($portableResults | Where-Object { $_.status -cne 'measured' }).Count -eq 0
$portableReport = [ordered]@{ schema_version = 1; status = if ($portableComplete) { 'measured' } else { 'incomplete_or_failed' }; scope = $portableScope; pack_directory = $PackDirectory; output_directory = $OutputDirectory; wrapper_sha256 = Get-FluxFileSha256 $PSCommandPath; expected_release_identity = $portableIdentity; payload_before = $portableBefore; payload_after = $portableAfter; payload_unchanged = $portableUnchanged; available_memory_before = $portableMemoryBefore; available_memory_after = $portableMemoryAfter; requested_cases = $Cases; cases = $portableResults.ToArray(); error = $portableError }
$portableReport['engine_helper_sha256'] = Get-FluxFileSha256 (Join-Path $PSScriptRoot 'flux2-common.ps1')
$portableReport['run_id'] = $portableRunId
$portableReport['measurement_inputs_before'] = $portableInputsBefore
$portableReport['measurement_inputs_after'] = $portableInputsAfter
$portableReport['measurement_inputs_unchanged'] = $portableInputsUnchanged
$portableReport['frame_present_tool_availability'] = $portablePresentTools
if (Test-Path -LiteralPath $OutputDirectory -PathType Container) { Write-PortableJson (Join-Path $OutputDirectory 'measurement.json') $portableReport }
if (-not $portableComplete) { throw "Portable measurement was incomplete or failed; inspect $OutputDirectory" }
Write-Output "MEASURED: exact portable retained; raw observations and scoped evidence saved to $OutputDirectory"
