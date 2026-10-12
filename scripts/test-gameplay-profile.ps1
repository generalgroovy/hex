# Pure receipt-admission regressions. No engine, file write, import or export.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'measurement-observation.ps1')
$profileValidatorPath = Join-Path $PSScriptRoot 'profile-gameplay.ps1'
$profileTokens = $null
$profileParseErrors = $null
$profileAst = [Management.Automation.Language.Parser]::ParseFile($profileValidatorPath, [ref]$profileTokens, [ref]$profileParseErrors)
if ($profileParseErrors.Count -gt 0) { throw ($profileParseErrors | Out-String) }
foreach ($name in @('Get-GameplayProfileValue', 'Get-GameplayProfileExpectedRows', 'Get-GameplayProfileReportErrors', 'Get-GameplayProfileBudgetErrors', 'Get-GameplayProfileCampusErrors', 'Get-GameplayProfileViewportErrors')) {
    $definitions = @($profileAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true))
    if ($definitions.Count -ne 1) { throw "Expected one profile validator function $name" }
    Invoke-Expression $definitions[0].Extent.Text
}
$assertions = 0
function Check-Profile([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Copy-Profile($Value) { return $Value | ConvertTo-Json -Depth 32 | ConvertFrom-Json }
$identity = [pscustomobject]@{ build_id = 'fixture'; runtime_source_sha256 = 'a' * 64; engine_identity = '4.7.1.stable.official.a13da4feb'; protocol_version = 60; snapshot_schema = 24; record_count = 1 }
$expected = [pscustomobject]@{ width = 1290; height = 730; frame_limit = 60; seconds = 60; soak = 0; observer = 'full'; profiles = @('low'); cases = @('paid_fire_bolt_sustained'); script_sha256 = 'b' * 64; identity = $identity; user_data = 'C:/isolated/data'; engine = 'C:/engine/godot.exe'; screenshots = $false }
$rows = @(
    [pscustomobject]@{ label = 'startup_arrival'; quality = 'low'; temperature = 'cold_process_cache'; ready = $true; window_size_before = @(1290, 730); window_size = @(1290, 730); viewport_mismatch_frames = 0 },
    [pscustomobject]@{ label = 'paid_fire_bolt_sustained'; quality = 'low'; temperature = 'warm'; ready = $true; window_size_before = @(1290, 730); window_size = @(1290, 730); viewport_mismatch_frames = 0; frame_interval_ms = @{ count = 100 }; ticks_advanced = 7200; cast_attempts = 60; admitted_casts_delta = 12; matter_paid_delta = 7200; fixture = @{ cast_interval_ticks = 120; resource_refill = $false } }
)
$report = [pscustomobject]@{
    schema = 'hex-gameplay-profile-v1'; complete = $true; observed_source_before = @{ ok = $true; sha256 = 'c' * 64 }; observed_source_after = @{ ok = $true; sha256 = 'c' * 64 }; observed_source_unchanged = $true
    profile_script_sha256 = 'b' * 64; manifest = $identity; user_data = $expected.user_data; executable = $expected.engine
    engine = @{ major = 4; minor = 7; patch = 1; status = 'stable'; build = 'official'; hash = 'a13da4feb' + ('0' * 31) }; display_server = 'windows'
    frame_limit = 60; case_seconds = 60; soak_seconds = 0; observer_mode = 'full'; tick_rate = 120; protocol = 60; profiles = @('low'); window_size = @(1290, 730); window_size_end = @(1290, 730); results = $rows
}
$expected | Add-Member -NotePropertyName run_id -NotePropertyValue 'fixture-run'
$expected | Add-Member -NotePropertyName campus_mode -NotePropertyValue 'retained'
$report | Add-Member -NotePropertyName campus_mode -NotePropertyValue 'retained'
$report | Add-Member -NotePropertyName foreground_arming -NotePropertyValue @{ schema = 'hex-foreground-arming-v1'; requested = $false; armed = $false; armed_utc_msec = $null }
$campusStats = @{ layer_count = 6; visible = $true; layers = @{} }
foreach ($name in @('ground', 'activity_arena', 'buildings', 'landmarks', 'stations', 'district_labels')) { $campusStats.layers[$name] = @{ requests = 2; draws = 2; draw_usec = 100 } }
$validBudget = @{ case_stream_limit = 12000; run_group_limit = 120000; overflow = $false; overflow_stream = ''; case_counts = @{ process = 101 }; run_counts = @{ process = 202 }; run_groups = 202 }
$report | Add-Member -NotePropertyName run_id -NotePropertyValue 'fixture-run'
$report | Add-Member -NotePropertyName observation_limits -NotePropertyValue $validBudget
for ($index = 0; $index -lt $rows.Count; $index++) {
    $rows[$index] | Add-Member -NotePropertyMembers @{ run_id = 'fixture-run'; case_index = $index; observation_limits = $validBudget; window_focus_before = $true; window_focus_end = $true; focus_sample_count = 101; unfocused_frames = 0; process_elapsed_ms = @{ count = 101 }; workload = @{ phase = $rows[$index].temperature; map_id = 'fixture-map'; tick_begin = 0; tick_end = 7200; resource_refill = $false; synthetic_commands = $true } }
    $rows[$index] | Add-Member -NotePropertyMembers @{ campus_mode = 'retained'; retained_campus_endpoints = @{ before = (Copy-Profile $campusStats); after = (Copy-Profile $campusStats) }; retained_campus_prepare = @{ calls = 101; elapsed_us = 1234 } }
    if ($index -eq 0) { $rows[$index] | Add-Member -NotePropertyName ticks_advanced -NotePropertyValue 7200 }
}
Check-Profile (@(Get-GameplayProfileReportErrors $report $expected).Count -eq 0) 'Matched native bounds and ordinary sustained payment admit'
foreach ($index in @(0, 1)) {
    $bad = Copy-Profile $report
    $bad.results[$index] | Add-Member -NotePropertyName garden_arrival_error -NotePropertyValue 'fixture preparation failure'
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) "Every cold/warm row rejects a Garden preparation failure: $index"
}
foreach ($key in @('window_size_before', 'window_size')) {
    foreach ($index in @(0, 1)) {
        $bad = Copy-Profile $report
        $bad.results[$index].$key = @(1300, 740)
        Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) "Every cold/warm viewport boundary is checked: $index/$key"
    }
}
$bad = Copy-Profile $report
$bad.results[1].viewport_mismatch_frames = 1
Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) 'Transient resize fails even when both endpoint sizes match'
$bad = Copy-Profile $report
$bad.window_size_end = @(1300, 740)
Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) 'Report completion cannot hide a final viewport drift'
foreach ($mutation in @('refill', 'cadence', 'unpaid', 'unadmitted')) {
    $bad = Copy-Profile $report
    switch ($mutation) {
        'refill' { $bad.results[1].fixture.resource_refill = $true }
        'cadence' { $bad.results[1].fixture.cast_interval_ticks = 0 }
        'unpaid' { $bad.results[1].matter_paid_delta = 0 }
        'unadmitted' { $bad.results[1].admitted_casts_delta = 0 }
    }
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) "Sustained fixture rejects missing ordinary payment evidence: $mutation"
}
$bad = Copy-Profile $report
$bad.observed_source_after.sha256 = 'd' * 64
Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) 'Source changes invalidate an otherwise complete profile'
foreach ($mutation in @('unfocused', 'focus_boundary', 'missing_focus', 'mismatched_count', 'overflow', 'case_limit', 'run_limit', 'unknown_stream', 'negative_count', 'fractional_count', 'wrong_total', 'wrong_run', 'wrong_case_order', 'wrong_tick_witness', 'missing_workload')) {
    $bad = Copy-Profile $report
    switch ($mutation) {
        'unfocused' { $bad.results[1].unfocused_frames = 1 }
        'focus_boundary' { $bad.results[0].window_focus_before = $false }
        'missing_focus' { $bad.results[1].PSObject.Properties.Remove('focus_sample_count') }
        'mismatched_count' { $bad.results[1].process_elapsed_ms.count = 100 }
        'overflow' { $bad.results[1].observation_limits.overflow = $true }
        'case_limit' { $bad.results[1].observation_limits.case_counts.process = 12001 }
        'run_limit' { $bad.observation_limits.run_counts.process = 120001; $bad.observation_limits.run_groups = 120001 }
        'unknown_stream' { $bad.observation_limits.case_counts | Add-Member -NotePropertyName 'anything' -NotePropertyValue 1 }
        'negative_count' { $bad.results[1].observation_limits.case_counts.process = -1 }
        'fractional_count' { $bad.results[1].observation_limits.case_counts.process = 1.5 }
        'wrong_total' { $bad.observation_limits.run_groups = 201 }
        'wrong_run' { $bad.results[1].run_id = 'another-run' }
        'wrong_case_order' { $bad.results[1].case_index = 0 }
        'wrong_tick_witness' { $bad.results[1].workload.tick_end = 7199 }
        'missing_workload' { $bad.results[1].PSObject.Properties.Remove('workload') }
    }
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) "Incomplete focus, workload or bounded-observer evidence fails: $mutation"
}
$light = Copy-Profile $report
$lightExpected = Copy-Profile $expected
$light.observer_mode = 'light'
$lightExpected.observer = 'light'
foreach ($row in $light.results) { $row.retained_campus_prepare = $null }
Check-Profile (@(Get-GameplayProfileReportErrors $light $lightExpected).Count -eq 0) 'Light observer retains the same focus, payment and bounded-storage admission rules.'
foreach ($mutation in @('mode', 'row_mode', 'missing_layer', 'extra_layer', 'negative', 'backward', 'missing_prepare')) {
    $bad = Copy-Profile $report
    switch ($mutation) {
        'mode' { $bad.campus_mode = 'immediate_reference' }
        'row_mode' { $bad.results[1].campus_mode = 'immediate_reference' }
        'missing_layer' { $bad.results[1].retained_campus_endpoints.after.layers.PSObject.Properties.Remove('ground') }
        'extra_layer' { $bad.results[1].retained_campus_endpoints.after.layers | Add-Member -NotePropertyName 'other' -NotePropertyValue @{} }
        'negative' { $bad.results[1].retained_campus_endpoints.after.layers.ground.requests = -1 }
        'backward' { $bad.results[1].retained_campus_endpoints.after.layers.ground.draws = 1 }
        'missing_prepare' { $bad.results[1].retained_campus_prepare = $null }
    }
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) "Campus comparison rejects incomplete or inconsistent evidence: $mutation"
}
$bad = Copy-Profile $light
$bad.results[1].retained_campus_endpoints.after.layers.ground.draw_usec = 101
Check-Profile (@(Get-GameplayProfileReportErrors $bad $lightExpected).Count -gt 0) 'Light mode cannot conceal an active retained child timer.'
$reference = Copy-Profile $report
$referenceExpected = Copy-Profile $expected
$reference.campus_mode = 'immediate_reference'
$referenceExpected.campus_mode = 'immediate_reference'
foreach ($row in $reference.results) { $row.campus_mode = 'immediate_reference' }
Check-Profile (@(Get-GameplayProfileReportErrors $reference $referenceExpected).Count -eq 0) 'Immediate comparison retains zero-delta child counters and the same independent admission gates.'
$reference.results[1].retained_campus_endpoints.after.layers.landmarks.draws = 3
Check-Profile (@(Get-GameplayProfileReportErrors $reference $referenceExpected).Count -gt 0) 'Reference path cannot silently draw candidate child layers.'
foreach ($value in @([double]::PositiveInfinity, [double]::NaN)) {
    $bad = Copy-Profile $report
    $bad.results[1].retained_campus_endpoints.after.layers.ground.draw_usec = $value
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) 'Nonfinite imported retained counters cannot qualify.'
    $bad = Copy-Profile $report
    $bad.results[1].retained_campus_prepare.elapsed_us = $value
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $expected).Count -gt 0) 'Nonfinite imported preparation time cannot qualify.'
}
$armedReport = Copy-Profile $report
$armedExpected = Copy-Profile $expected
$armedExpected | Add-Member -NotePropertyName wait_for_foreground -NotePropertyValue $true
$armedReport.foreground_arming = @{
    schema = 'hex-foreground-arming-v1'; requested = $true; armed = $true
    deadline_ms = 300000; stable_focus_required_ms = 1000; maximum_poll_gap_ms = 250
    setup_started_utc_msec = 100000L; setup_started_monotonic_usec = 1000000L
    manual_confirmation_received = $true; manual_confirmation_phase = 'setup'; manual_confirmation_kind = 'start_button_pressed'
    manual_confirmation_utc_msec = 101000L; manual_confirmation_monotonic_usec = 2000000L
    armed_utc_msec = 102000L; armed_monotonic_usec = 3000000L; wait_elapsed_ms = 2000L
    stable_focus_elapsed_ms = 1000L; stable_focus_samples = 61
    game_instantiation_started_utc_msec = 102100L; game_instantiation_started_monotonic_usec = 3100000L
    setup_focus_observations = @(for ($i = 0; $i -le 20; $i++) { @{ phase = 'setup'; elapsed_ms = $i * 100; focused = $i -ge 10; eligible = $i -ge 10 } })
    post_arm_focus = @{ samples = 120; unfocused_samples = 0; focus_exit_events = 0 }
}
foreach ($row in $armedReport.results) { $row | Add-Member -NotePropertyMembers @{ started_utc_msec = 104000L; started_monotonic_usec = 5000000L } }
Check-Profile (@(Get-GameplayProfileReportErrors $armedReport $armedExpected).Count -eq 0) 'Wrapper admits only explicit pre-instantiation arming with coherent later case clocks.'
foreach ($mutation in @('unrequested', 'missing_arming', 'case_prearm', 'case_preinstantiation', 'missing_case_clock', 'case_clock_jump', 'between_case_focus_loss')) {
    $bad = Copy-Profile $armedReport
    $badExpected = Copy-Profile $armedExpected
    switch ($mutation) {
        'unrequested' { $badExpected.wait_for_foreground = $false }
        'missing_arming' { $bad.PSObject.Properties.Remove('foreground_arming') }
        'case_prearm' { $bad.results[0].started_utc_msec = 101999; $bad.results[0].started_monotonic_usec = 2999000 }
        'case_preinstantiation' { $bad.results[0].started_utc_msec = 102001; $bad.results[0].started_monotonic_usec = 3001000 }
        'missing_case_clock' { $bad.results[1].PSObject.Properties.Remove('started_monotonic_usec') }
        'case_clock_jump' { $bad.results[1].started_utc_msec += 251 }
        'between_case_focus_loss' { $bad.foreground_arming.post_arm_focus.focus_exit_events = 1 }
    }
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $badExpected).Count -gt 0) "Explicit arming cannot weaken wrapper-to-case boundaries: $mutation"
}
# Optional viewport timings are last-engine readings, never a current-frame sum.
# Exercise zero versus unavailable, UPDATE_ONCE captured before disable, idle
# gaps, replacement, aligned record bounds and exact cleanup accounting.
function New-ProfileViewportRow([string]$Role, [string]$Status, $Instance, $Mode) {
    $queried = $Status -in @('warmup_or_resumed', 'last_engine_reading')
    return @{ role = $Role; status = $Status; instance_id = $Instance; update_mode_before = $Mode; requested_node_update_mode = $(if ($Role -ne 'root') { $Mode } else { $null }); expected_update = $queried
        source_frame = $null; cpu_last_engine_reading_ms = $(if ($queried) { 0.125 } else { $null }); gpu_last_engine_reading_ms = $(if ($queried) { 0.0 } else { $null }) }
}
$viewportReport = Copy-Profile $report
$viewportExpected = Copy-Profile $expected
$viewportExpected | Add-Member -NotePropertyName viewport_render_timing -NotePropertyValue $true
$viewportReport | Add-Member -NotePropertyName viewport_render_timing -NotePropertyValue @{
    schema = 'hex-viewport-render-timing-v1'; requested = $true; viewport_limit = 3; reading_scope = 'last_engine_reading_source_frame_unknown'; update_mode_scope = 'rendering_server_pre_draw'
    cleanup = @{ enabled_count = 4; disabled_count = 3; freed_before_cleanup_count = 1; live_owned_count = 0; pre_draw_callback_connected = $false }
}
$viewportGroups = @(for ($index = 0; $index -lt 6; $index++) {
    $rootRow = New-ProfileViewportRow 'root' $(if ($index -in @(0, 5)) { 'warmup_or_resumed' } else { 'last_engine_reading' }) $(if ($index -eq 5) { 11 } else { 10 }) 'visible_window'
    $mainRow = switch ($index) {
        { $_ -in @(0, 2) } { New-ProfileViewportRow 'pov_main' 'inactive' 20 0; break }
        { $_ -in @(1, 3) } { New-ProfileViewportRow 'pov_main' 'warmup_or_resumed' 20 1; break }
        default { New-ProfileViewportRow 'pov_main' 'last_engine_reading' 20 4 }
    }
    $spareRow = if ($index -lt 3) { New-ProfileViewportRow 'pov_spare' 'absent' $null $null } elseif ($index -eq 4) { New-ProfileViewportRow 'pov_spare' 'inactive' 30 0 } else { New-ProfileViewportRow 'pov_spare' 'warmup_or_resumed' 30 1 }
    # An already consumed ONCE request remains cached on SubViewport. Only the
    # separately observed server DISABLED policy prevents a stale timing query.
    if ($index -eq 2) { $mainRow.requested_node_update_mode = 1 }
    if ($index -eq 4) { $spareRow.requested_node_update_mode = 1 }
    @{ observation_serial = $index + 1; pre_draw_process_frame = 100 + $index; observation_process_frame = 100 + $index; source_frame_unknown = $true; viewports = @($rootRow, $mainRow, $spareRow) }
})
$viewportSummary = @{ group_count = 6; viewport_limit = 3; observer_pre_elapsed_us = 25; observer_post_elapsed_us = 30; roles = @{} }
foreach ($role in @('root', 'pov_main', 'pov_spare')) {
    $statusCounts = @{ absent = 0; inactive = 0; warmup_or_resumed = 0; last_engine_reading = 0; unavailable_after_pre_draw = 0 }
    foreach ($group in $viewportGroups) { foreach ($view in $group.viewports) { if ($view.role -ceq $role) { $statusCounts[$view.status]++ } } }
    $viewportSummary.roles[$role] = @{ status_counts = $statusCounts }
    foreach ($pair in @(@('continuous', 'last_engine_reading'), @('warmup', 'warmup_or_resumed'))) {
        foreach ($kind in @('cpu', 'gpu')) { $viewportSummary.roles[$role][$pair[0] + '_' + $kind + '_last_engine_reading_ms'] = @{ count = $statusCounts[$pair[1]] } }
    }
}
foreach ($row in $viewportReport.results) {
    $row | Add-Member -NotePropertyName viewport_render_timing -NotePropertyValue (Copy-Profile $viewportSummary)
    $row | Add-Member -NotePropertyName raw -NotePropertyValue @{ viewport_render_timing = (Copy-Profile $viewportGroups); engine_render_setup_cpu_ms = @(0.01, 0.01, 0.01, 0.01, 0.01, 0.01) }
}
foreach ($budget in @($viewportReport.observation_limits) + @($viewportReport.results | ForEach-Object { $_.observation_limits })) {
    $budget.case_counts | Add-Member -NotePropertyName render_setup -NotePropertyValue 6
    $budget.run_counts | Add-Member -NotePropertyName render_setup -NotePropertyValue 12
    $budget.run_groups = 214
}
Check-Profile (@(Get-GameplayProfileReportErrors $viewportReport $viewportExpected).Count -eq 0) 'Opt-in viewport receipt preserves numeric GPU zero, null inactive targets, one-shot/resumed labels and replacement warmup.'
Check-Profile ($viewportGroups[2].viewports[1].requested_node_update_mode -eq 1 -and $viewportGroups[2].viewports[1].update_mode_before -eq 0 -and $viewportGroups[2].viewports[1].status -ceq 'inactive' -and $null -eq $viewportGroups[2].viewports[1].cpu_last_engine_reading_ms) 'Consumed ONCE keeps requested policy separate from effective DISABLED and unavailable timing.'
Check-Profile (@(Get-GameplayProfileReportErrors (Copy-Profile $viewportReport) (Copy-Profile $viewportExpected)).Count -eq 0) 'Viewport receipt survives JSON without carrying Nodes/RIDs or changing null and numeric meanings.'
Check-Profile (@(Get-GameplayProfileReportErrors $viewportReport $expected).Count -gt 0) 'Default profile cannot silently enable viewport instrumentation.'
foreach ($mutation in @('light', 'missing_header', 'node_policy_provenance', 'missing_requested_policy', 'unknown_requested_policy', 'consumed_once_eligible', 'frame_claim', 'cleanup_live', 'cleanup_connected', 'cleanup_ledger', 'missing_raw', 'count_alignment', 'four_targets', 'wrong_order', 'serial', 'frame_regression', 'source_frame', 'missing_source_frame', 'stale_inactive', 'missing_zero', 'negative', 'infinity', 'nan', 'first_not_warm', 'resume_not_warm', 'replacement_not_warm', 'disabled_eligible', 'unknown_mode', 'absent_instance', 'mixed_summary', 'observer_nonfinite')) {
    $bad = Copy-Profile $viewportReport
    $badExpected = Copy-Profile $viewportExpected
    $groups = $bad.results[1].raw.viewport_render_timing
    switch ($mutation) {
        'light' { $bad.observer_mode = 'light'; $badExpected.observer = 'light' }
        'missing_header' { $bad.PSObject.Properties.Remove('viewport_render_timing') }
        'node_policy_provenance' { $bad.viewport_render_timing.update_mode_scope = 'requested_node_property' }
        'missing_requested_policy' { $groups[2].viewports[1].PSObject.Properties.Remove('requested_node_update_mode') }
        'unknown_requested_policy' { $groups[2].viewports[1].requested_node_update_mode = 5 }
        'consumed_once_eligible' { $groups[2].viewports[1].expected_update = $true }
        'frame_claim' { $groups[0].source_frame_unknown = $false }
        'cleanup_live' { $bad.viewport_render_timing.cleanup.live_owned_count = 1 }
        'cleanup_connected' { $bad.viewport_render_timing.cleanup.pre_draw_callback_connected = $true }
        'cleanup_ledger' { $bad.viewport_render_timing.cleanup.disabled_count = 2 }
        'missing_raw' { $bad.results[1].raw.viewport_render_timing = $null }
        'count_alignment' { $bad.results[1].observation_limits.case_counts.render_setup = 7 }
        'four_targets' { $groups[0].viewports += (Copy-Profile $groups[0].viewports[0]) }
        'wrong_order' { $groups[0].viewports = @($groups[0].viewports[1], $groups[0].viewports[0], $groups[0].viewports[2]) }
        'serial' { $groups[1].observation_serial = 1 }
        'frame_regression' { $groups[1].pre_draw_process_frame = 99 }
        'source_frame' { $groups[1].viewports[0].source_frame = 101 }
        'missing_source_frame' { $groups[1].viewports[0].PSObject.Properties.Remove('source_frame') }
        'stale_inactive' { $groups[0].viewports[1].cpu_last_engine_reading_ms = 0.2 }
        'missing_zero' { $groups[1].viewports[0].gpu_last_engine_reading_ms = $null }
        'negative' { $groups[1].viewports[0].gpu_last_engine_reading_ms = -0.1 }
        'infinity' { $groups[1].viewports[0].gpu_last_engine_reading_ms = [double]::PositiveInfinity }
        'nan' { $groups[1].viewports[0].gpu_last_engine_reading_ms = [double]::NaN }
        'first_not_warm' { $groups[0].viewports[0].status = 'last_engine_reading' }
        'resume_not_warm' { $groups[3].viewports[1].status = 'last_engine_reading' }
        'replacement_not_warm' { $groups[5].viewports[0].status = 'last_engine_reading' }
        'disabled_eligible' { $groups[0].viewports[1].expected_update = $true }
        'unknown_mode' { $groups[1].viewports[1].update_mode_before = 5 }
        'absent_instance' { $groups[0].viewports[2].instance_id = 123 }
        'mixed_summary' { $bad.results[1].viewport_render_timing.roles.pov_main.continuous_gpu_last_engine_reading_ms.count = 4 }
        'observer_nonfinite' { $bad.results[1].viewport_render_timing.observer_pre_elapsed_us = [double]::NaN }
    }
    Check-Profile (@(Get-GameplayProfileReportErrors $bad $badExpected).Count -gt 0) "Viewport receipt rejects contradictory or unbounded evidence: $mutation"
}
& (Join-Path $PSScriptRoot 'test-measurement-observation.ps1')
& (Join-Path $PSScriptRoot 'test-measurement-arming.ps1')
& (Join-Path $PSScriptRoot 'test-portable-measurement.ps1')
Write-Output "gameplay-profile: $assertions assertions passed"
