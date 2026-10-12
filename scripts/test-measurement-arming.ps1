# Pure manual-arm boundary tests. No engine, native calls or files written.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'measurement-observation.ps1')
$armingAssertions = 0
function Check-Arming([bool]$Condition, [string]$Message) {
    $script:armingAssertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Copy-Arming($Value) { return $Value | ConvertTo-Json -Depth 32 | ConvertFrom-Json }
function New-ArmingFixture {
    $epoch = [DateTimeOffset]::Parse('2026-10-12T12:00:00Z').ToUnixTimeMilliseconds()
    return [ordered]@{
        schema = 'hex-foreground-arming-v1'; requested = $true; armed = $true
        deadline_ms = 300000; stable_focus_required_ms = 1000; maximum_poll_gap_ms = 250
        setup_started_utc_msec = $epoch; setup_started_monotonic_usec = 1000000L
        manual_confirmation_received = $true; manual_confirmation_phase = 'setup'; manual_confirmation_kind = 'start_button_pressed'
        manual_confirmation_utc_msec = $epoch + 1000; manual_confirmation_monotonic_usec = 2000000L
        armed_utc_msec = $epoch + 2000; armed_monotonic_usec = 3000000L; wait_elapsed_ms = 2000L
        stable_focus_elapsed_ms = 1000L; stable_focus_samples = 61
        game_instantiation_started_utc_msec = $epoch + 2100; game_instantiation_started_monotonic_usec = 3100000L
        setup_focus_observations = @(for ($i = 0; $i -le 20; $i++) { @{ phase = 'setup'; elapsed_ms = $i * 100; focused = $i -ge 10; eligible = $i -ge 10 } })
        post_arm_focus = @{ samples = 120; unfocused_samples = 0; focus_exit_events = 0 }
    }
}
function New-ArmedWindowFixture {
    $begin = [DateTimeOffset]::Parse('2026-10-12T12:00:00Z')
    @(for ($i = 0; $i -le 6; $i++) {
        [ordered]@{
            elapsed_ms = $i * 500; observed_utc = $begin.AddMilliseconds($i * 500).UtcDateTime.ToString('o'); process_id = 91
            main_window_available = $true; main_window_handle = 'FEED'; availability_reason = 'available'
            main_window_process_id = 91; main_window_process_matches = $true; client_width = 1280; client_height = 720
            client_size_scope = 'physical_pixels_per_monitor_v2'; foreground_process_matches = $i -ge 2; foreground_window_matches = $i -ge 2
            main_window_visible = $true; main_window_minimized = $false; error = $null
        }
    })
}
$fixture = New-ArmingFixture
$windows = New-ArmedWindowFixture
$originalArming = $fixture | ConvertTo-Json -Depth 32 -Compress
$originalWindows = $windows | ConvertTo-Json -Depth 32 -Compress
$assessment = Get-MeasurementArmedWindowAssessment $windows 1280 720 $fixture $true
Check-Arming $assessment.qualified_samples 'Explicit pre-instantiation arm admits valid post-arm samples while retaining unfocused setup.'
Check-Arming ($assessment.setup_sample_count -eq 4 -and $assessment.measurement_sample_count -eq 3 -and $assessment.sample_phases.Count -eq 7) 'Each original observation has exactly one explicit phase; the sample at the UTC arm is measured.'
Check-Arming ($assessment.setup_assessment.counts.unfocused -eq 2 -and -not $assessment.setup_assessment.qualified_samples) 'Unfocused setup remains inspectable and is never relabelled as admitted focus.'
Check-Arming ($assessment.measurement_assessment.counts.foreground -eq 3 -and $assessment.measurement_assessment.observed_span_ms -eq 1000) 'Setup samples do not inflate the minimum three samples or measured span.'
Check-Arming (($fixture | ConvertTo-Json -Depth 32 -Compress) -ceq $originalArming -and ($windows | ConvertTo-Json -Depth 32 -Compress) -ceq $originalWindows) 'Partitioning never edits or deletes original engine or Windows evidence.'
Check-Arming ((Get-MeasurementArmedWindowAssessment (Copy-Arming $windows) 1280 720 (Copy-Arming $fixture) $true).qualified_samples) 'An unmodified JSON roundtrip remains valid when PowerShell materializes explicit UTC timestamps.'
foreach ($waitMs in @(120000L, 300000L)) {
    $longArm = Copy-Arming $fixture
    $longArm.manual_confirmation_utc_msec = $longArm.setup_started_utc_msec + $waitMs - 1000
    $longArm.manual_confirmation_monotonic_usec = $longArm.setup_started_monotonic_usec + ($waitMs - 1000) * 1000
    $longArm.armed_utc_msec = $longArm.setup_started_utc_msec + $waitMs
    $longArm.armed_monotonic_usec = $longArm.setup_started_monotonic_usec + $waitMs * 1000
    $longArm.wait_elapsed_ms = $waitMs
    $longArm.game_instantiation_started_utc_msec = $longArm.armed_utc_msec + 100
    $longArm.game_instantiation_started_monotonic_usec = $longArm.armed_monotonic_usec + 100000
    $longArm.setup_focus_observations = @(for ($at = 0L; $at -le $waitMs; $at += 100) {
        @{ phase = 'setup'; elapsed_ms = $at; focused = $at -ge ($waitMs - 1000); eligible = $at -ge ($waitMs - 1000) }
    })
    $longWindows = @(for ($at = 0L; $at -le ($waitMs + 1000); $at += 500) {
        $row = Copy-Arming $windows[0]
        $row.elapsed_ms = $at
        $row.observed_utc = [DateTimeOffset]::FromUnixTimeMilliseconds($longArm.setup_started_utc_msec + $at).UtcDateTime.ToString('o')
        $row.foreground_process_matches = $at -ge ($waitMs - 1000)
        $row.foreground_window_matches = $at -ge ($waitMs - 1000)
        $row
    })
    $longAssessment = Get-MeasurementArmedWindowAssessment $longWindows 1280 720 $longArm $true
    Check-Arming $longAssessment.qualified_samples "Coherent late manual Start is admitted at $waitMs ms, including the exact five-minute boundary."
    Check-Arming ($longAssessment.measurement_sample_count -eq 3 -and $longArm.setup_focus_observations.Count -eq ($waitMs / 100 + 1)) "Long setup preserves every bounded setup record without adding measured samples: $waitMs ms."
    foreach ($postIndex in @(($longWindows.Count - 3), ($longWindows.Count - 2))) {
        $badWindows = Copy-Arming $longWindows
        $badWindows[$postIndex].foreground_window_matches = $false
        Check-Arming (-not (Get-MeasurementArmedWindowAssessment $badWindows 1280 720 $longArm $true).qualified_samples) "Long setup cannot conceal first or later post-arm focus loss: $waitMs ms / $postIndex."
    }
}
$pastDeadline = Copy-Arming $longArm
$pastDeadline.manual_confirmation_utc_msec += 1
$pastDeadline.manual_confirmation_monotonic_usec += 1000
$pastDeadline.armed_utc_msec += 1
$pastDeadline.armed_monotonic_usec += 1000
$pastDeadline.wait_elapsed_ms += 1
$pastDeadline.game_instantiation_started_utc_msec += 1
$pastDeadline.game_instantiation_started_monotonic_usec += 1000
foreach ($row in $pastDeadline.setup_focus_observations) { $row.elapsed_ms += 1 }
Check-Arming (@(Get-MeasurementArmingErrors $pastDeadline $true | Where-Object { $_ -match 'outside the bounded' }).Count -eq 1) 'One millisecond beyond five minutes is rejected despite coherent clocks and a recorded Start.'
foreach ($mutation in @('missing', 'not_requested', 'not_armed', 'late', 'deadline', 'unstable', 'few_polls', 'before_instantiation', 'engine_clock_jump', 'engine_focus_loss', 'engine_focus_event', 'too_few_engine_samples', 'nonfinite', 'missing_setup', 'oversized_setup', 'contradictory_focus', 'contradictory_eligibility', 'missing_eligibility', 'missing_endpoint', 'after_arm', 'stable_record_gap', 'no_start', 'missing_start_time', 'wrong_start_phase', 'auto_start_kind', 'start_before_setup', 'start_inside_stable', 'start_clock_jump', 'eligible_before_start')) {
    $bad = Copy-Arming $fixture
    switch ($mutation) {
        'missing' { $bad.PSObject.Properties.Remove('armed_utc_msec') }
        'not_requested' { $bad.requested = $false }
        'not_armed' { $bad.armed = $false }
        'late' { $bad.armed_utc_msec += 300000; $bad.armed_monotonic_usec += 300000000; $bad.wait_elapsed_ms += 300000 }
        'deadline' { $bad.deadline_ms = 120000 }
        'unstable' { $bad.stable_focus_elapsed_ms = 999 }
        'few_polls' { $bad.stable_focus_samples = 2 }
        'before_instantiation' { $bad.game_instantiation_started_utc_msec = $bad.armed_utc_msec - 1; $bad.game_instantiation_started_monotonic_usec = $bad.armed_monotonic_usec - 1 }
        'engine_clock_jump' { $bad.armed_utc_msec += 251 }
        'engine_focus_loss' { $bad.post_arm_focus.unfocused_samples = 1 }
        'engine_focus_event' { $bad.post_arm_focus.focus_exit_events = 1 }
        'too_few_engine_samples' { $bad.post_arm_focus.samples = 2 }
        'nonfinite' { $bad.armed_monotonic_usec = [double]::PositiveInfinity }
        'missing_setup' { $bad.setup_focus_observations = @() }
        'oversized_setup' { $bad.setup_focus_observations = @($bad.setup_focus_observations[0]) * 3002 }
        'contradictory_focus' { foreach ($row in $bad.setup_focus_observations) { $row.focused = $false } }
        'contradictory_eligibility' { $bad.setup_focus_observations[-2].eligible = $false }
        'missing_eligibility' { $bad.setup_focus_observations[-1].PSObject.Properties.Remove('eligible') }
        'missing_endpoint' { $bad.setup_focus_observations = @($bad.setup_focus_observations[0..19]) }
        'after_arm' { $bad.setup_focus_observations[-1].elapsed_ms = 2001 }
        'stable_record_gap' { $bad.setup_focus_observations = @($bad.setup_focus_observations[0..10]) + @($bad.setup_focus_observations[14..20]) }
        'no_start' { $bad.manual_confirmation_received = $false; foreach ($row in $bad.setup_focus_observations) { $row.focused = $true } }
        'missing_start_time' { $bad.PSObject.Properties.Remove('manual_confirmation_monotonic_usec') }
        'wrong_start_phase' { $bad.manual_confirmation_phase = 'measurement' }
        'auto_start_kind' { $bad.manual_confirmation_kind = 'engine_focus' }
        'start_before_setup' { $bad.manual_confirmation_monotonic_usec = 999999; $bad.manual_confirmation_utc_msec = $bad.setup_started_utc_msec - 1 }
        'start_inside_stable' { $bad.manual_confirmation_monotonic_usec += 1000; $bad.manual_confirmation_utc_msec += 1 }
        'start_clock_jump' { $bad.manual_confirmation_utc_msec += 251 }
        'eligible_before_start' { $bad.setup_focus_observations[9].eligible = $true }
    }
    Check-Arming (-not (Get-MeasurementArmedWindowAssessment $windows 1280 720 $bad $true).qualified_samples) "Invalid arm cannot exclude setup evidence: $mutation"
}
foreach ($mutation in @('first_unfocused', 'later_unfocused', 'first_missing', 'interior_missing', 'wrong_pixels', 'wrong_owner', 'missing_utc', 'local_utc', 'utc_clock_jump', 'elapsed_clock_jump', 'no_post', 'two_post', 'no_setup', 'late_post_start')) {
    $bad = Copy-Arming $windows
    switch ($mutation) {
        'first_unfocused' { $bad[4].foreground_process_matches = $false }
        'later_unfocused' { $bad[6].foreground_window_matches = $false }
        'first_missing' { $bad[4].main_window_available = $false; $bad[4].availability_reason = 'window_unavailable' }
        'interior_missing' { $bad[5].main_window_available = $false; $bad[5].availability_reason = 'window_unavailable' }
        'wrong_pixels' { $bad[4].client_width = 1290 }
        'wrong_owner' { $bad[5].main_window_process_id = 92 }
        'missing_utc' { $bad[0].PSObject.Properties.Remove('observed_utc') }
        'local_utc' { $bad[0].observed_utc = '2026-10-12T12:00:00' }
        'utc_clock_jump' { $bad[4].observed_utc = '2026-10-12T12:00:02.251Z' }
        'elapsed_clock_jump' { $bad[4].elapsed_ms += 251 }
        'no_post' { $bad = @($bad[0..3]) }
        'two_post' { $bad = @($bad[0..5]) }
        'no_setup' { $bad = @($bad[4..6]) }
        'late_post_start' { foreach ($row in $bad[4..6]) { $row.elapsed_ms += 18000; $row.observed_utc = ([DateTimeOffset]$row.observed_utc).AddMilliseconds(18000).UtcDateTime.ToString('o') } }
    }
    Check-Arming (-not (Get-MeasurementArmedWindowAssessment $bad 1280 720 $fixture $true).qualified_samples) "Post-arm errors and uncertain clock boundaries remain failures: $mutation"
}
$edge = Copy-Arming $windows
foreach ($row in $edge[4..6]) { $row.elapsed_ms += 1500; $row.observed_utc = ([DateTimeOffset]$row.observed_utc).AddMilliseconds(1500).UtcDateTime.ToString('o') }
Check-Arming ((Get-MeasurementArmedWindowAssessment $edge 1280 720 $fixture $true).qualified_samples) 'The original inclusive two-second observer gap limit still applies across the arm boundary.'
foreach ($row in $edge[4..6]) { $row.elapsed_ms += 1; $row.observed_utc = ([DateTimeOffset]$row.observed_utc).AddMilliseconds(1).UtcDateTime.ToString('o') }
Check-Arming (-not (Get-MeasurementArmedWindowAssessment $edge 1280 720 $fixture $true).qualified_samples) 'A one-millisecond overflow at the setup/measurement seam cannot disappear during partitioning.'
$timeout = Copy-Arming $fixture
$timeout.armed = $false
$timeout.armed_utc_msec = $null
$timeout.armed_monotonic_usec = $null
$timeout.game_instantiation_started_monotonic_usec = $null
$timeout.game_instantiation_started_utc_msec = $null
$timedOut = Get-MeasurementArmedWindowAssessment $windows 1280 720 $timeout $true
Check-Arming (-not $timedOut.qualified_samples -and $timedOut.setup_sample_count -eq 7 -and $timedOut.measurement_sample_count -eq 0) 'Timeout retains all known unarmed observations as setup and can never admit gameplay.'
$disabled = @{ schema = 'hex-foreground-arming-v1'; requested = $false; armed = $false; armed_utc_msec = $null }
$default = Get-MeasurementArmedWindowAssessment $windows 1280 720 $disabled $false
Check-Arming (-not $default.qualified_samples -and $default.setup_sample_count -eq 0 -and $default.measurement_assessment.counts.unfocused -eq 2) 'Default mode still validates every available sample, including the same unfocused first second.'
Check-Arming (-not (Get-MeasurementArmedWindowAssessment $windows 1280 720 $fixture $false).qualified_samples) 'An unrequested arm never changes default admission.'
Write-Output "measurement-arming: $armingAssertions assertions passed"
