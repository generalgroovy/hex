# Pure admission rules shared by native-source and actual-portable diagnostics.
# No engine/process launch, foreground activation, system setting or file write.
function Get-MeasurementValue($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Test-MeasurementInteger($Value) {
    return $Value -is [ValueType] -and $Value -isnot [bool] -and -not [double]::IsNaN([double]$Value) -and -not [double]::IsInfinity([double]$Value) -and [double]$Value -ge 0 -and [double]$Value -le [long]::MaxValue -and [double]$Value -eq [Math]::Floor([double]$Value)
}

function Get-MeasurementArmingErrors($Arming, [bool]$Requested) {
    $errors = [Collections.Generic.List[string]]::new()
    if ((Get-MeasurementValue $Arming 'schema' '') -cne 'hex-foreground-arming-v1' -or (Get-MeasurementValue $Arming 'requested') -cne $Requested) { $errors.Add('Foreground arming mode is missing or differs from the explicit request.') }
    if (-not $Requested) {
        if ((Get-MeasurementValue $Arming 'armed') -cne $false -or $null -ne (Get-MeasurementValue $Arming 'armed_utc_msec')) { $errors.Add('Default measurement cannot silently exclude a setup interval.') }
        return $errors.ToArray()
    }
    if ((Get-MeasurementValue $Arming 'armed') -cne $true) { $errors.Add('Requested foreground arming did not complete.') }
    if ((Get-MeasurementValue $Arming 'manual_confirmation_received') -cne $true -or (Get-MeasurementValue $Arming 'manual_confirmation_phase' '') -cne 'setup' -or (Get-MeasurementValue $Arming 'manual_confirmation_kind' '') -cne 'start_button_pressed') { $errors.Add('Manual arming requires a recorded Start button event during setup; engine focus alone cannot arm the run.') }
    foreach ($pair in @(@('deadline_ms', 300000), @('stable_focus_required_ms', 1000), @('maximum_poll_gap_ms', 250))) {
        if ((Get-MeasurementValue $Arming $pair[0] -1) -ne $pair[1]) { $errors.Add("Foreground arming policy differs: $($pair[0]).") }
    }
    $keys = @('setup_started_utc_msec', 'setup_started_monotonic_usec', 'manual_confirmation_utc_msec', 'manual_confirmation_monotonic_usec', 'armed_utc_msec', 'armed_monotonic_usec', 'wait_elapsed_ms', 'stable_focus_elapsed_ms', 'stable_focus_samples', 'game_instantiation_started_utc_msec', 'game_instantiation_started_monotonic_usec')
    $numbers = @{}
    foreach ($key in $keys) {
        $value = Get-MeasurementValue $Arming $key
        if (-not (Test-MeasurementInteger $value)) { $errors.Add("Foreground arming lacks a finite nonnegative integer: $key.") }
        else { $numbers[$key] = [long]$value }
    }
    if ($numbers.Count -eq $keys.Count) {
        $wait = ($numbers.armed_monotonic_usec - $numbers.setup_started_monotonic_usec) / 1000.0
        if ($wait -lt 1000 -or $wait -gt 300000 -or $numbers.wait_elapsed_ms -ne [Math]::Floor($wait)) { $errors.Add('Foreground arm boundary lies outside the bounded one-second-to-five-minute setup interval.') }
        if ([Math]::Abs(($numbers.armed_utc_msec - $numbers.setup_started_utc_msec) - $wait) -gt 250) { $errors.Add('Setup UTC and monotonic clocks diverged; a safe window-sample partition is unavailable.') }
        if ($numbers.stable_focus_elapsed_ms -lt 1000 -or $numbers.stable_focus_elapsed_ms -gt $numbers.wait_elapsed_ms -or $numbers.stable_focus_samples -lt 3) { $errors.Add('Arming lacks a full second and at least three stable focus polls.') }
        $confirmedAfterSetup = $numbers.manual_confirmation_monotonic_usec - $numbers.setup_started_monotonic_usec
        if ($confirmedAfterSetup -lt 0 -or $numbers.manual_confirmation_utc_msec -lt $numbers.setup_started_utc_msec -or $numbers.manual_confirmation_monotonic_usec -gt ($numbers.armed_monotonic_usec - $numbers.stable_focus_elapsed_ms * 1000) -or $numbers.armed_monotonic_usec - $numbers.manual_confirmation_monotonic_usec -lt 1000000) { $errors.Add('Manual Start must occur during setup and before the entire final one-second stable focus interval.') }
        if ([Math]::Abs(($numbers.manual_confirmation_utc_msec - $numbers.setup_started_utc_msec) - $confirmedAfterSetup / 1000.0) -gt 250) { $errors.Add('Manual Start UTC and monotonic clocks diverged.') }
        if ($numbers.game_instantiation_started_monotonic_usec -lt $numbers.armed_monotonic_usec -or $numbers.game_instantiation_started_utc_msec -lt $numbers.armed_utc_msec) { $errors.Add('The game was instantiated before the foreground arm boundary.') }
        if ([Math]::Abs(($numbers.game_instantiation_started_utc_msec - $numbers.armed_utc_msec) - (($numbers.game_instantiation_started_monotonic_usec - $numbers.armed_monotonic_usec) / 1000.0)) -gt 250) { $errors.Add('Game-start UTC and monotonic clocks diverged after arming.') }
    }
    $setupRows = @(Get-MeasurementValue $Arming 'setup_focus_observations' @())
    if ($setupRows.Count -lt 3 -or $setupRows.Count -gt 3001) { $errors.Add('Bounded setup focus observations are absent or exceed 3001 records.') }
    $previous = -1L
    $stableRows = [Collections.Generic.List[object]]::new()
    foreach ($row in $setupRows) {
        $at = Get-MeasurementValue $row 'elapsed_ms'
        if ((Get-MeasurementValue $row 'phase' '') -cne 'setup' -or -not (Test-MeasurementInteger $at) -or $at -gt 300000 -or $at -le $previous -or (Get-MeasurementValue $row 'focused') -isnot [bool] -or (Get-MeasurementValue $row 'eligible') -isnot [bool]) { $errors.Add('Malformed or unordered engine setup focus observation.') }
        else {
            $previous = [long]$at
            if ($numbers.Count -eq $keys.Count) {
                if ($at -gt $numbers.wait_elapsed_ms) { $errors.Add('A setup observation occurs after the claimed arm boundary.') }
                if ($at -lt [Math]::Floor(($numbers.manual_confirmation_monotonic_usec - $numbers.setup_started_monotonic_usec) / 1000.0) -and (Get-MeasurementValue $row 'eligible') -ceq $true) { $errors.Add('Raw setup focus became eligible before manual Start.') }
                if ($at -ge ($numbers.wait_elapsed_ms - $numbers.stable_focus_elapsed_ms)) { $stableRows.Add($row) }
            }
        }
    }
    if ($numbers.Count -eq $keys.Count) {
        if ($setupRows.Count -eq 0 -or (Get-MeasurementValue $setupRows[-1] 'elapsed_ms' -1) -ne $numbers.wait_elapsed_ms) { $errors.Add('The final raw setup observation does not coincide with the arm boundary.') }
        if ($stableRows.Count -lt 3) { $errors.Add('The claimed final stable interval lacks three corroborating raw setup observations.') }
        # Records are at least100ms apart; a250ms maximum poll gap permits a
        # raw-record gap below350ms. These rows corroborate, not reconstruct,
        # intervening engine polls or uninterrupted operating-system focus.
        $previousStable = $numbers.wait_elapsed_ms - $numbers.stable_focus_elapsed_ms
        foreach ($row in $stableRows) {
            $at = [long](Get-MeasurementValue $row 'elapsed_ms' -1)
            if ((Get-MeasurementValue $row 'focused') -cne $true -or (Get-MeasurementValue $row 'eligible') -cne $true -or $at - $previousStable -gt 350) { $errors.Add('Raw setup observations contradict the claimed final stable focus interval.') }
            $previousStable = $at
        }
    }
    $post = Get-MeasurementValue $Arming 'post_arm_focus'
    foreach ($key in @('samples', 'unfocused_samples', 'focus_exit_events')) {
        if (-not (Test-MeasurementInteger (Get-MeasurementValue $post $key))) { $errors.Add("Missing post-arm engine focus counter: $key.") }
    }
    if ((Get-MeasurementValue $post 'samples' 0) -lt 3 -or (Get-MeasurementValue $post 'unfocused_samples' -1) -ne 0 -or (Get-MeasurementValue $post 'focus_exit_events' -1) -ne 0) { $errors.Add('Post-arm engine focus was lost or insufficiently observed, including between measured cases.') }
    return $errors.ToArray()
}

function Get-MeasurementArmedWindowAssessment {
    param([object[]]$Observations, [int]$Width, [int]$Height, $Arming, [bool]$Requested)
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($message in @(Get-MeasurementArmingErrors $Arming $Requested)) { $errors.Add($message) }
    $rows = @($Observations)
    $setup = [Collections.Generic.List[object]]::new()
    $post = [Collections.Generic.List[object]]::new()
    $phases = [Collections.Generic.List[object]]::new()
    $armed = Get-MeasurementValue $Arming 'armed_utc_msec'
    $canPartition = $Requested -and (Test-MeasurementInteger $armed) -and (Get-MeasurementValue $Arming 'armed') -ceq $true
    $unarmedSetup = $Requested -and (Get-MeasurementValue $Arming 'requested') -ceq $true -and (Get-MeasurementValue $Arming 'armed') -ceq $false -and $null -eq (Get-MeasurementValue $Arming 'game_instantiation_started_monotonic_usec')
    $firstUtc = $null
    $firstElapsed = $null
    $previousUtc = $null
    $previousElapsed = -1L
    $lastSetupUtc = $null
    $firstPostUtc = $null
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $row = $rows[$index]
        $phase = if ($unarmedSetup) { 'setup' } elseif ($Requested) { 'unclassified' } else { 'measurement' }
        if ($canPartition) {
            $rawTimestamp = Get-MeasurementValue $row 'observed_utc' ''
            # PowerShell can materialize JSON Z timestamps as UTC DateTime.
            # Retain that explicit UTC type; reject unspecified/local kinds.
            $timestamp = if ($rawTimestamp -is [DateTime] -and $rawTimestamp.Kind -eq [DateTimeKind]::Utc) { $rawTimestamp.ToString('o') }
                elseif ($rawTimestamp -is [DateTimeOffset] -and $rawTimestamp.Offset -eq [TimeSpan]::Zero) { $rawTimestamp.ToString('o') }
                elseif ($rawTimestamp -is [string]) { $rawTimestamp } else { '' }
            $parsed = [DateTimeOffset]::MinValue
            $elapsed = Get-MeasurementValue $row 'elapsed_ms'
            if ($timestamp -cnotmatch '(Z|\+00:00)$' -or -not [DateTimeOffset]::TryParse($timestamp, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed) -or -not (Test-MeasurementInteger $elapsed)) {
                $errors.Add("Window sample $index lacks exact UTC/monotonic evidence for explicit arming.")
            } else {
                $utc = $parsed.ToUnixTimeMilliseconds()
                if ($null -eq $firstUtc) { $firstUtc = $utc; $firstElapsed = [long]$elapsed }
                if (($null -ne $previousUtc -and $utc -le $previousUtc) -or [long]$elapsed -le $previousElapsed -or [Math]::Abs(($utc - $firstUtc) - ([long]$elapsed - $firstElapsed)) -gt 250) { $errors.Add("Window sample $index has unordered or divergent UTC/monotonic clocks; setup cannot be safely excluded.") }
                $previousUtc = $utc
                $previousElapsed = [long]$elapsed
                $phase = if ($utc -lt [long]$armed) { 'setup' } else { 'measurement' }
                if ($phase -eq 'setup') { $lastSetupUtc = $utc }
                elseif ($null -eq $firstPostUtc) { $firstPostUtc = $utc }
            }
        }
        $phases.Add([ordered]@{ index = $index; phase = $phase })
        if ($phase -eq 'setup') { $setup.Add($row) } else { $post.Add($row) }
    }
    if ($rows.Count -gt 3601) { $errors.Add('Whole-run window evidence exceeds the 3601-record bound, including setup.') }
    # An absent HWND after an explicit arm is no longer a startup boundary.
    if ($canPartition -and $post.Count -gt 0 -and (Get-MeasurementValue $post[0] 'main_window_available') -cne $true) { $errors.Add('The first post-arm window observation is unavailable; setup exclusion cannot conceal a later window loss.') }
    if ($canPartition -and $post.Count -gt 0 -and $firstUtc -ge [long]$armed) { $errors.Add('No pre-arm window observation exists to bind the explicit setup boundary.') }
    $firstPostDelay = if ($null -ne $firstPostUtc) { $firstPostUtc - [long]$armed } else { $null }
    $boundaryGap = if ($null -ne $firstPostUtc -and $null -ne $lastSetupUtc) { $firstPostUtc - $lastSetupUtc } else { $null }
    if ($canPartition -and ($null -eq $firstPostDelay -or $firstPostDelay -gt 2000 -or $null -eq $boundaryGap -or $boundaryGap -gt 2000)) { $errors.Add('Window observation continuity across the arm boundary is absent or exceeds the existing 2000ms sampling-gap limit.') }
    $assessment = Get-MeasurementWindowAssessment $post.ToArray() $Width $Height
    foreach ($message in $assessment.errors) { $errors.Add($message) }
    return [ordered]@{
        policy = 'explicit-foreground-arm-v1'; requested = $Requested; armed_utc_msec = $armed
        qualified_samples = $errors.Count -eq 0; errors = $errors.ToArray()
        setup_sample_count = $setup.Count; measurement_sample_count = $post.Count; sample_phases = $phases.ToArray()
        first_post_arm_delay_ms = $firstPostDelay; arm_boundary_observation_gap_ms = $boundaryGap
        setup_assessment = $(if ($setup.Count -gt 0) { Get-MeasurementWindowAssessment $setup.ToArray() $Width $Height } else { $null })
        measurement_assessment = $assessment
        scope = 'Original Windows observations remain unchanged and retained. Only an explicitly requested, bounded pre-instantiation arm can label earlier observations SETUP. Every later available observation still requires exact owned pixels and foreground; missing interior observations and focus loss fail. Setup assessment is diagnostic, not admitted gameplay. Samples and engine focus events do not prove uninterrupted OS focus or physical frame presentation.'
    }
}

