[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateSet('low', 'standard')][string[]]$Profiles = @('low', 'standard'),
    [ValidateSet('hearth_idle', 'garden_entry', 'garden_middle', 'paid_fire_bolt', 'paid_all_six_mantle', 'movement_boundary', 'range_paid_fire', 'paid_fire_bolt_close', 'paid_fire_bolt_sustained', 'paid_all_six_mantle_sustained')]
    [string[]]$Cases = @('hearth_idle', 'garden_entry', 'garden_middle', 'paid_fire_bolt', 'paid_all_six_mantle', 'movement_boundary', 'range_paid_fire'),
    [ValidateRange(1, 600)][double]$SecondsPerCase = 10,
    [ValidateRange(0, 3600)][double]$SoakSeconds = 0,
    [ValidateSet(0, 60, 120)][int]$FrameLimit = 60,
    [ValidateRange(960, 2560)][int]$Width = 1280,
    [ValidateRange(540, 1440)][int]$Height = 720,
    [switch]$LightObserver,
    [switch]$ViewportRenderTiming,
    [switch]$ReferenceCampus,
    [switch]$RequestForegroundOnce,
    [switch]$WaitForForeground,
    [switch]$Screenshots,
    [ValidateRange(1, 1800)][int]$TimeoutSeconds = 900
)

# Native source diagnostic only. This wrapper never imports, changes a runtime
# identity, promotes a build, or runs a packaged release executable.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
. (Join-Path $PSScriptRoot 'measurement-observation.ps1')

function Get-GameplayProfileValue($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-GameplayProfileMemory {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -Property Caption, Version, FreePhysicalMemory, TotalVisibleMemorySize -ErrorAction Stop
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); os = $os.Caption; os_version = $os.Version; available_mb = [Math]::Round([double]$os.FreePhysicalMemory / 1024.0, 2); total_visible_mb = [Math]::Round([double]$os.TotalVisibleMemorySize / 1024.0, 2); error = $null }
    } catch {
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); available_mb = $null; error = $_.Exception.Message }
    }
}