function Get-MeasurementWindowAssessment {
    param([object[]]$Observations, [int]$Width, [int]$Height)
    $errors = [Collections.Generic.List[string]]::new()
    $rows = @($Observations)
    $first = -1
    $last = -1
    $maxGap = 0L
    $counts = [ordered]@{ available = 0; foreground = 0; boundary_unavailable = 0; interior_unavailable = 0; wrong_owner = 0; wrong_size = 0; unfocused = 0; invisible_or_minimized = 0; query_error = 0; memory_available = 0 }
    $memory = [ordered]@{ first_private_bytes = $null; last_private_bytes = $null; max_private_bytes = $null; max_working_set_bytes = $null }
    # The checked runner's 1,800-second watchdog and >=500ms sample spacing
    # bound storage to <=3,601 records. Reject malformed/imported larger input.
    if ($rows.Count -gt 3601) { $errors.Add('Window observation count exceeds the checked-runner watchdog bound (3601).') }
    for ($index = 0; $index -lt $rows.Count; $index++) {
        if ((Get-MeasurementValue $rows[$index] 'main_window_available') -ceq $true) {
            if ($first -lt 0) { $first = $index }
            $last = $index
        }
    }
    $previousMs = -1L
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $sample = $rows[$index]
        $at = [long](Get-MeasurementValue $sample 'elapsed_ms' -1)
        if ($at -lt 0 -or ($index -gt 0 -and $at -le $previousMs)) { $errors.Add("Window sample $index has a missing, duplicate or unordered monotonic timestamp.") }
        if ($index -gt $first -and $index -le $last) { $maxGap = [Math]::Max($maxGap, $at - $previousMs) }
        $previousMs = $at
        $private = Get-MeasurementValue $sample 'process_private_bytes'
        $working = Get-MeasurementValue $sample 'process_working_set_bytes'
        if ($null -ne $private -and $null -ne $working -and $private -ge 0 -and $working -ge 0) {
            if ($counts.memory_available -eq 0) { $memory.first_private_bytes = $private; $memory.max_private_bytes = $private; $memory.max_working_set_bytes = $working }
            $counts.memory_available++
            $memory.last_private_bytes = $private
            $memory.max_private_bytes = [Math]::Max([long]$memory.max_private_bytes, [long]$private)
            $memory.max_working_set_bytes = [Math]::Max([long]$memory.max_working_set_bytes, [long]$working)
        }
        if ((Get-MeasurementValue $sample 'main_window_available') -cne $true) {
            $reason = Get-MeasurementValue $sample 'availability_reason' ''
            if (($index -lt $first -or $index -gt $last) -and $reason -in @('window_unavailable', 'process_exited') -and -not (Get-MeasurementValue $sample 'error')) {
                $counts.boundary_unavailable++
            } else {
                $counts.interior_unavailable++
                $errors.Add("Window sample $index is unavailable inside the observed interval or lacks an unambiguous boundary reason.")
            }
            continue
        }
        $counts.available++
        if (Get-MeasurementValue $sample 'error') { $counts.query_error++; $errors.Add("Window sample $index has a native query error.") }
        $owner = [long](Get-MeasurementValue $sample 'main_window_process_id' 0)
        $processId = [long](Get-MeasurementValue $sample 'process_id' 0)
        if ($owner -le 0 -or $owner -ne $processId -or (Get-MeasurementValue $sample 'main_window_process_matches') -cne $true) { $counts.wrong_owner++; $errors.Add("Window sample $index does not prove the launched process owns the measured HWND.") }
        if ((Get-MeasurementValue $sample 'client_width' -1) -ne $Width -or (Get-MeasurementValue $sample 'client_height' -1) -ne $Height -or (Get-MeasurementValue $sample 'client_size_scope' '') -cne 'physical_pixels_per_monitor_v2') { $counts.wrong_size++; $errors.Add("Window sample $index does not prove the requested ${Width}x${Height} physical client area.") }
        if ((Get-MeasurementValue $sample 'foreground_process_matches') -ceq $true -and (Get-MeasurementValue $sample 'foreground_window_matches') -ceq $true) { $counts.foreground++ }
        else { $counts.unfocused++; $errors.Add("Window sample $index is unfocused or has unknown foreground ownership.") }
        if ((Get-MeasurementValue $sample 'main_window_visible') -cne $true -or (Get-MeasurementValue $sample 'main_window_minimized') -cne $false) { $counts.invisible_or_minimized++; $errors.Add("Window sample $index is invisible, minimized or has unknown visibility.") }
    }
    $span = if ($first -ge 0 -and $last -ge $first) { [long](Get-MeasurementValue $rows[$last] 'elapsed_ms' 0) - [long](Get-MeasurementValue $rows[$first] 'elapsed_ms' 0) } else { 0L }
    if ($counts.available -lt 3 -or $span -lt 1000) { $errors.Add('At least three owned-window samples spanning one second are required; shorter runs remain diagnostic.') }
    if ($maxGap -gt 2000) { $errors.Add('Observed-window sampling has an interior gap above 2000ms; continuity of the sampling schedule is unproven.') }
    return [ordered]@{
        policy = 'owned-client-and-sampled-foreground-v1'; qualified_samples = $errors.Count -eq 0
        requested_client_pixels = @($Width, $Height); sample_count = $rows.Count; counts = $counts
        first_available_index = $first; last_available_index = $last; observed_span_ms = $span; maximum_interior_gap_ms = $maxGap
        maximum_records = 3601; maximum_interior_gap_allowed_ms = 2000; process_memory = $memory
        errors = $errors.ToArray()
        scope = 'Only contiguous unavailable-handle startup/shutdown boundaries are excluded, explicitly counted and retained. Every available sample must prove exact owned HWND client pixels, foreground, visibility and non-minimization. Approximately 500ms samples do not prove continuous focus, unobscured presentation, displayed frames, GPU time or input latency. Process memory is sampled working set/private committed bytes, not GPU memory or proof of a leak.'
    }
}

function Get-MeasurementPresentToolAvailability {
    $found = [Collections.Generic.List[object]]::new()
    foreach ($name in @('PresentMon.exe', 'PresentMonConsoleApplication.exe', 'CapFrameX.exe', 'wpr.exe')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) { $found.Add([ordered]@{ name = $name; path = $command.Source; discovery = 'PATH' }) }
    }
    $locations = @('C:/Program Files/Intel/PresentMon', 'C:/Program Files/PresentMon', 'C:/Program Files/CapFrameX')
    if ($env:LOCALAPPDATA) { $locations += Join-Path $env:LOCALAPPDATA 'CapFrameX' }
    $existing = @($locations | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
    return [ordered]@{ executables_on_path = $found.ToArray(); inspected_install_directories = $locations; existing_install_directories = $existing; capture_performed = $false; scope = 'Read-only PATH and named-directory availability check only; no executable, service or capture is started. WPR availability alone is not a configured frame-present trace. No machine-wide installation inventory is claimed.' }
}

function Get-MeasurementActivationErrors([bool]$Requested, [object[]]$Requests, [object[]]$Observations) {
    $errors = [Collections.Generic.List[string]]::new()
    $attempts = @($Requests)
    if (-not $Requested) {
        if ($attempts.Count -ne 0) { $errors.Add('Foreground activation occurred without the wrapper opt-in.') }
        return $errors.ToArray()
    }
    if ($attempts.Count -ne 1) { $errors.Add('Foreground opt-in requires exactly one retained activation attempt.'); return $errors.ToArray() }
    $attempt = $attempts[0]
    $firstWindow = @($Observations | Where-Object { (Get-MeasurementValue $_ 'main_window_available') -ceq $true } | Select-Object -First 1)
    if ((Get-MeasurementValue $attempt 'requested') -cne $true -or (Get-MeasurementValue $attempt 'error') -or (Get-MeasurementValue $attempt 'native_returned_success') -isnot [bool] -or (Get-MeasurementValue $attempt 'elapsed_ms' -1) -lt 0) { $errors.Add('Foreground opt-in did not record a valid native request/result.') }
    if ($firstWindow.Count -ne 1 -or (Get-MeasurementValue $attempt 'window_process_id' 0) -ne (Get-MeasurementValue $firstWindow[0] 'process_id' -1) -or (Get-MeasurementValue $attempt 'process_id' 0) -ne (Get-MeasurementValue $firstWindow[0] 'process_id' -1) -or (Get-MeasurementValue $attempt 'window_handle' '') -cne (Get-MeasurementValue $firstWindow[0] 'main_window_handle' 'missing') -or (Get-MeasurementValue $attempt 'elapsed_ms' 0) -gt (Get-MeasurementValue $firstWindow[0] 'elapsed_ms' -1)) { $errors.Add('Foreground request did not target the exact owned HWND before its first available observation.') }
    # A native false return is retained, not converted into foreground proof.
    # The independent window samples still must all prove actual foreground.
    return $errors.ToArray()
}