function Write-GameplayProfileReceipt([string]$Path, $Value) {
    $text = ($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    if ([IO.File]::ReadAllText($Path) -cne $text) { throw "Receipt read-back differs: $Path" }
}

function Get-GameplayProfileExpectedRows([string[]]$SelectedProfiles, [string[]]$SelectedCases, [double]$SelectedSoak) {
    [pscustomobject]@{ label = 'startup_arrival'; quality = $SelectedProfiles[0]; temperature = 'cold_process_cache' }
    foreach ($quality in $SelectedProfiles) {
        foreach ($label in $SelectedCases) {
            if ($label -in @('garden_entry', 'garden_middle')) {
                [pscustomobject]@{ label = $label + '_arrival'; quality = $quality; temperature = 'travel_process_cache_state_recorded' }
            }
            [pscustomobject]@{ label = $label; quality = $quality; temperature = 'warm' }
        }
        if ($SelectedSoak -gt 0) {
            [pscustomobject]@{ label = 'garden_middle_arrival'; quality = $quality; temperature = 'travel_process_cache_state_recorded' }
            [pscustomobject]@{ label = 'garden_soak'; quality = $quality; temperature = 'warm' }
        }
    }
}

function Get-GameplayProfileReportErrors($Report, $Expected) {
    $errors = [Collections.Generic.List[string]]::new()
    if ((Get-GameplayProfileValue $Report 'schema' '') -cne 'hex-gameplay-profile-v1' -or (Get-GameplayProfileValue $Report 'complete' $false) -cne $true) { $errors.Add('Benchmark receipt is absent, incompatible, or incomplete.') }
    if (Get-GameplayProfileValue $Report 'error' '') { $errors.Add('Benchmark receipt records an error.') }
    if ((Get-GameplayProfileValue $Report 'run_id' '') -cne (Get-GameplayProfileValue $Expected 'run_id' 'missing')) { $errors.Add('Benchmark run ID differs from this wrapper invocation.') }
    $arming = Get-GameplayProfileValue $Report 'foreground_arming'
    $waitForForeground = [bool](Get-GameplayProfileValue $Expected 'wait_for_foreground' $false)
    foreach ($message in @(Get-MeasurementArmingErrors $arming $waitForForeground)) { $errors.Add($message) }
    foreach ($message in @(Get-GameplayProfileBudgetErrors (Get-GameplayProfileValue $Report 'observation_limits'))) { $errors.Add("Run: $message") }
    foreach ($message in @(Get-GameplayProfileViewportErrors $Report $Expected)) { $errors.Add($message) }
    foreach ($key in @('observed_source_before', 'observed_source_after')) {
        $snapshot = Get-GameplayProfileValue $Report $key
        if ((Get-GameplayProfileValue $snapshot 'ok' $false) -cne $true -or (Get-GameplayProfileValue $snapshot 'sha256' '') -cnotmatch '^[0-9a-f]{64}$') { $errors.Add("Missing valid independent source snapshot: $key") }
    }
    $before = Get-GameplayProfileValue $Report 'observed_source_before'
    $after = Get-GameplayProfileValue $Report 'observed_source_after'
    if ((Get-GameplayProfileValue $Report 'observed_source_unchanged' $false) -cne $true -or (Get-GameplayProfileValue $before 'sha256' '') -cne (Get-GameplayProfileValue $after 'sha256' '')) { $errors.Add('Benchmark source changed during the run.') }
    if ((Get-GameplayProfileValue $Report 'profile_script_sha256' '') -cne $Expected.script_sha256) { $errors.Add('Benchmark script identity differs from the launched source.') }
    $manifest = Get-GameplayProfileValue $Report 'manifest'
    foreach ($key in @('build_id', 'runtime_source_sha256', 'engine_identity', 'protocol_version', 'snapshot_schema', 'record_count')) {
        if ((Get-GameplayProfileValue $manifest $key) -cne (Get-GameplayProfileValue $Expected.identity $key)) { $errors.Add("Runtime manifest mismatch: $key") }
    }
    if (([string](Get-GameplayProfileValue $Report 'user_data' '')).Replace('\', '/').TrimEnd('/') -ine $Expected.user_data.Replace('\', '/').TrimEnd('/')) { $errors.Add('Runtime user-data directory is not the exact isolated profile.') }
    if (([string](Get-GameplayProfileValue $Report 'executable' '')).Replace('\', '/') -ine $Expected.engine.Replace('\', '/')) { $errors.Add('Runtime executable differs from the selected Godot binary.') }
    $engine = Get-GameplayProfileValue $Report 'engine'
    $enginePrefix = (@('major', 'minor', 'patch', 'status', 'build') | ForEach-Object { [string](Get-GameplayProfileValue $engine $_ '') }) -join '.'
    $engineHash = [string](Get-GameplayProfileValue $engine 'hash' '')
    $expectedEngineHash = ([string]$Expected.identity.engine_identity).Split('.')[-1]
    if ($Expected.identity.engine_identity -cne ($enginePrefix + '.' + $expectedEngineHash) -or $engineHash -cnotmatch '^[0-9a-f]{40}$' -or -not $engineHash.StartsWith($expectedEngineHash, [StringComparison]::Ordinal)) { $errors.Add('Runtime engine version differs from the canonical identity.') }
    if ((Get-GameplayProfileValue $Report 'display_server' '') -in @('', 'headless')) { $errors.Add('A native display is required.') }
    foreach ($entry in @(@('frame_limit', $Expected.frame_limit), @('case_seconds', $Expected.seconds), @('soak_seconds', $Expected.soak), @('observer_mode', $Expected.observer), @('campus_mode', $Expected.campus_mode), @('tick_rate', 120), @('protocol', $Expected.identity.protocol_version))) {
        if ((Get-GameplayProfileValue $Report $entry[0]) -cne $entry[1]) { $errors.Add("Runtime setting mismatch: $($entry[0])") }
    }
    if ((@(Get-GameplayProfileValue $Report 'profiles' @()) -join ',') -cne ($Expected.profiles -join ',')) { $errors.Add('Runtime quality profile order differs from the request.') }
    if ((@(Get-GameplayProfileValue $Report 'window_size' @()) -join ',') -cne (@($Expected.width, $Expected.height) -join ',')) { $errors.Add('Actual native window size differs from the requested bounds.') }
    if ((@(Get-GameplayProfileValue $Report 'window_size_end' @()) -join ',') -cne (@($Expected.width, $Expected.height) -join ',')) { $errors.Add('Final native window size differs from the requested bounds.') }
    $expectedRows = @(Get-GameplayProfileExpectedRows $Expected.profiles $Expected.cases $Expected.soak)
    $rows = @(Get-GameplayProfileValue $Report 'results' @())
    if ($rows.Count -ne $expectedRows.Count) { $errors.Add("Expected $($expectedRows.Count) exact startup/travel/warm rows, received $($rows.Count).") }
    for ($index = 0; $index -lt [Math]::Min($rows.Count, $expectedRows.Count); $index++) {
        $row = $rows[$index]
        $wanted = $expectedRows[$index]
        if ($waitForForeground) {
            $caseUtc = Get-GameplayProfileValue $row 'started_utc_msec'
            $caseMono = Get-GameplayProfileValue $row 'started_monotonic_usec'
            $gameUtc = Get-GameplayProfileValue $arming 'game_instantiation_started_utc_msec'
            $gameMono = Get-GameplayProfileValue $arming 'game_instantiation_started_monotonic_usec'
            if (-not (Test-MeasurementInteger $caseUtc) -or -not (Test-MeasurementInteger $caseMono) -or -not (Test-MeasurementInteger $gameUtc) -or -not (Test-MeasurementInteger $gameMono) -or $caseUtc -lt $gameUtc -or $caseMono -lt $gameMono) { $errors.Add("Result $index lacks an exact post-arm, post-instantiation measurement boundary.") }
            elseif ([Math]::Abs(($caseUtc - $gameUtc) - (($caseMono - $gameMono) / 1000.0)) -gt 250) { $errors.Add("Result $index has divergent UTC and monotonic clocks after arming.") }
        }
        foreach ($key in @('label', 'quality', 'temperature')) {
            if ((Get-GameplayProfileValue $row $key '') -cne $wanted.$key) { $errors.Add("Result $index has the wrong $key.") }
        }
        if ((Get-GameplayProfileValue $row 'ready' $false) -cne $true) { $errors.Add("Result $index did not reach actual area readiness.") }
        if ([string](Get-GameplayProfileValue $row 'garden_arrival_error' '') -cne '') { $errors.Add("Result $index reported a Garden arrival preparation failure.") }
        foreach ($sizeKey in @('window_size_before', 'window_size')) {
            if ((@(Get-GameplayProfileValue $row $sizeKey @()) -join ',') -cne (@($Expected.width, $Expected.height) -join ',')) { $errors.Add("Result $index has the wrong native viewport: $sizeKey.") }
        }
        if ((Get-GameplayProfileValue $row 'viewport_mismatch_frames' -1) -ne 0) { $errors.Add("Result $index observed a viewport change during measurement.") }
        if ((Get-GameplayProfileValue $row 'run_id' '') -cne (Get-GameplayProfileValue $Expected 'run_id' 'missing') -or (Get-GameplayProfileValue $row 'case_index' -1) -ne $index) { $errors.Add("Result $index has missing or inconsistent run/case metadata.") }
        foreach ($message in @(Get-GameplayProfileCampusErrors $row $Expected)) { $errors.Add("Result ${index}: $message") }
        if ((Get-GameplayProfileValue $row 'window_focus_before') -cne $true -or (Get-GameplayProfileValue $row 'window_focus_end') -cne $true -or (Get-GameplayProfileValue $row 'unfocused_frames' -1) -ne 0 -or (Get-GameplayProfileValue $row 'focus_sample_count' 0) -lt 1) { $errors.Add("Result $index did not maintain focus at every sampled process callback and both endpoints.") }
        $rowBudget = Get-GameplayProfileValue $row 'observation_limits'
        foreach ($message in @(Get-GameplayProfileBudgetErrors $rowBudget)) { $errors.Add("Result ${index}: $message") }
        $processCount = Get-GameplayProfileValue (Get-GameplayProfileValue $rowBudget 'case_counts') 'process' 0
        if ($processCount -ne (Get-GameplayProfileValue $row 'focus_sample_count' -1) -or $processCount -ne (Get-GameplayProfileValue (Get-GameplayProfileValue $row 'process_elapsed_ms') 'count' -1)) { $errors.Add("Result $index has inconsistent process/focus/budget sample counts.") }
        $workload = Get-GameplayProfileValue $row 'workload'
        if ((Get-GameplayProfileValue $workload 'phase' '') -cne $wanted.temperature -or (Get-GameplayProfileValue $workload 'resource_refill') -cne $false -or (Get-GameplayProfileValue $workload 'synthetic_commands') -cne $true -or -not (Get-GameplayProfileValue $workload 'map_id' '') -or (Get-GameplayProfileValue $workload 'tick_begin' -1) -lt 0 -or ((Get-GameplayProfileValue $workload 'tick_end' -1) - (Get-GameplayProfileValue $workload 'tick_begin' 0)) -ne (Get-GameplayProfileValue $row 'ticks_advanced' -1)) { $errors.Add("Result $index lacks a coherent workload/phase/tick witness.") }
        if ($wanted.temperature -cne 'warm') { continue }
        $samples = Get-GameplayProfileValue $row 'frame_interval_ms'
        if ((Get-GameplayProfileValue $samples 'count' 0) -lt 1 -or (Get-GameplayProfileValue $row 'ticks_advanced' 0) -lt 1) { $errors.Add("Warm result $index has no frame interval or simulation progress.") }
        if ($wanted.label -in @('paid_fire_bolt', 'paid_all_six_mantle', 'range_paid_fire', 'paid_fire_bolt_close', 'paid_fire_bolt_sustained', 'paid_all_six_mantle_sustained')) {
            if ((Get-GameplayProfileValue $row 'cast_attempts' 0) -lt 1 -or (Get-GameplayProfileValue $row 'matter_paid_delta' 0) -lt 1) { $errors.Add("Paid result $index has no actual payment witness.") }
        }
        if ($wanted.label -in @('paid_fire_bolt_sustained', 'paid_all_six_mantle_sustained')) {
            $fixture = Get-GameplayProfileValue $row 'fixture'
            if ((Get-GameplayProfileValue $fixture 'cast_interval_ticks' 0) -ne 120 -or (Get-GameplayProfileValue $fixture 'resource_refill' $true) -cne $false -or (Get-GameplayProfileValue $row 'admitted_casts_delta' 0) -lt 1) { $errors.Add("Sustained result $index lacks ordinary paid, unrefilled cadence evidence.") }
        }
        if ($wanted.label -ceq 'paid_fire_bolt_close') {
            $fixture = Get-GameplayProfileValue $row 'fixture'
            foreach ($entry in @(@('cast_attempts', 12), @('admitted_casts_delta', 12), @('refused_casts_delta', 0), @('matter_paid_delta', 7200))) {
                if ((Get-GameplayProfileValue $row $entry[0] -1) -ne $entry[1]) { $errors.Add("Close Fire result $index lacks the complete finite paid witness: $($entry[0]).") }
            }
            if ((Get-GameplayProfileValue $fixture 'finite_attempt_limit' 0) -ne 12 -or (Get-GameplayProfileValue $fixture 'spell_wire' 0) -ne 145 -or (Get-GameplayProfileValue $fixture 'target_distance_px' 0) -ne 200 -or (Get-GameplayProfileValue $fixture 'resource_refill' $true) -cne $false -or (@(Get-GameplayProfileValue $fixture 'target_world_px' @()) -join ',') -cne '1736,880' -or (@(Get-GameplayProfileValue $row 'position_before' @()) -join ',') -cne '1536,880') { $errors.Add("Close Fire result $index does not describe the actual near-target, unrefilled fixture.") }
            $attemptTicks = @(Get-GameplayProfileValue $row 'cast_attempt_ticks' @())
            if ($attemptTicks.Count -ne 12) { $errors.Add("Close Fire result $index lacks all twelve raw command ticks.") }
            for ($attempt = 1; $attempt -lt $attemptTicks.Count; $attempt++) {
                if ([long]$attemptTicks[$attempt] -le [long]$attemptTicks[$attempt - 1]) { $errors.Add("Close Fire result $index has unordered or duplicate command ticks.") }
            }
            if ($Expected.observer -ceq 'full') {
                $components = Get-GameplayProfileValue $row 'main_court_components_total_us'
                $observation = Get-GameplayProfileValue $row 'close_fire_observation'
                if ((Get-GameplayProfileValue $row 'max_paid_cells' 0) -lt 1 -or (Get-GameplayProfileValue $components 'bundle' 0) -le 0 -or (Get-GameplayProfileValue $components 'surface' 0) -le 0 -or (Get-GameplayProfileValue $observation 'accepted_prepared_regions' 0) -lt 1) { $errors.Add("Close Fire result $index never witnessed actual prepared visible paid material.") }
            }
        }
        if (Get-GameplayProfileValue $Expected 'screenshots' $false) {
            $shotPath = [string](Get-GameplayProfileValue $row 'screenshot' '')
            $wantedShot = Join-Path ([IO.Path]::GetDirectoryName($Expected.metrics_path)) ([IO.Path]::GetFileNameWithoutExtension($Expected.metrics_path) + '-' + $wanted.quality + '-' + $wanted.label + '.png')
            if ($shotPath.Replace('\', '/') -ine $wantedShot.Replace('\', '/') -or -not (Test-Path -LiteralPath $wantedShot -PathType Leaf) -or (Get-Item -LiteralPath $wantedShot).Length -le 8) { $errors.Add("Requested screenshot is absent or failed for warm result $index.") }
        }
    }
    return $errors.ToArray()
}

function Get-GameplayProfileViewportErrors($Report, $Expected) {
    $errors = [Collections.Generic.List[string]]::new()
    $requested = [bool](Get-GameplayProfileValue $Expected 'viewport_render_timing' $false)
    $header = Get-GameplayProfileValue $Report 'viewport_render_timing'
    if ((Get-GameplayProfileValue $header 'requested' $false) -cne $requested) { $errors.Add('Viewport timing mode differs from the explicit request.') }
    if ($requested) {
        if ($Expected.observer -cne 'full' -or (Get-GameplayProfileValue $header 'schema' '') -cne 'hex-viewport-render-timing-v1' -or (Get-GameplayProfileValue $header 'viewport_limit' -1) -ne 3 -or (Get-GameplayProfileValue $header 'reading_scope' '') -cne 'last_engine_reading_source_frame_unknown' -or (Get-GameplayProfileValue $header 'update_mode_scope' '') -cne 'rendering_server_pre_draw') { $errors.Add('Viewport timing lacks full-observer, bounded last-engine-reading and effective pre-draw policy provenance.') }
        $cleanup = Get-GameplayProfileValue $header 'cleanup'
        $counters = @{}
        foreach ($key in @('enabled_count', 'disabled_count', 'freed_before_cleanup_count', 'live_owned_count')) {
            $value = Get-GameplayProfileValue $cleanup $key
            if (-not (Test-MeasurementInteger $value)) { $errors.Add("Viewport cleanup lacks $key.") } else { $counters[$key] = [long]$value }
        }
        if ((Get-GameplayProfileValue $cleanup 'pre_draw_callback_connected') -cne $false -or $counters.Count -ne 4 -or $counters.live_owned_count -ne 0 -or $counters.enabled_count -lt 1 -or $counters.enabled_count -ne ($counters.disabled_count + $counters.freed_before_cleanup_count)) { $errors.Add('Viewport timing did not account for disabling every live owned target and callback.') }
    } elseif ($null -ne (Get-GameplayProfileValue $header 'cleanup')) { $errors.Add('Default profile cannot claim viewport timing instrumentation or cleanup.') }
    $roles = @('root', 'pov_main', 'pov_spare')
    foreach ($row in @(Get-GameplayProfileValue $Report 'results' @())) {
        $summary = Get-GameplayProfileValue $row 'viewport_render_timing'
        $raw = Get-GameplayProfileValue (Get-GameplayProfileValue $row 'raw') 'viewport_render_timing'
        if (-not $requested) {
            if ($null -ne $summary -or $null -ne $raw) { $errors.Add('Default profile must leave viewport timing unavailable.') }
            continue
        }
        $groups = @($raw)
        $budgetCount = Get-GameplayProfileValue (Get-GameplayProfileValue (Get-GameplayProfileValue $row 'observation_limits') 'case_counts') 'render_setup' -1
        $setupCount = @(Get-GameplayProfileValue (Get-GameplayProfileValue $row 'raw') 'engine_render_setup_cpu_ms' @()).Count
        if ($null -eq $raw -or $groups.Count -lt 1 -or $groups.Count -gt 12000 -or $groups.Count -ne $budgetCount -or $groups.Count -ne $setupCount -or (Get-GameplayProfileValue $summary 'group_count' -1) -ne $groups.Count -or (Get-GameplayProfileValue $summary 'viewport_limit' -1) -ne 3) { $errors.Add('Viewport raw groups must align with the bounded render_setup stream and summary.'); continue }
        foreach ($key in @('observer_pre_elapsed_us', 'observer_post_elapsed_us')) {
            if (-not (Test-MeasurementInteger (Get-GameplayProfileValue $summary $key))) { $errors.Add("Viewport observer lacks a finite $key total.") }
        }
        $previous = @{}
        $counts = @{}
        foreach ($role in $roles) { $counts[$role] = @{ absent = 0; inactive = 0; warmup_or_resumed = 0; last_engine_reading = 0; unavailable_after_pre_draw = 0 } }
        $lastFrame = -1L
        for ($groupIndex = 0; $groupIndex -lt $groups.Count; $groupIndex++) {
            $group = $groups[$groupIndex]
            $pre = Get-GameplayProfileValue $group 'pre_draw_process_frame'
            $post = Get-GameplayProfileValue $group 'observation_process_frame'
            if ((Get-GameplayProfileValue $group 'observation_serial' -1) -ne ($groupIndex + 1) -or -not (Test-MeasurementInteger $pre) -or -not (Test-MeasurementInteger $post) -or $post -lt $pre -or $pre -lt $lastFrame -or (Get-GameplayProfileValue $group 'source_frame_unknown') -cne $true) { $errors.Add('Viewport observations lack ordered callback provenance; observation frames are not timing source frames.') }
            if (Test-MeasurementInteger $post) { $lastFrame = [long]$post }
            $viewports = @(Get-GameplayProfileValue $group 'viewports' @())
            if ((($viewports | ForEach-Object { Get-GameplayProfileValue $_ 'role' '' }) -join ',') -cne ($roles -join ',')) { $errors.Add('Each viewport observation must contain exactly the three known ordered roles.'); continue }
            foreach ($view in $viewports) {
                $role = Get-GameplayProfileValue $view 'role' ''
                $status = Get-GameplayProfileValue $view 'status' ''
                $expectedUpdate = Get-GameplayProfileValue $view 'expected_update'
                $instance = Get-GameplayProfileValue $view 'instance_id'
                $mode = Get-GameplayProfileValue $view 'update_mode_before'
                $requestedMode = Get-GameplayProfileValue $view 'requested_node_update_mode' 'missing'
                if ($expectedUpdate -isnot [bool] -or (Get-GameplayProfileValue $view 'source_frame' 'missing') -cne $null -or -not $counts[$role].ContainsKey($status)) { $errors.Add('Viewport row has unknown status, source-frame claims or missing expected eligibility.'); continue }
                $counts[$role][$status]++
                if ($status -eq 'absent') {
                    if ($expectedUpdate -or $null -ne $instance -or $null -ne $mode -or $null -ne $requestedMode) { $errors.Add('Absent viewport cannot have a live target/update policy.') }
                } else {
                    if (-not (Test-MeasurementInteger $instance) -or $instance -le 0) { $errors.Add('A live pre-draw viewport needs a positive instance witness.') }
                    if ($role -eq 'root') {
                        if ($mode -cne 'visible_window' -or $null -ne $requestedMode) { $errors.Add('Root viewport must record its actual window policy.') }
                    } elseif (-not (Test-MeasurementInteger $mode) -or $mode -gt 4 -or -not (Test-MeasurementInteger $requestedMode) -or $requestedMode -gt 4 -or $expectedUpdate -ne ($mode -ne 0)) { $errors.Add('POV eligibility contradicts its effective pre-draw update mode or lacks its separate requested node policy.') }
                }
                $queried = $status -in @('warmup_or_resumed', 'last_engine_reading')
                if ($queried) {
                    $wasExpected = $previous.ContainsKey($role) -and $previous[$role].expected -and $previous[$role].instance -eq $instance
                    $wantedStatus = if ($wasExpected) { 'last_engine_reading' } else { 'warmup_or_resumed' }
                    if (-not $expectedUpdate -or $status -cne $wantedStatus) { $errors.Add('First, replaced or resumed viewport readings must retain their warmup/stale-risk label.') }
                } elseif (($status -eq 'inactive' -and $expectedUpdate) -or ($status -eq 'unavailable_after_pre_draw' -and -not $expectedUpdate)) { $errors.Add('Unqueried viewport status contradicts its eligibility.') }
                foreach ($key in @('cpu_last_engine_reading_ms', 'gpu_last_engine_reading_ms')) {
                    $value = Get-GameplayProfileValue $view $key 'missing'
                    if ($queried) {
                        if ($value -isnot [ValueType] -or $value -is [bool] -or [double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value) -or [double]$value -lt 0) { $errors.Add("Queried viewport lacks a finite raw $key; numeric zero remains a valid unqualified engine reading.") }
                    } elseif ($null -ne $value) { $errors.Add('Absent/inactive/unavailable viewport readings must be null, never stale copied values.') }
                }
                $previous[$role] = @{ expected = $expectedUpdate; instance = $instance }
            }
        }
        foreach ($role in $roles) {
            $roleSummary = Get-GameplayProfileValue (Get-GameplayProfileValue $summary 'roles') $role
            foreach ($status in $counts[$role].Keys) {
                if ((Get-GameplayProfileValue (Get-GameplayProfileValue $roleSummary 'status_counts') $status -1) -ne $counts[$role][$status]) { $errors.Add('Viewport summary status counts disagree with raw observations.') }
            }
            foreach ($pair in @(@('continuous', 'last_engine_reading'), @('warmup', 'warmup_or_resumed'))) {
                foreach ($kind in @('cpu', 'gpu')) {
                    if ((Get-GameplayProfileValue (Get-GameplayProfileValue $roleSummary ($pair[0] + '_' + $kind + '_last_engine_reading_ms')) 'count' -1) -ne $counts[$role][$pair[1]]) { $errors.Add('Viewport timing summary mixes warmup and continuous raw readings.') }
                }
            }
        }
    }
    return $errors.ToArray()
}

function Get-GameplayProfileCampusErrors($Row, $Expected) {
    $errors = [Collections.Generic.List[string]]::new()
    $mode = Get-GameplayProfileValue $Expected 'campus_mode' 'missing'
    if ((Get-GameplayProfileValue $Row 'campus_mode' '') -cne $mode -or $mode -notin @('retained', 'immediate_reference')) { $errors.Add('Campus renderer mode is absent or differs from the launched comparison.') }
    $endpoints = Get-GameplayProfileValue $Row 'retained_campus_endpoints'
    $names = @('ground', 'activity_arena', 'buildings', 'landmarks', 'stations', 'district_labels')
    foreach ($endpoint in @('before', 'after')) {
        $stats = Get-GameplayProfileValue $endpoints $endpoint
        $layers = Get-GameplayProfileValue $stats 'layers'
        $keys = if ($layers -is [Collections.IDictionary]) { @($layers.Keys) } elseif ($null -ne $layers) { @($layers.PSObject.Properties | ForEach-Object { $_.Name }) } else { @() }
        if ((Get-GameplayProfileValue $stats 'layer_count' -1) -ne 6 -or (($keys | Sort-Object) -join ',') -cne (($names | Sort-Object) -join ',')) { $errors.Add("Campus $endpoint lacks exactly the six ordered layer counters."); continue }
        foreach ($name in $names) {
            $layer = Get-GameplayProfileValue $layers $name
            foreach ($counter in @('requests', 'draws', 'draw_usec')) {
                $value = Get-GameplayProfileValue $layer $counter -1
                if ($value -isnot [ValueType] -or $value -is [bool] -or [double]::IsInfinity([double]$value) -or [double]::IsNaN([double]$value) -or [double]$value -lt 0 -or [double]$value -ne [Math]::Floor([double]$value)) { $errors.Add("Campus $endpoint/$name has an invalid $counter counter."); continue }
                if ($endpoint -eq 'after') {
                    $old = Get-GameplayProfileValue (Get-GameplayProfileValue (Get-GameplayProfileValue (Get-GameplayProfileValue $endpoints 'before') 'layers') $name) $counter -1
                    if ($old -isnot [ValueType] -or [double]$value -lt [double]$old) { $errors.Add("Campus $name/$counter counter regressed during a case.") }
                    if (($mode -eq 'immediate_reference' -or ($Expected.observer -eq 'light' -and $counter -eq 'draw_usec')) -and $value -ne $old) { $errors.Add("Campus $name/$counter reports work disabled by the selected mode.") }
                }
            }
        }
    }
    $prepare = Get-GameplayProfileValue $Row 'retained_campus_prepare'
    if ($Expected.observer -eq 'light') {
        if ($null -ne $prepare) { $errors.Add('Light observer must report campus preparation timing as unavailable.') }
    } else {
        foreach ($counter in @('calls', 'elapsed_us')) {
            $value = Get-GameplayProfileValue $prepare $counter -1
            if ($value -isnot [ValueType] -or $value -is [bool] -or [double]::IsInfinity([double]$value) -or [double]::IsNaN([double]$value) -or [double]$value -lt 0 -or [double]$value -ne [Math]::Floor([double]$value)) { $errors.Add("Campus preparation lacks a valid $counter total.") }
        }
    }
    return $errors.ToArray()
}

function Get-GameplayProfileBudgetErrors($Budget) {
    $errors = [Collections.Generic.List[string]]::new()
    if ((Get-GameplayProfileValue $Budget 'case_stream_limit' -1) -ne 12000 -or (Get-GameplayProfileValue $Budget 'run_group_limit' -1) -ne 120000 -or (Get-GameplayProfileValue $Budget 'overflow') -cne $false -or (Get-GameplayProfileValue $Budget 'overflow_stream' 'missing') -cne '') { $errors.Add('Observer limits are absent, changed or exhausted; partial measurements cannot be admitted.') }
    $streams = @('process', 'draw', 'court', 'campus', 'garden', 'garden_step', 'terrain', 'pov', 'render_setup', 'cast_attempt')
    $runTotal = 0L
    foreach ($group in @('case_counts', 'run_counts')) {
        $counts = Get-GameplayProfileValue $Budget $group
        if ($null -eq $counts) { $errors.Add("Observer budget lacks $group."); continue }
        $keys = if ($counts -is [Collections.IDictionary]) { @($counts.Keys) } else { @($counts.PSObject.Properties | ForEach-Object { $_.Name }) }
        foreach ($key in $keys) {
            $value = Get-GameplayProfileValue $counts $key -1
            if ($key -cnotin $streams -or $value -isnot [ValueType] -or $value -lt 0 -or $value -ne [long]$value -or ($group -eq 'case_counts' -and $value -gt 12000) -or ($group -eq 'run_counts' -and $value -gt 120000)) { $errors.Add("Invalid observer record count: $group/$key"); continue }
            if ($group -eq 'run_counts') { $runTotal += [long]$value }
            elseif ($value -gt (Get-GameplayProfileValue (Get-GameplayProfileValue $Budget 'run_counts') $key -1)) { $errors.Add("Case observer count exceeds the run count: $key") }
        }
    }
    if ($runTotal -lt 1 -or $runTotal -gt 120000 -or $runTotal -ne (Get-GameplayProfileValue $Budget 'run_groups' -1)) { $errors.Add('Observer total is missing, inconsistent or above the run bound.') }
    return $errors.ToArray()
}

function Get-GameplayProfileCompactReport($Report) {
    if ($null -eq $Report) { return $null }
    $compact = [ordered]@{}
    foreach ($property in $Report.PSObject.Properties) {
        if ($property.Name -eq 'results') {
            $rows = [Collections.Generic.List[object]]::new()
            foreach ($row in $property.Value) {
                $small = [ordered]@{}
                foreach ($field in $row.PSObject.Properties) { if ($field.Name -cne 'raw') { $small[$field.Name] = $field.Value } }
                $rows.Add($small)
            }
            $compact[$property.Name] = $rows.ToArray()
        } elseif ($property.Name -in @('observed_source_before', 'observed_source_after')) {
            $snapshot = [ordered]@{}
            foreach ($field in $property.Value.PSObject.Properties) { if ($field.Name -cne 'files') { $snapshot[$field.Name] = $field.Value } }
            $compact[$property.Name] = $snapshot
        } else { $compact[$property.Name] = $property.Value }
    }
    return $compact
}

$profileRoot = Get-FluxRepoRoot
if ($LightObserver -and $ViewportRenderTiming) { throw 'ViewportRenderTiming requires the full observer; omit LightObserver.' }
# PowerShell ValidateSet is case-insensitive; the GDScript CLI is not.
$Profiles = @($Profiles | ForEach-Object { $_.ToLowerInvariant() })
$Cases = @($Cases | ForEach-Object { $_.ToLowerInvariant() })
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory = Join-Path $profileRoot $OutputDirectory }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a fresh benchmark output directory; existing evidence is never overwritten.' }
if ($Profiles.Count -eq 0 -or @($Profiles | Select-Object -Unique).Count -ne $Profiles.Count -or $Cases.Count -eq 0 -or @($Cases | Select-Object -Unique).Count -ne $Cases.Count) { throw 'Select nonempty profiles and cases without duplicates.' }
if (-not [double]::IsFinite($SecondsPerCase) -or -not [double]::IsFinite($SoakSeconds)) { throw 'Diagnostic durations must be finite.' }
$minimumSeconds = $Profiles.Count * ($Cases.Count * ($SecondsPerCase + 1) + $(if ($SoakSeconds -gt 0) { $SoakSeconds + 1 } else { 0 }))
if ($WaitForForeground) { $minimumSeconds += 300 }
if ($minimumSeconds -ge $TimeoutSeconds) { throw "Requested case/soak durations and one-second warmups need at least $minimumSeconds seconds, before extra startup/preparation; choose a smaller matrix or larger watchdog (maximum1800)." }
$profileScript = Join-Path $profileRoot 'scripts/profile-gameplay.gd'
$profileIdentityScript = Join-Path $profileRoot 'scripts/runtime-build-identity.ps1'
$profileManifestPath = Join-Path $profileRoot 'content/runtime/runtime_build_identity_v1.json'
$profileProject = Get-Content -Raw -LiteralPath (Join-Path $profileRoot 'project.godot')
if ($profileProject -notmatch '(?m)^config/use_custom_user_dir=true\s*$' -or $profileProject -notmatch '(?m)^config/custom_user_dir_name="Godot/app_userdata/FLUX 2"\s*$') { throw 'Review the exact engine user-data contract before running this benchmark.' }
$profileEngine = Get-FluxGodot
$profileLease = Enter-FluxEngineRun 'profile-native-gameplay'
$profileHadAppData = Test-Path Env:APPDATA
$profileSavedAppData = $env:APPDATA
$profileErrors = [Collections.Generic.List[string]]::new()
$profileReport = $null
$profileRunId = [Guid]::NewGuid().ToString('D')
$profileWindowObservations = [Collections.Generic.List[object]]::new()
$profileWindowActivations = [Collections.Generic.List[object]]::new()
$profilePresentTools = Get-MeasurementPresentToolAvailability
$profileIdentityBefore = $null
$profileIdentityAfter = $null
$profileBefore = [ordered]@{}
$profileAfter = [ordered]@{}
$profileMemoryBefore = Get-GameplayProfileMemory
$profileWatch = [Diagnostics.Stopwatch]::StartNew()
$profileArguments = @()
$profileMetricsPath = Join-Path $OutputDirectory 'metrics.json'
$profileLogPath = Join-Path $OutputDirectory 'engine.log'
try {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $profileIdentityBefore = (& $profileIdentityScript -Mode Check -Json | Out-String) | ConvertFrom-Json -ErrorAction Stop
    foreach ($path in @($profileScript, $PSCommandPath, $profileIdentityScript, (Join-Path $PSScriptRoot 'flux2-common.ps1'), (Join-Path $PSScriptRoot 'engine-guard.ps1'), (Join-Path $PSScriptRoot 'measurement-observation.ps1'), $profileManifestPath)) { $profileBefore[$path] = Get-FluxFileSha256 $path }
    Copy-Item -LiteralPath $profileManifestPath -Destination (Join-Path $OutputDirectory 'runtime-identity.input.json')
    $env:APPDATA = Join-Path $OutputDirectory 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $profileExpectedUserData = Join-Path $env:APPDATA 'Godot/app_userdata/FLUX 2'
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $profileArguments = @('--path', $profileRoot, '--script', 'res://scripts/profile-gameplay.gd', '--windowed', '--resolution', "${Width}x${Height}", '--', '--no-lan-discovery', '--fullbody-art', '--pixel-cast', "--profile-output=$profileMetricsPath", "--profile-user-data=$profileExpectedUserData", ('--profile-seconds=' + $SecondsPerCase.ToString('R', $culture)), ('--profile-soak-seconds=' + $SoakSeconds.ToString('R', $culture)), ('--profile-profiles=' + ($Profiles -join ',')), ('--profile-cases=' + ($Cases -join ',')), "--profile-frame-limit=$FrameLimit", "--profile-width=$Width", "--profile-height=$Height")
    $profileArguments += "--profile-run-id=$profileRunId"
    if ($RequestForegroundOnce) { $profileArguments += '--profile-external-foreground-request' }
    if ($WaitForForeground) { $profileArguments += '--profile-wait-for-foreground' }
    if ($LightObserver) { $profileArguments += '--profile-light-observer' }
    if ($ViewportRenderTiming) { $profileArguments += '--profile-viewport-render-timing' }
    if ($ReferenceCampus) { $profileArguments += '--reference-campus' }
    else { $profileArguments += '--retained-campus' }
    if ($Screenshots) { $profileArguments += '--profile-screenshots' }
    Push-Location -LiteralPath $profileRoot
    try { Invoke-FluxGodotChecked $profileEngine $profileArguments $profileLogPath -RejectWarnings -TimeoutSeconds $TimeoutSeconds -VisibleWindow -WindowObservations $profileWindowObservations -RequestForegroundOnce:$RequestForegroundOnce -WindowActivationRequests $profileWindowActivations | Out-Null }
    catch { $profileErrors.Add($_.Exception.Message) }
    finally { Pop-Location }
    if (-not (Test-Path -LiteralPath $profileMetricsPath -PathType Leaf)) {
        $profileErrors.Add('Complete metrics.json is missing; any partial report remains unqualified evidence.')
        if (Test-Path -LiteralPath "$profileMetricsPath.partial.json" -PathType Leaf) { $profileReport = Get-Content -Raw -LiteralPath "$profileMetricsPath.partial.json" | ConvertFrom-Json -ErrorAction Stop }
    }
    else {
        $profileReport = Get-Content -Raw -LiteralPath $profileMetricsPath | ConvertFrom-Json -ErrorAction Stop
        $expected = @{ profiles = $Profiles; cases = $Cases; seconds = $SecondsPerCase; soak = $SoakSeconds; frame_limit = $FrameLimit; width = $Width; height = $Height; observer = $(if ($LightObserver) { 'light' } else { 'full' }); identity = $profileIdentityBefore; engine = $profileEngine; user_data = $profileExpectedUserData; script_sha256 = $profileBefore[$profileScript]; screenshots = [bool]$Screenshots; metrics_path = $profileMetricsPath }
        $expected['run_id'] = $profileRunId
        $expected['campus_mode'] = $(if ($ReferenceCampus) { 'immediate_reference' } else { 'retained' })
        $expected['wait_for_foreground'] = [bool]$WaitForForeground
        $expected['viewport_render_timing'] = [bool]$ViewportRenderTiming
        foreach ($message in @(Get-GameplayProfileReportErrors $profileReport $expected)) { $profileErrors.Add($message) }
    }
    $completeLines = @(if (Test-Path -LiteralPath $profileLogPath) { Get-Content -LiteralPath $profileLogPath | Where-Object { $_ -ceq "HEX_GAMEPLAY_PROFILE_COMPLETE $profileMetricsPath" -or $_ -ceq ('HEX_GAMEPLAY_PROFILE_COMPLETE ' + $profileMetricsPath.Replace('\', '/')) } })
    if ($completeLines.Count -ne 1) { $profileErrors.Add('Expected exactly one matching complete-report marker in the native log.') }
    $armLines = @(if (Test-Path -LiteralPath $profileLogPath) { Get-Content -LiteralPath $profileLogPath | Where-Object { $_.StartsWith('HEX_GAMEPLAY_PROFILE_ARMED ', [StringComparison]::Ordinal) } })
    $armUtc = Get-MeasurementValue (Get-GameplayProfileValue $profileReport 'foreground_arming') 'armed_utc_msec'
    if ($WaitForForeground) {
        if ($armLines.Count -ne 1 -or $armLines[0] -cne "HEX_GAMEPLAY_PROFILE_ARMED $profileRunId $armUtc") { $profileErrors.Add('Manual measurement requires exactly one matching run/UTC arming marker.') }
    } elseif ($armLines.Count -ne 0) { $profileErrors.Add('Default measurement unexpectedly emitted a foreground arming marker.') }
    $stderrPath = "$profileLogPath.err"
    if (-not (Test-Path -LiteralPath $stderrPath) -or (Get-Item -LiteralPath $stderrPath).Length -ne 0) { $profileErrors.Add('Native stderr is missing or nonempty; inspect the preserved log.') }
    $profileIdentityAfter = (& $profileIdentityScript -Mode Check -Json | Out-String) | ConvertFrom-Json -ErrorAction Stop
    if ($profileIdentityBefore.runtime_source_sha256 -cne $profileIdentityAfter.runtime_source_sha256 -or $profileIdentityBefore.build_id -cne $profileIdentityAfter.build_id) { $profileErrors.Add('Canonical runtime identity changed during the benchmark.') }
} catch { $profileErrors.Add($_.Exception.Message) }
finally {
    $profileWatch.Stop()
    if ($profileHadAppData) { $env:APPDATA = $profileSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    foreach ($path in $profileBefore.Keys) {
        try {
            $profileAfter[$path] = Get-FluxFileSha256 $path
            if ($profileAfter[$path] -cne $profileBefore[$path]) { $profileErrors.Add("Qualification input changed: $path") }
        } catch { $profileErrors.Add($_.Exception.Message) }
    }
    Exit-FluxEngineRun $profileLease
}
$profileMemoryAfter = Get-GameplayProfileMemory
$profileArmedAssessment = Get-MeasurementArmedWindowAssessment $profileWindowObservations.ToArray() $Width $Height (Get-GameplayProfileValue $profileReport 'foreground_arming') ([bool]$WaitForForeground)
$profileWindowAssessment = $profileArmedAssessment.measurement_assessment
foreach ($message in $profileArmedAssessment.errors) { $profileErrors.Add($message) }
foreach ($message in @(Get-MeasurementActivationErrors ([bool]$RequestForegroundOnce) $profileWindowActivations.ToArray() $profileWindowObservations.ToArray())) { $profileErrors.Add($message) }
$profileAppDataRestored = (Test-Path Env:APPDATA) -eq $profileHadAppData -and (-not $profileHadAppData -or $env:APPDATA -ceq $profileSavedAppData)
if (-not $profileAppDataRestored) { $profileErrors.Add('APPDATA restoration did not match its exact initial existence/value.') }
$profileSummary = [ordered]@{
    schema = 'hex-native-profile-wrapper-v1'; run_id = $profileRunId; status = $(if ($profileErrors.Count -eq 0) { 'measured' } else { 'incomplete_or_failed' })
    scope = 'Instrumented native source runtime, not portable-release FPS acceptance or physical presentation/input latency. Cold rows mean this game process cache, not full process launch latency or a flushed OS cache; optional foreground waiting and source hashing precede game instantiation and are retained separately from measured cases. Warm and travel rows stay separate. No source/package/promotion edits; engine preferences live only in the isolated profile. The shared checked-engine runner validates process results, but does not expose a numeric exit code when Windows leaves it unavailable.'
    numeric_process_exit_code = $null; exit_code_scope = 'Not exposed by the shared checked-engine runner; clean launcher return, exact completion marker, complete receipt and empty stderr are required.'
    appdata_restored = $profileAppDataRestored
    requested = [ordered]@{ profiles = $Profiles; cases = $Cases; seconds_per_case = $SecondsPerCase; soak_seconds = $SoakSeconds; frame_limit = $FrameLimit; width = $Width; height = $Height; observer_mode = $(if ($LightObserver) { 'light' } else { 'full' }); viewport_render_timing = [bool]$ViewportRenderTiming; campus_mode = $(if ($ReferenceCampus) { 'immediate_reference' } else { 'retained' }); screenshots = [bool]$Screenshots; timeout_seconds = $TimeoutSeconds }
    output_directory = $OutputDirectory; engine = $profileEngine; arguments = $profileArguments; wall_seconds = $profileWatch.Elapsed.TotalSeconds
    available_memory_before = $profileMemoryBefore; available_memory_after = $profileMemoryAfter
    window_observations = $profileWindowObservations.ToArray(); window_assessment = $profileWindowAssessment; frame_present_tool_availability = $profilePresentTools
    foreground_request_opt_in = [bool]$RequestForegroundOnce; window_activation_requests = $profileWindowActivations.ToArray()
    wait_for_foreground_opt_in = [bool]$WaitForForeground; foreground_arming_assessment = $profileArmedAssessment
    runtime_identity_before = $profileIdentityBefore; runtime_identity_after = $profileIdentityAfter; input_hashes_before = $profileBefore; input_hashes_after = $profileAfter
    raw_metrics_path = $profileMetricsPath; native_log_path = $profileLogPath; metrics_sha256 = $(if (Test-Path -LiteralPath $profileMetricsPath -PathType Leaf) { Get-FluxFileSha256 $profileMetricsPath } else { $null })
    validation_errors = $profileErrors.ToArray(); benchmark = Get-GameplayProfileCompactReport $profileReport
}
if (Test-Path -LiteralPath $OutputDirectory -PathType Container) { Write-GameplayProfileReceipt (Join-Path $OutputDirectory 'summary.json') $profileSummary }
if ($profileErrors.Count -gt 0) { throw "Native profile is incomplete or failed; inspect $OutputDirectory" }
Write-Output "MEASURED: native diagnostic and compact summary retained at $OutputDirectory"
